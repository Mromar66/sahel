import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:inventory_app/app/widgets/hover_widgets.dart';
import 'package:inventory_app/core/utils/csv_utils.dart';
import 'package:inventory_app/features/products/data/product_repository.dart';

/// A saved-file result shown to the user after exporting.
class ExportResult {
  ExportResult({required this.title, required this.path});

  final String title;
  final String path;
}

/// Builds an Arabic RTL PDF table using the Windows Tahoma font. Returns null
/// when the font is unavailable so callers can show a clear message.
Future<pw.Document?> buildTablePdfDocument({
  String? title,
  String? subtitle,
  required List<String> headers,
  required List<List<String>> rows,
}) async {
  try {
    final fontBytes = File('C:\\Windows\\Fonts\\tahoma.ttf').readAsBytesSync();
    final font = pw.Font.ttf(ByteData.sublistView(fontBytes));
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (context) => [
          if (title != null && title.isNotEmpty) ...[
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 4),
          ],
          if (subtitle != null && subtitle.isNotEmpty) ...[
            pw.Text(
              subtitle,
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 10),
          ],
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF31BB68),
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerRight,
            border: pw.TableBorder.all(
              color: PdfColor.fromInt(0xFFBBBBBB),
              width: 0.5,
            ),
          ),
        ],
      ),
    );
    return doc;
  } catch (_) {
    return null;
  }
}

/// A ready-to-export report table. The share dialog is intentionally generic so
/// every screen (products, treasury, …) gets the exact same buttons, icons and
/// behaviour without duplicating the UI.
class ExportTable {
  ExportTable({
    this.title = 'تصدير',
    required this.headers,
    required this.rows,
    required this.filePrefix,
    required this.printName,
    required this.printSentLabel,
    required this.emptyMessage,
    required this.whatsAppIntro,
    required this.whatsAppLine,
    this.pdfTitle,
    this.pdfSubtitle,
  });

  final String title;
  final List<String> headers;
  final List<List<String>> rows;
  final String filePrefix;
  final String printName;
  final String printSentLabel;
  final String emptyMessage;
  final String whatsAppIntro;
  final String Function(List<String> row) whatsAppLine;
  final String? pdfTitle;
  final String? pdfSubtitle;
}

/// "تصدير" dialog — copy of the reference share dialog with tidy Material
/// icons: row of big tiles [طباعة (yellow) / أكسل / PDF], second row
/// [WhatsApp / صورة PNG] beside the printer picker with a pin, a wide
/// [نسخة صورة] button beside the phone field, and a gray [إلغاء] at the
/// bottom-left. All actions are fully offline.
Future<void> showExportDialog(
  BuildContext context, {
  required List<ProductListRow> rows,
  GlobalKey? tableBoundaryKey,
}) {
  final data = <List<String>>[
    for (final row in rows)
      [
        '${row.product.id ?? ''}',
        row.product.name,
        '${row.totalQuantity}',
        row.unitName,
        '${row.product.sellingPrice}',
        '${row.avgPurchasePrice}',
        '${row.lastPurchasePrice}',
        row.product.barcode ?? '',
        row.product.productCode,
      ],
  ];
  return showTableExportDialog(
    context,
    table: ExportTable(
      headers: const [
        'رقم الصنف',
        'اسم الصنف',
        'إجمالي الكمية',
        'الوحدة',
        'سعر البيع',
        'متوسط سعر الشراء',
        'آخر سعر شراء',
        'باركود',
        'كود الصنف 1',
      ],
      rows: data,
      filePrefix: 'products',
      printName: 'قائمة الأصناف',
      printSentLabel: 'القائمة',
      emptyMessage: 'لا توجد أصناف لتصديرها.',
      whatsAppIntro: 'قائمة الأصناف (${rows.length} صنف)',
      whatsAppLine: (row) => '${row[1]} | الكمية: ${row[2]} | السعر: ${row[4]}',
    ),
    tableBoundaryKey: tableBoundaryKey,
  );
}

