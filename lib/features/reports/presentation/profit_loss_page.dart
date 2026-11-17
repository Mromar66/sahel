import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import 'package:printing/printing.dart';

import 'package:inventory_app/app/shell/app_top_bar.dart';
import 'package:inventory_app/app/theme/shop_colors.dart';
import 'package:inventory_app/app/widgets/hover_widgets.dart';
import 'package:inventory_app/features/products/presentation/export_dialog.dart';
import 'package:inventory_app/features/reports/data/profit_loss_repository.dart';
import 'package:inventory_app/features/reports/domain/profit_loss_models.dart';

part 'profit_loss_layout.dart';

const Color _kYellow = ShopColors.yellow;
const Color _kGreen = ShopColors.panelGreen;
const Color _kSoft = ShopColors.soft;
const Color _kInk = ShopColors.ink;
const Color _kHeader = Color(0xFFDDDDDD);

final intl.NumberFormat _kNumberFormat = intl.NumberFormat('#,##0', 'en');

String _money(int value) => _kNumberFormat.format(value);

String _dateText(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

DateTime? _parseDate(String text) {
  final parts = text.trim().split(RegExp(r'[/\-.]'));
  if (parts.length != 3) return null;
  int? day;
  int? month;
  int? year;
  if (parts[0].trim().length == 4) {
    year = int.tryParse(parts[0].trim());
    month = int.tryParse(parts[1].trim());
    day = int.tryParse(parts[2].trim());
  } else {
    day = int.tryParse(parts[0].trim());
    month = int.tryParse(parts[1].trim());
    year = int.tryParse(parts[2].trim());
  }
  if (day == null || month == null || year == null) return null;
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}

String _errorText(Object error) =>
    error is ProfitLossException ? error.message : 'تعذر تنفيذ العملية: $error';

/// الأرباح والخسائر — the real profit and loss statement of the shop.
class ProfitLossPage extends StatefulWidget {
  const ProfitLossPage({super.key});

  @override
  State<ProfitLossPage> createState() => _ProfitLossPageState();
}

class _ProfitLossPageState extends State<ProfitLossPage> {
  final _repo = ProfitLossRepository();
  final _pageFocus = FocusScopeNode(debugLabel: 'profit-loss-page');
  final _reportBoundaryKey = GlobalKey();
  final _rowsScroll = ScrollController();

  final _fromDate = TextEditingController();
  final _toDate = TextEditingController();

  List<ProfitLossOption> _treasuries = const [];
  int? _treasuryId;
  bool _manualOnly = true;
  bool _showOtherIncome = true;
  bool _detailed = false;

  bool _loading = false;
  ProfitLossReport? _report;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate.text = _dateText(DateTime(now.year, now.month, 1));
    _toDate.text = _dateText(DateTime(now.year, now.month + 1, 0));
    _refreshFilterLists();
    _loadReport();
  }

  @override
  void dispose() {
    _pageFocus.dispose();
    _rowsScroll.dispose();
    _fromDate.dispose();
    _toDate.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers.
  // ---------------------------------------------------------------------------
  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _rebuild(VoidCallback fn) => setState(fn);

  void _close() => context.go('/');

  void _refreshFilterLists() {
    try {
      final treasuries = _repo.getTreasuries();
      if (!mounted) return;
      _rebuild(() {
        _treasuries = treasuries;
        if (_treasuryId != null &&
            !treasuries.any((item) => item.id == _treasuryId)) {
          _treasuryId = null;
        }
      });
    } catch (error) {
      _toast(_errorText(error));
    }
  }

  Future<bool> _loadReport({bool showToast = false}) async {
    final fromDate = _parseDate(_fromDate.text);
    final toDate = _parseDate(_toDate.text);
    if (fromDate == null || toDate == null) {
      _toast('صيغة التاريخ غير صحيحة. استخدم يوم/شهر/سنة.');
      return false;
    }
    if (fromDate.isAfter(toDate)) {
      _toast('تاريخ البداية يجب أن يكون قبل تاريخ النهاية.');
      return false;
    }

    _rebuild(() => _loading = true);
    try {
      final report = _repo.buildReport(
        ProfitLossFilters(
          from: fromDate,
          to: toDate,
          treasuryId: _treasuryId,
          manualOnly: _manualOnly,
          includeOtherIncome: _showOtherIncome,
        ),
      );
      if (!mounted) return false;
      _rebuild(() {
        _report = report;
        _loading = false;
      });
      if (showToast) _toast('تم تحديث قائمة الأرباح والخسائر.');
      return true;
    } catch (error) {
      if (!mounted) return false;
      _rebuild(() => _loading = false);
      _toast(_errorText(error));
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Filters.
  // ---------------------------------------------------------------------------
  Future<void> _pickDate(TextEditingController controller) async {
    final initial = _parseDate(controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    _rebuild(() => controller.text = _dateText(picked));
    _loadReport();
  }

  void _setTreasury(int? value) {
    _rebuild(() => _treasuryId = value);
    _loadReport();
  }

  void _setManualOnly(bool value) {
    if (!value && _manualOnly) {
      _toast(
        'سيتم احتساب الحركات المرتبطة بالحسابات والفواتير أيضاً. '
        'قد تتداخل مع الإيرادات والتكلفة.',
      );
    }
    _rebuild(() => _manualOnly = value);
    _loadReport();
  }

  void _setShowOtherIncome(bool value) {
    _rebuild(() => _showOtherIncome = value);
    _loadReport();
  }

  void _toggleDetailed() {
    _rebuild(() => _detailed = !_detailed);
  }

  // ---------------------------------------------------------------------------
  // Print / share.
  // ---------------------------------------------------------------------------
  List<String> get _exportHeaders => _detailed
      ? const ['التاريخ', 'البيان', 'النوع', 'مدين', 'دائن']
      : const ['البيان', 'المبلغ'];

  List<List<String>> _exportRows(ProfitLossReport report) {
    if (_detailed) {
      final rows = <List<String>>[
        for (final row in report.details)
          [
            _dateText(row.date),
            row.description,
            row.type,
            row.debit == 0 ? '' : _money(row.debit),
            row.credit == 0 ? '' : _money(row.credit),
          ],
      ];
      final debit = report.details.fold<int>(0, (sum, row) => sum + row.debit);
      final credit = report.details.fold<int>(
        0,
        (sum, row) => sum + row.credit,
      );
      rows.add(['الإجمالي', '', '', _money(debit), _money(credit)]);
      return rows;
    }
    return [
      for (final line in report.statement)
        [
          line.kind == ProfitLossLineKind.header ? line.label : line.label,
          line.kind == ProfitLossLineKind.header ? '' : _money(line.amount),
        ],
    ];
  }

  String _subtitle(ProfitLossReport report) {
    final basis = _manualOnly
        ? 'الحركات اليدوية فقط'
        : 'كل الحركات غير التحويلية';
    return '${report.periodText}  •  الخزينة: ${report.treasuryName}  '
        '•  الأساس: $basis';
  }

  ExportTable _exportTable(ProfitLossReport report) {
    return ExportTable(
      headers: _exportHeaders,
      rows: _exportRows(report),
      filePrefix: _detailed ? 'profit_loss_details' : 'profit_loss',
      printName: 'الأرباح والخسائر',
      printSentLabel: 'التقرير',
      emptyMessage: 'لا توجد بيانات لتصديرها.',
      whatsAppIntro:
          'الأرباح والخسائر\n'
          '${_subtitle(report)}\n'
          'صافي الربح: ${_money(report.netProfit)}',
      whatsAppLine: (row) {
        if (row[0].trim().isEmpty) return '';
        if (_detailed) {
          return '${row[0]} | ${row[2]} | ${row[1]} | ${row[3]} | ${row[4]}';
        }
        return '${row[0]} | ${row[1]}';
      },
      pdfTitle: 'الأرباح والخسائر',
      pdfSubtitle: _subtitle(report),
    );
  }

  Future<void> _print() async {
    final loaded = await _loadReport();
    if (!loaded || !mounted) return;
    final report = _report;
    if (report == null) return;
    try {
      final doc = await buildTablePdfDocument(
        title: 'الأرباح والخسائر',
        subtitle: _subtitle(report),
        headers: _exportHeaders,
        rows: _exportRows(report),
      );
      if (!mounted) return;
      if (doc == null) {
        _toast('تعذر تجهيز ملف الطباعة (خط عربي غير متوفر).');
        return;
      }
      final printed = await Printing.layoutPdf(
        onLayout: (format) => doc.save(),
        name: 'الأرباح والخسائر',
        windowsModernDialog: true,
      );
      if (!mounted) return;
      if (printed) _toast('تم إرسال قائمة الأرباح والخسائر إلى الطباعة.');
    } catch (_) {
      if (mounted) _toast('تعذر بدء الطباعة.');
    }
  }

  Future<void> _share() async {
    final loaded = await _loadReport();
    if (!loaded || !mounted) return;
    final report = _report;
    if (report == null) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await showTableExportDialog(
      context,
      table: _exportTable(report),
      tableBoundaryKey: _reportBoundaryKey,
    );
  }

  // ---------------------------------------------------------------------------
  // Keyboard.
  // ---------------------------------------------------------------------------
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f5) {
      _loadReport(showToast: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f12) {
      _print();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f11) {
      _share();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---------------------------------------------------------------------------
  // Build.
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return withPlainInputs(
      FocusScope(
        node: _pageFocus,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: AppShell(
          activeTab: AppTab.home,
          homeTabActive: false,
          extraTabLabel: 'الأرباح والخسائر',
          extraTabColor: Colors.white,
          extraTabTextColor: _kInk,
          onExtraTabClose: _close,
          hideActiveTab: true,
          extraTabWidth: 190,
          child: Container(
            color: Colors.white,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: 1018,
                    height: 618,
                    child: Column(
                      children: [
                        _buildToolbar(),
                        _buildFilters(),
                        _buildActions(),
                        Expanded(child: _buildContent(_report)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
