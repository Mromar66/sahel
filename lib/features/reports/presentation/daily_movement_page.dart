import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import 'package:printing/printing.dart';

import 'package:inventory_app/app/shell/app_top_bar.dart';
import 'package:inventory_app/app/theme/shop_colors.dart';
import 'package:inventory_app/app/widgets/hover_widgets.dart';
import 'package:inventory_app/features/products/presentation/export_dialog.dart';
import 'package:inventory_app/features/reports/data/daily_movement_repository.dart';
import 'package:inventory_app/features/reports/domain/daily_movement_models.dart';

part 'daily_movement_layout.dart';
part 'daily_movement_table.dart';

const Color _kYellow = ShopColors.yellow;
const Color _kGreen = ShopColors.panelGreen;
const Color _kSoft = ShopColors.soft;
const Color _kInk = ShopColors.ink;
const Color _kLine = Color(0xFFD4D4D4);
const Color _kCell = Color(0xFFEFEFEF);

/// The reference report tab is a bright sky-blue, not the app's darker blue.
const Color _kTabBlue = Color(0xFF5395FF);

final intl.NumberFormat _kNumberFormat = intl.NumberFormat('#,##0', 'en');

String _money(int value) => _kNumberFormat.format(value);

String _dateText(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

String _timeText(DateTime date) {
  final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final suffix = date.hour < 12 ? 'AM' : 'PM';
  return '${hour12.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')} $suffix';
}

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

DateTime? _parseTime(String text) {
  var raw = text.trim().toUpperCase();
  final isPm = raw.contains('PM');
  final isAm = raw.contains('AM');
  raw = raw.replaceAll('AM', '').replaceAll('PM', '').trim();
  final parts = raw.split(':');
  if (parts.isEmpty) return null;
  var hour = int.tryParse(parts[0].trim());
  final minute = int.tryParse(parts.length > 1 ? parts[1].trim() : '0');
  if (hour == null || minute == null || minute < 0 || minute > 59) {
    return null;
  }
  if (isPm && hour < 12) hour += 12;
  if (isAm && hour == 12) hour = 0;
  if (hour < 0 || hour > 23) return null;
  return DateTime(2000, 1, 1, hour, minute);
}

String _errorText(Object error) => error is DailyMovementException
    ? error.message
    : 'تعذر تنفيذ العملية: $error';

/// تقرير الحركة اليومية — the read-only daily summary of sales, purchases,
/// returns, vouchers, stock documents and the treasury.
class DailyMovementPage extends StatefulWidget {
  const DailyMovementPage({super.key});

  @override
  State<DailyMovementPage> createState() => _DailyMovementPageState();
}

class _DailyMovementPageState extends State<DailyMovementPage> {
  final _repo = DailyMovementRepository();
  final _pageFocus = FocusScopeNode(debugLabel: 'daily-movement-page');
  final _reportBoundaryKey = GlobalKey();

  final _fromDate = TextEditingController();
  final _fromTime = TextEditingController();
  final _toDate = TextEditingController();
  final _toTime = TextEditingController();

  List<DailyMovementOption> _treasuries = const [];
  List<DailyMovementOption> _warehouses = const [];
  int? _treasuryId;
  int? _warehouseId;
  String _period = 'اليوم';
  bool _pinned = false;
  bool _loading = false;
  DailyMovementReport? _report;

  static const List<String> _periods = [
    'اليوم',
    'أمس',
    'هذا الأسبوع',
    'هذا الشهر',
    'هذا العام',
    'فترة مخصصة',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate.text = _dateText(now);
    _fromTime.text = _timeText(DateTime(now.year, now.month, now.day));
    _toDate.text = _dateText(now);
    _toTime.text = _timeText(DateTime(now.year, now.month, now.day, 23, 59));
    _refreshFilterLists();
    _loadReport();
  }