/// Shows the same share/export window used by the products screen for any
/// [ExportTable] (treasury summary, movements, …).
Future<void> showTableExportDialog(
  BuildContext context, {
  required ExportTable table,
  GlobalKey? tableBoundaryKey,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0x66000000),
    builder: (dialogContext) =>
        _ExportDialog(table: table, tableBoundaryKey: tableBoundaryKey),
  );
}

class _ExportDialog extends StatefulWidget {
  const _ExportDialog({required this.table, this.tableBoundaryKey});

  final ExportTable table;
  final GlobalKey? tableBoundaryKey;

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  static const _pinnedPrinterFile = 'database/printer.json';

  final TextEditingController _phoneController = TextEditingController();
  String _printerName = 'Microsoft Print to PDF';
  bool _pinned = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadPinnedPrinter();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadPinnedPrinter() async {
    try {
      final file = File(_pinnedPrinterFile);
      if (file.existsSync()) {
        final content = file.readAsStringSync().trim();
        final decoded = jsonDecode(content);
        final printer = decoded is Map ? decoded['printer'] : null;
        if (printer is String && printer.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _printerName = printer;
            _pinned = true;
          });
        }
      }
    } catch (_) {
      // Missing or corrupt settings file — keep the default printer.
    }
  }

  Future<void> _togglePin() async {
    setState(() => _pinned = !_pinned);
    try {
      final file = File(_pinnedPrinterFile);
      if (_pinned) {
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(jsonEncode({'printer': _printerName}));
      } else if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {
      // Persistence failure is non-fatal.
    }
  }

  // ---------------------------------------------------------------------------
  // Export folder helpers.
  // ---------------------------------------------------------------------------
  Directory _exportsDir() {
    final dir = Directory('database/exports');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  String _stamp() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mi = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    return '${now.year}$mm${dd}_$hh$mi$ss';
  }

  // ---------------------------------------------------------------------------
  // Data assembly.
  // ---------------------------------------------------------------------------
  List<List<String>> _tableData() {
    return [widget.table.headers, ...widget.table.rows];
  }

  // ---------------------------------------------------------------------------
  // PDF building (with embedded Tahoma when available).
  // ---------------------------------------------------------------------------
  Future<pw.Document?> _buildPdfDocument() {
    return buildTablePdfDocument(
      title: widget.table.pdfTitle,
      subtitle: widget.table.pdfSubtitle,
      headers: widget.table.headers,
      rows: widget.table.rows,
    );
  }

  // ---------------------------------------------------------------------------
  // Actions.
  // ---------------------------------------------------------------------------
  Future<void> _actionPrint() async {
    setState(() => _busy = true);
    try {
      final doc = await _buildPdfDocument();
      if (!mounted) return;
      if (doc == null) {
        _toast('تعذر تجهيز ملف الطباعة (خط عربي غير متوفر).');
        return;
      }
      final printed = await Printing.layoutPdf(
        onLayout: (format) => doc.save(),
        name: widget.table.printName,
        windowsModernDialog: true,
      );
      if (!mounted) return;
      if (printed) {
        _toast(
          'تم إرسال ${widget.table.printSentLabel} إلى الطباعة عبر: $_printerName',
        );
      }
    } catch (_) {
      if (mounted) _toast('تعذر بدء الطباعة.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _actionExcel() async {
    if (widget.table.rows.isEmpty) {
      _toast(widget.table.emptyMessage);
      return;
    }
    setState(() => _busy = true);
    try {
      final buffer = StringBuffer('\uFEFF'); // UTF-8 BOM for Excel Arabic.
      for (final line in _tableData()) {
        buffer.writeln(line.map(escapeCsvCellForSpreadsheet).join(','));
      }
      final path =
          '${_exportsDir().path}\\${widget.table.filePrefix}_${_stamp()}.csv';
      File(path).writeAsStringSync(buffer.toString(), flush: true);
      if (!mounted) return;
      _resultDialog(ExportResult(title: 'تم تصدير ملف الإكسل', path: path));
    } catch (_) {
      if (mounted) _toast('تعذر حفظ ملف الإكسل.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _actionPdf() async {
    if (widget.table.rows.isEmpty) {
      _toast(widget.table.emptyMessage);
      return;
    }
    setState(() => _busy = true);
    try {
      final doc = await _buildPdfDocument();
      if (!mounted) return;
      if (doc == null) {
        _toast('تعذر توليد الـ PDF (خط عربي غير متوفر).');
        return;
      }
      final path =
          '${_exportsDir().path}\\${widget.table.filePrefix}_${_stamp()}.pdf';
      File(path).writeAsBytesSync(await doc.save(), flush: true);
      if (!mounted) return;
      _resultDialog(ExportResult(title: 'تم تصدير ملف الـ PDF', path: path));
    } catch (_) {
      if (mounted) _toast('تعذر حفظ ملف الـ PDF.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _actionWhatsApp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _toast('أدخل رقم الواتساب أولًا.');
      return;
    }
    if (widget.table.rows.isEmpty) {
      _toast(widget.table.emptyMessage);
      return;
    }
    final buffer = StringBuffer('${widget.table.whatsAppIntro}\n');
    for (final row in widget.table.rows.take(30)) {
      buffer.writeln(widget.table.whatsAppLine(row));
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    _toast('تم نسخ البيانات للرقم $phone — الرسائل تحتاج اتصالاً بالإنترنت.');
  }

  Future<void> _captureTable({required bool toClipboard}) async {
    final key = widget.tableBoundaryKey;
    if (key == null || key.currentContext == null) {
      _toast('لا يوجد جدول لالتقاطه.');
      return;
    }
    setState(() => _busy = true);
    try {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      image.dispose();
      if (byteData == null) throw Exception('capture failed');
      final bytes = byteData.buffer.asUint8List();

      if (toClipboard) {
        final tempPath = '${_exportsDir().path}\\clipboard_${_stamp()}.png';
        File(tempPath).writeAsBytesSync(bytes, flush: true);
        final scriptFolder = await Directory.systemTemp.createTemp(
          'sahel_clipboard_',
        );
        final scriptFile = File(
          '${scriptFolder.path}${Platform.pathSeparator}copy-image.ps1',
        );
        try {
          await scriptFile.writeAsString(r'''
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile($args[0])
try { [System.Windows.Forms.Clipboard]::SetImage($img) }
finally { $img.Dispose() }
''');
          final result = await Process.run('powershell.exe', [
            '-STA',
            '-NoProfile',
            '-NonInteractive',
            '-File',
            scriptFile.path,
            tempPath,
          ]);
          if (!mounted) return;
          if (result.exitCode == 0) {
            _toast('تم نسخ صورة الجدول إلى الحافظة.');
          } else {
            _resultDialog(
              ExportResult(title: 'تم حفظ صورة الجدول', path: tempPath),
            );
          }
        } finally {
          await scriptFolder.delete(recursive: true);
        }
      } else {
        final path =
            '${_exportsDir().path}\\${widget.table.filePrefix}_${_stamp()}.png';
        File(path).writeAsBytesSync(bytes, flush: true);
        if (!mounted) return;
        _resultDialog(ExportResult(title: 'تم حفظ صورة الـ PNG', path: path));
      }
    } catch (_) {
      if (mounted) _toast('تعذر التقاط صورة الجدول.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Feedback.
  // ---------------------------------------------------------------------------
  void _toast(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _resultDialog(ExportResult result) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Text(
            result.title,
            style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
          ),
          content: Text(
            result.path,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF004AC0)),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: result.path));
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'نسخ المسار',
                style: TextStyle(color: Color(0xFF004AC0)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'إغلاق',
                style: TextStyle(color: Color(0xFF555555)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI.
  // ---------------------------------------------------------------------------
  static const Color _tileGrey = Color(0xFFE9E9E9);
  static const Color _ink = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: withPlainInputs(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            width: 900,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFBFC9D2)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTitleBar(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 34, 24, 52),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: SizedBox(
                          width: 685,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                textDirection: TextDirection.ltr,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _tileColumn([
                                    _tile(
                                      label: 'PDF',
                                      icon: const _PdfIcon(),
                                      onTap: _busy ? null : _actionPdf,
                                    ),
                                    _tile(
                                      label: 'صورة PNG',
                                      icon: const _PngIcon(),
                                      onTap: _busy
                                          ? null
                                          : () => _captureTable(
                                              toClipboard: false,
                                            ),
                                    ),
                                  ]),
                                  const SizedBox(width: 10),
                                  _tileColumn([
                                    _tile(
                                      label: 'أكسل',
                                      icon: const _ExcelIcon(),
                                      onTap: _busy ? null : _actionExcel,
                                    ),
                                    _tile(
                                      label: 'WhatsApp',
                                      icon: const _WhatsAppIcon(),
                                      onTap: _busy ? null : _actionWhatsApp,
                                    ),
                                  ]),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 200,
                                    child: Column(
                                      children: [
                                        _tile(
                                          label: 'طباعة',
                                          yellow: true,
                                          icon: const Icon(
                                            Icons.print,
                                            size: 40,
                                            color: Color(0xFF101010),
                                          ),
                                          onTap: _busy ? null : _actionPrint,
                                        ),
                                        const SizedBox(height: 7),
                                        SizedBox(
                                          height: 104,
                                          child: Align(
                                            alignment: Alignment.topCenter,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                top: 14,
                                              ),
                                              child: _printerRow(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Padding(
                                    padding: EdgeInsets.only(top: 138),
                                    child: Text(
                                      'الطابعة',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: _ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 34),
                              Row(
                                textDirection: TextDirection.ltr,
                                children: [
                                  _copyImageButton(),
                                  const SizedBox(width: 10),
                                  _phoneField(),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 86),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _cancelButton(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tileColumn(List<Widget> tiles) {
    return SizedBox(
      width: 200,
      child: Column(
        children: [
          tiles[0],
          const SizedBox(height: 7),
          if (tiles.length > 1) tiles[1],
        ],
      ),
    );
  }

  Widget _buildTitleBar() {
    return Container(
      height: 46,
      padding: const EdgeInsets.only(left: 14, right: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE6E6E6))),
      ),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          const Text('تصدير', style: TextStyle(fontSize: 14, color: _ink)),
          const Spacer(),
          HoverBuilder(
            builder: (context, hovered) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: hovered ? kHoverYellow : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 17,
                  color: Color(0xFF2B374A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One large light-gray tile with a brand icon above its caption, exactly as
  /// in the reference share dialog. Hovering paints the tile yellow.
  Widget _tile({
    required String label,
    required Widget icon,
    required VoidCallback? onTap,
    bool yellow = false,
  }) {
    return HoverBuilder(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      builder: (context, hovered) {
        final background = yellow
            ? (hovered ? const Color(0xFFDDB92F) : const Color(0xFFE6C33C))
            : (hovered ? kHoverYellow : _tileGrey);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? 0.55 : 1,
            child: Container(
              width: 200,
              height: 104,
              decoration: BoxDecoration(
                color: background,
                border: Border.all(
                  color: hovered
                      ? const Color(0xFFC7A62B)
                      : const Color(0xFFE2E2E2),
                ),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 42, child: Center(child: icon)),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _printerRow() {
    return Row(
      textDirection: TextDirection.ltr,
      children: [
        HoverBuilder(
          builder: (context, hovered) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _togglePin,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: hovered ? kHoverYellow : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _pinned ? Icons.push_pin : Icons.push_pin_outlined,
                size: 15,
                color: _pinned ? _ink : const Color(0xFF5A6772),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        HoverBuilder(
          builder: (context, hovered) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _pickPrinter,
            child: Container(
              width: 174,
              height: 28,
              padding: const EdgeInsets.only(left: 2, right: 4),
              decoration: BoxDecoration(
                color: hovered ? kHoverYellow : Colors.white,
                border: Border.all(color: const Color(0xFFBFBFBF)),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.arrow_drop_down,
                    size: 18,
                    color: Color(0xFF333333),
                  ),
                  Expanded(
                    child: Text(
                      _printerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11.5, color: _ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickPrinter() async {
    final result = await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      'Get-CimInstance Win32_Printer | Select-Object -ExpandProperty Name',
    ]);
    final names = (result.stdout as String)
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (!mounted) return;
    if (names.isEmpty) {
      _toast('لا توجد طابعات مثبتة على الجهاز.');
      return;
    }
    final chosen = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SimpleDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Text('اختر الطابعة', style: TextStyle(fontSize: 15)),
          children: [
            for (final name in names)
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(name),
                child: Text(name, style: const TextStyle(fontSize: 12.5)),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    setState(() => _printerName = chosen);
    if (_pinned) {
      final file = File(_pinnedPrinterFile);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode({'printer': _printerName}));
    }
  }

  Widget _copyImageButton() {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _busy ? null : () => _captureTable(toClipboard: true),
        child: Container(
          width: 200,
          height: 28,
          decoration: BoxDecoration(
            color: hovered ? kHoverYellow : _tileGrey,
            border: Border.all(
              color: hovered
                  ? const Color(0xFFC7A62B)
                  : const Color(0xFFE0E0E0),
            ),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            textDirection: TextDirection.ltr,
            children: const [
              Text('نسخة صورة', style: TextStyle(fontSize: 12.5, color: _ink)),
              SizedBox(width: 10),
              Icon(Icons.copy_rounded, size: 15, color: Color(0xFF111111)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _phoneField() {
    return Container(
      width: 200,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFBFBFBF)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
        style: const TextStyle(fontSize: 11.5, color: _ink),
        decoration: const InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          hintText: 'Ex. +2012345678',
          hintStyle: TextStyle(fontSize: 11.5, color: Color(0xFF8A8A8A)),
        ),
      ),
    );
  }

  Widget _cancelButton() {
    return HoverBuilder(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: 105,
          height: 28,
          decoration: BoxDecoration(
            color: hovered ? kHoverYellow : _tileGrey,
            border: Border.all(
              color: hovered
                  ? const Color(0xFFC7A62B)
                  : const Color(0xFFD8D8D8),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            textDirection: TextDirection.ltr,
            children: [
              const Text(
                'إلغاء',
                style: TextStyle(fontSize: 12.5, color: _ink),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.close,
                size: 15,
                color: hovered ? const Color(0xFF2B374A) : Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Brand icons, drawn as vectors so they match the reference without any
// network fonts or third-party icon packages.
// -----------------------------------------------------------------------------

class _PdfIcon extends StatelessWidget {
  const _PdfIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(30, 38), painter: const _PdfPainter());
  }
}

class _PdfPainter extends CustomPainter {
  const _PdfPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const red = Color(0xFFE03A2F);

    final page = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, w - 2, h - 2),
      const Radius.circular(2),
    );
    canvas.drawRRect(page, Paint()..color = Colors.white);
    canvas.drawRRect(
      page,
      Paint()
        ..color = const Color(0xFFC4C4C4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Folded top-right corner.
    final fold = Path()
      ..moveTo(w - 10, 1.5)
      ..lineTo(w - 10, 9)
      ..lineTo(w - 2.5, 9)
      ..close();
    canvas.drawPath(fold, Paint()..color = const Color(0xFFEDEDED));
    canvas.drawPath(
      fold,
      Paint()
        ..color = const Color(0xFFC4C4C4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // Red rule above the "PDF" block.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(3.5, 12, (w - 7) * 0.6, 3),
        const Radius.circular(1.5),
      ),
      Paint()..color = red,
    );

    final label = TextPainter(
      text: const TextSpan(
        text: 'PDF',
        style: TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final box = Rect.fromLTWH(2.5, 18, w - 5, 14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(2)),
      Paint()..color = red,
    );
    label.paint(
      canvas,
      Offset(box.center.dx - label.width / 2, box.center.dy - label.height / 2),
    );
  }

  @override
  bool shouldRepaint(_PdfPainter oldDelegate) => false;
}

class _ExcelIcon extends StatelessWidget {
  const _ExcelIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(40, 40),
      painter: const _ExcelPainter(),
    );
  }
}

class _ExcelPainter extends CustomPainter {
  const _ExcelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const green = Color(0xFF217337);
    const darkGreen = Color(0xFF1A5C2C);

    // The white spreadsheet sheet on the right, holding the green grid.
    final sheet = RRect.fromRectAndRadius(
      const Rect.fromLTWH(21, 6, 19, 28),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(sheet, Paint()..color = const Color(0xFFFBFDFB));
    canvas.drawRRect(
      sheet,
      Paint()
        ..color = const Color(0xFFD7E4D9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    final cell = Paint()..color = green;
    for (var col = 0; col < 3; col++) {
      for (var row = 0; row < 3; row++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(25.5 + col * 4.6, 10.5 + row * 5.4, 3.4, 3.6),
            const Radius.circular(0.6),
          ),
          cell,
        );
      }
    }

    // Green book cover on the left with the white "X".
    final book = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 3, 26, 34),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(book, Paint()..color = green);
    canvas.drawRect(
      const Rect.fromLTWH(22.5, 3, 3.5, 34),
      Paint()..color = darkGreen,
    );

    final xPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(const Offset(7.5, 12), const Offset(18.5, 28), xPaint);
    canvas.drawLine(const Offset(18.5, 12), const Offset(7.5, 28), xPaint);
  }

  @override
  bool shouldRepaint(_ExcelPainter oldDelegate) => false;
}

class _WhatsAppIcon extends StatelessWidget {
  const _WhatsAppIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(40, 40),
            painter: const _WhatsAppBubblePainter(),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 2),
            child: Icon(Icons.phone, size: 19, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _WhatsAppBubblePainter extends CustomPainter {
  const _WhatsAppBubblePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const green = Color(0xFF25D353);
    final center = Offset(size.width / 2, size.height / 2 - 1);
    final r = size.width / 2 - 3.2;

    final bubble = Path()..addOval(Rect.fromCircle(center: center, radius: r));
    final tail = Path()
      ..moveTo(center.dx - r * 0.66, center.dy + r * 0.52)
      ..lineTo(center.dx - r * 0.92, center.dy + r * 0.96)
      ..lineTo(center.dx - r * 0.24, center.dy + r * 0.78)
      ..close();

    final combined = Path.combine(PathOperation.union, bubble, tail);

    // White outline ring matches the reference sticker look.
    canvas.drawPath(
      combined,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(combined, Paint()..color = green);
  }

  @override
  bool shouldRepaint(_WhatsAppBubblePainter oldDelegate) => false;
}

class _PngIcon extends StatelessWidget {
  const _PngIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(44, 34), painter: const _PngPainter());
  }
}

class _PngPainter extends CustomPainter {
  const _PngPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(3));

    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEAF7FF), Color(0xFFCBDDFA)],
        ).createShader(rect),
    );
    canvas.drawCircle(
      Offset(size.width * 0.22, size.height * 0.26),
      size.width * 0.085,
      Paint()..color = const Color(0xFFF5C544),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height)
        ..lineTo(size.width * 0.42, size.height * 0.30)
        ..lineTo(size.width * 0.78, size.height)
        ..close(),
      Paint()..color = const Color(0xFF2FA44E),
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.30, size.height)
        ..lineTo(size.width * 0.66, size.height * 0.46)
        ..lineTo(size.width, size.height)
        ..close(),
      Paint()..color = const Color(0xFF1F7F39),
    );
    canvas.restore();

    canvas.drawRRect(
      rr,
      Paint()
        ..color = const Color(0xFFBFC9DA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_PngPainter oldDelegate) => false;
}