  @override
  void dispose() {
    _pageFocus.dispose();
    for (final controller in [_fromDate, _fromTime, _toDate, _toTime]) {
      controller.dispose();
    }
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
      final warehouses = _repo.getWarehouses();
      if (!mounted) return;
      _rebuild(() {
        _treasuries = treasuries;
        _warehouses = warehouses;
        if (_treasuryId != null &&
            !treasuries.any((item) => item.id == _treasuryId)) {
          _treasuryId = null;
        }
        if (_warehouseId != null &&
            !warehouses.any((item) => item.id == _warehouseId)) {
          _warehouseId = null;
        }
      });
    } catch (error) {
      _toast(_errorText(error));
    }
  }

  Future<bool> _loadReport({bool showToast = false}) async {
    final fromDate = _parseDate(_fromDate.text);
    final fromTime = _parseTime(_fromTime.text);
    final toDate = _parseDate(_toDate.text);
    final toTime = _parseTime(_toTime.text);
    if (fromDate == null || toDate == null) {
      _toast('صيغة التاريخ غير صحيحة. استخدم يوم/شهر/سنة.');
      return false;
    }
    if (fromTime == null || toTime == null) {
      _toast('صيغة الوقت غير صحيحة. استخدم ساعة:دقيقة.');
      return false;
    }
    final from = DateTime(
      fromDate.year,
      fromDate.month,
      fromDate.day,
      fromTime.hour,
      fromTime.minute,
    );
    final to = DateTime(
      toDate.year,
      toDate.month,
      toDate.day,
      toTime.hour,
      toTime.minute,
      59,
      999,
    );
    if (from.isAfter(to)) {
      _toast('تاريخ البداية يجب أن يكون قبل تاريخ النهاية.');
      return false;
    }

    _rebuild(() => _loading = true);
    try {
      final report = _repo.buildReport(
        from: from,
        to: to,
        treasuryId: _treasuryId,
        warehouseId: _warehouseId,
      );
      if (!mounted) return false;
      _rebuild(() {
        _report = report;
        _loading = false;
      });
      if (showToast) _toast('تم تحديث تقرير الحركة اليومية.');
      return true;
    } catch (error) {
      if (!mounted) return false;
      _rebuild(() => _loading = false);
      _toast(_errorText(error));
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Period / date / time filters.
  // ---------------------------------------------------------------------------
  void _applyPeriod(String period) {
    final now = DateTime.now();
    DateTime from;
    DateTime to;
    switch (period) {
      case 'أمس':
        final yesterday = now.subtract(const Duration(days: 1));
        from = DateTime(yesterday.year, yesterday.month, yesterday.day);
        to = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59);
      case 'هذا الأسبوع':
        final start = now.subtract(
          Duration(days: (now.weekday - DateTime.saturday) % 7),
        );
        from = DateTime(start.year, start.month, start.day);
        to = DateTime(now.year, now.month, now.day, 23, 59);
      case 'هذا الشهر':
        from = DateTime(now.year, now.month, 1);
        to = DateTime(now.year, now.month, now.day, 23, 59);
      case 'هذا العام':
        from = DateTime(now.year, 1, 1);
        to = DateTime(now.year, now.month, now.day, 23, 59);
      case 'فترة مخصصة':
        _rebuild(() => _period = period);
        return;
      default:
        from = DateTime(now.year, now.month, now.day);
        to = DateTime(now.year, now.month, now.day, 23, 59);
    }
    _rebuild(() {
      _period = period;
      _fromDate.text = _dateText(from);
      _fromTime.text = _timeText(from);
      _toDate.text = _dateText(to);
      _toTime.text = _timeText(to);
    });
    _loadReport();
  }

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
    _rebuild(() => _period = 'فترة مخصصة');
    _loadReport();
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final parsed = _parseTime(controller.text);
    final initial = parsed == null
        ? TimeOfDay.now()
        : TimeOfDay(hour: parsed.hour, minute: parsed.minute);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;
    final value = DateTime(2000, 1, 1, picked.hour, picked.minute);
    _rebuild(() => controller.text = _timeText(value));
    _rebuild(() => _period = 'فترة مخصصة');
    _loadReport();
  }

  void _adjustTime(TextEditingController controller, int minutes) {
    final parsed = _parseTime(controller.text);
    if (parsed == null) {
      _toast('صيغة الوقت غير صحيحة. استخدم ساعة:دقيقة.');
      return;
    }
    final next = parsed.add(Duration(minutes: minutes));
    _rebuild(() => controller.text = _timeText(next));
    _rebuild(() => _period = 'فترة مخصصة');
    _loadReport();
  }

  void _resetFilters() {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final to = DateTime(now.year, now.month, now.day, 23, 59);
    _rebuild(() {
      _period = 'اليوم';
      _treasuryId = null;
      _warehouseId = null;
      _fromDate.text = _dateText(from);
      _fromTime.text = _timeText(from);
      _toDate.text = _dateText(to);
      _toTime.text = _timeText(to);
    });
    _loadReport(showToast: true);
  }

  void _togglePin() {
    _rebuild(() => _pinned = !_pinned);
    _toast(_pinned ? 'تم تثبيت الفترة.' : 'تم إلغاء تثبيت الفترة.');
  }

  void _setTreasury(int? value) {
    _rebuild(() => _treasuryId = value);
    _loadReport();
  }

  void _setWarehouse(int? value) {
    _rebuild(() => _warehouseId = value);
    _loadReport();
  }

  // ---------------------------------------------------------------------------
  // Print / share.
  // ---------------------------------------------------------------------------
  static const List<String> _exportHeaders = [
    'البيان',
    'عدد الفواتير',
    'الإجمالي',
    'نقدي',
    'أجل',
  ];

  String _periodText(DailyMovementReport report) {
    return 'من ${_dateText(report.from)} ${_timeText(report.from)} '
        'إلى ${_dateText(report.to)} ${_timeText(report.to)}';
  }

  String _subtitle(DailyMovementReport report) {
    return '${_periodText(report)}  •  الخزينة: ${report.treasuryName}  '
        '•  المخزن: ${report.warehouseName}';
  }

  List<List<String>> _exportRows(DailyMovementReport report) {
    final rows = <List<String>>[];
    for (final row in report.rows) {
      rows.add([
        row.label,
        row.visibleCells >= 1 ? _money(row.count) : '',
        row.visibleCells >= 2 ? _money(row.total) : '',
        row.visibleCells >= 4 ? _money(row.cash) : '',
        row.visibleCells >= 4 ? _money(row.credit) : '',
      ]);
    }
    rows.add(const ['', '', '', '', '']);
    rows.add(const ['ملخص حركة الخزينة', '', '', '', '']);
    for (final line in _treasuryLines(report.treasury)) {
      rows.add([line.label, '', _money(line.value), '', '']);
    }
    return rows;
  }

  ExportTable _exportTable(DailyMovementReport report) {
    return ExportTable(
      headers: _exportHeaders,
      rows: _exportRows(report),
      filePrefix: 'daily_movement',
      printName: 'تقرير الحركة اليومية',
      printSentLabel: 'التقرير',
      emptyMessage: 'لا توجد بيانات لتصديرها.',
      whatsAppIntro:
          'تقرير الحركة اليومية\n'
          '${_periodText(report)}\n'
          'الخزينة: ${report.treasuryName} — المخزن: ${report.warehouseName}',
      whatsAppLine: (row) {
        if (row[0].trim().isEmpty) return '';
        return '${row[0]} | عدد: ${row[1]} | الإجمالي: ${row[2]} | '
            'نقدي: ${row[3]} | أجل: ${row[4]}';
      },
      pdfTitle: 'تقرير الحركة اليومية',
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
        title: 'تقرير الحركة اليومية',
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
        name: 'تقرير الحركة اليومية',
        windowsModernDialog: true,
      );
      if (!mounted) return;
      if (printed) _toast('تم إرسال تقرير الحركة اليومية إلى الطباعة.');
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
          extraTabLabel: 'تقرير الحركة اليومية',
          extraTabColor: Colors.white,
          extraTabTextColor: _kInk,
          onExtraTabClose: _close,
          hideActiveTab: true,
          extraTabWidth: 230,
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                _buildToolbar(),
                _buildFilters(),
                const SizedBox(height: 14),
                _buildTabs(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    child: _buildReportArea(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
