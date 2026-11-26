import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import 'package:printing/printing.dart';

import 'package:safwa/app/shell/app_top_bar.dart';
import 'package:safwa/app/theme/shop_colors.dart';
import 'package:safwa/app/widgets/hover_widgets.dart';
import 'package:safwa/app/widgets/shared_data_grid.dart';
import 'package:safwa/app/widgets/shop_dialog_kit.dart';
import 'package:safwa/app/widgets/document_custom_fields.dart';
import 'package:safwa/core/services/document_custom_fields.dart';
import 'package:safwa/features/accounts/presentation/print_preview_dialog.dart';
import 'package:safwa/features/products/presentation/export_dialog.dart';
import 'package:safwa/features/treasury/data/treasury_movement_repository.dart';
import 'package:safwa/features/treasury/domain/treasury_movement_models.dart';

part 'treasury_movement_dialogs.dart';
part 'treasury_movement_layout.dart';
part 'treasury_movement_table.dart';

const Color _kYellow = ShopColors.yellow;
const Color _kGreen = ShopColors.green;
const Color _kPanelGreen = ShopColors.panelGreen;
const Color _kRed = ShopColors.red;
const Color _kBlue = ShopColors.blue;
const Color _kSoft = ShopColors.soft;
const Color _kField = ShopColors.field;
const Color _kInk = ShopColors.ink;
const Color _kLine = ShopColors.line;

final intl.NumberFormat _kMoneyFormat = intl.NumberFormat('#,##0', 'en');

String _money(int value) => _kMoneyFormat.format(value);

String _dateText(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

String _timeText(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:'
    '${date.minute.toString().padLeft(2, '0')}';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

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

String _errorText(Object error) => error is TreasuryValidationException
    ? error.message
    : 'تعذر تنفيذ العملية: $error';

/// حركة الخزينة — a fully wired treasury report built on the same shell,
/// fields, buttons and interactive [SharedDataGrid] used by شراء.
class TreasuryMovementPage extends StatefulWidget {
  const TreasuryMovementPage({super.key, this.newMovement});

  final String? newMovement;

  @override
  State<TreasuryMovementPage> createState() => _TreasuryMovementPageState();
}

class _TreasuryMovementPageState extends State<TreasuryMovementPage> {
  final _repo = TreasuryMovementRepository();
  final _summaryTable = TreasurySummaryTableController();
  final _movementTable = TreasuryMovementTableController();
  final _summaryGridKey = GlobalKey<SharedDataGridState<TreasurySummaryRow>>();
  final _movementGridKey = GlobalKey<SharedDataGridState<TreasuryMovement>>();
  final _summaryBoundaryKey = GlobalKey();
  final _pageFocus = FocusScopeNode(debugLabel: 'treasury-movement-page');

  final _fromDate = TextEditingController();
  final _fromTime = TextEditingController();
  final _toDate = TextEditingController();
  final _toTime = TextEditingController();
  final _numberFilter = TextEditingController();
  final _notesFilter = TextEditingController();

  List<TreasuryAccount> _treasuries = const [];
  int _treasuryFilter = 0;
  String _period = 'هذا الشهر';
  int _tab = 0;
  TreasuryReport? _report;
  bool _loading = false;
  String _status = '';

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
    _fromDate.text = _dateText(DateTime(now.year, now.month, 1));
    _fromTime.text = '00:00';
    _toDate.text = _dateText(now);
    _toTime.text = _timeText(now);
    _refresh(initial: true).then((_) {
      if (!mounted) return;
      if (widget.newMovement == 'expense') _openExpense();
      if (widget.newMovement == 'receive') _openReceive();
    });
  }

  @override
  void dispose() {
    _summaryTable.dispose();
    _movementTable.dispose();
    _pageFocus.dispose();
    for (final controller in [
      _fromDate,
      _fromTime,
      _toDate,
      _toTime,
      _numberFilter,
      _notesFilter,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

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

  void _close() {
    removeCurrentAppTab(context);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _refresh({bool initial = false}) async {
    try {
      final treasuries = _repo.getTreasuries();
      if (!mounted) return;
      setState(() {
        _treasuries = treasuries;
        if (_treasuryFilter != 0 &&
            !treasuries.any((t) => t.id == _treasuryFilter)) {
          _treasuryFilter = 0;
        }
      });
    } catch (error) {
      _toast(_errorText(error));
      return;
    }
    await _loadReport(showToast: !initial);
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

    setState(() => _loading = true);
    try {
      final filters = TreasuryFilters(
        from: from,
        to: to,
        treasuryId: _treasuryFilter == 0 ? null : _treasuryFilter,
        numberQuery: _numberFilter.text.trim(),
        notesQuery: _notesFilter.text.trim(),
      );
      final report = _repo.buildReport(filters);
      if (!mounted) return false;
      _summaryTable.setRows(report.summary);
      _movementTable.setRows(report.movements);
      setState(() {
        _report = report;
        _loading = false;
        _status =
            'آخر تحديث ${_timeText(DateTime.now())} — '
            '${report.movements.length - 2} حركة';
      });
      if (showToast) _toast('تم تحديث حركة الخزينة.');
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _loading = false);
      _toast(_errorText(error));
      return false;
    }
  }

  TreasuryFilters _currentFilters() {
    final fromDate = _parseDate(_fromDate.text) ?? DateTime.now();
    final fromTime = _parseTime(_fromTime.text) ?? DateTime(2000, 1, 1);
    final toDate = _parseDate(_toDate.text) ?? DateTime.now();
    final toTime = _parseTime(_toTime.text) ?? DateTime(2000, 1, 1, 23, 59);
    return TreasuryFilters(
      from: DateTime(
        fromDate.year,
        fromDate.month,
        fromDate.day,
        fromTime.hour,
        fromTime.minute,
      ),
      to: DateTime(
        toDate.year,
        toDate.month,
        toDate.day,
        toTime.hour,
        toTime.minute,
        59,
        999,
      ),
      treasuryId: _treasuryFilter == 0 ? null : _treasuryFilter,
      numberQuery: _numberFilter.text.trim(),
      notesQuery: _notesFilter.text.trim(),
    );
  }

  /// Widens the visible period when a saved movement falls outside it so the
  /// refreshed report always shows the row the user just added or edited.
  void _ensurePeriodCovers(DateTime movementDate) {
    final filters = _currentFilters();
    final beforeStart = movementDate.isBefore(filters.from);
    final afterEnd = movementDate.isAfter(filters.to);
    if (!beforeStart && !afterEnd) return;
    setState(() {
      _period = 'فترة مخصصة';
      if (beforeStart) {
        _fromDate.text = _dateText(movementDate);
        _fromTime.text = _timeText(movementDate);
      }
      if (afterEnd) {
        _toDate.text = _dateText(movementDate);
        _toTime.text = _timeText(movementDate);
      }
    });
  }

  void _applyPeriod(String value) {
    final now = DateTime.now();
    setState(() {
      _period = value;
      if (value == 'فترة مخصصة') return;
      late DateTime from;
      late DateTime to;
      switch (value) {
        case 'اليوم':
          from = DateTime(now.year, now.month, now.day);
          to = now;
        case 'أمس':
          final yesterday = now.subtract(const Duration(days: 1));
          from = DateTime(yesterday.year, yesterday.month, yesterday.day);
          to = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59);
        case 'هذا الأسبوع':
          final monday = now.subtract(Duration(days: now.weekday - 1));
          from = DateTime(monday.year, monday.month, monday.day);
          to = now;
        case 'هذا الشهر':
          from = DateTime(now.year, now.month, 1);
          to = now;
        case 'هذا العام':
          from = DateTime(now.year, 1, 1);
          to = now;
        default:
          return;
      }
      _fromDate.text = _dateText(from);
      _fromTime.text = '00:00';
      _toDate.text = _dateText(to);
      _toTime.text = _timeText(to);
    });
    if (value != 'فترة مخصصة') _loadReport();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initial = _parseDate(controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'اختر التاريخ',
      cancelText: 'إلغاء',
      confirmText: 'موافق',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: ShopColors.green,
            brightness: Brightness.light,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      controller.text = _dateText(picked);
      _period = 'فترة مخصصة';
    });
    await _loadReport();
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final initial = _parseTime(controller.text) ?? DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
      helpText: 'اختر الوقت',
      cancelText: 'إلغاء',
      confirmText: 'موافق',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: ShopColors.green,
            brightness: Brightness.light,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      controller.text =
          '${picked.hour.toString().padLeft(2, '0')}:'
          '${picked.minute.toString().padLeft(2, '0')}';
      _period = 'فترة مخصصة';
    });
    await _loadReport();
  }

  int? get _preferredTreasuryId {
    if (_treasuryFilter != 0) return _treasuryFilter;
    if (_tab == 0) {
      final row = _summaryTable.selectedRow;
      if (row != null && !row.isTotal) return row.treasuryId;
    }
    final movement = _movementTable.selectedMovement;
    if (movement != null) return movement.treasuryId;
    return _treasuries.isEmpty ? null : _treasuries.first.id;
  }

  // ---------------------------------------------------------------------------
  // Actions.
  // ---------------------------------------------------------------------------
  Future<void> _openReceive({DateTime? date, int? treasuryId}) async {
    if (_treasuries.isEmpty) {
      _toast('لا توجد خزائن نشطة.');
      return;
    }
    final input = await showDialog<TreasuryMovementInput>(
      context: context,
      builder: (_) => TreasuryMovementEntryDialog(
        mode: TreasuryEntryMode.receive,
        treasuries: _treasuries,
        initialTreasuryId: treasuryId ?? _preferredTreasuryId,
        initialDate: date ?? DateTime.now(),
        initialCustomFields: const {},
      ),
    );
    if (!mounted || input == null) return;
    try {
      await _repo.addReceive(input);
      if (!mounted) return;
      _ensurePeriodCovers(input.date);
      setState(() => _tab = 1);
      await _refresh();
      _toast('تم تسجيل قبض ${_money(input.amount)}.');
    } catch (error) {
      _toast(_errorText(error));
    }
  }

  Future<void> _openExpense({DateTime? date, int? treasuryId}) async {
    if (_treasuries.isEmpty) {
      _toast('لا توجد خزائن نشطة.');
      return;
    }
    final input = await showDialog<TreasuryMovementInput>(
      context: context,
      builder: (_) => TreasuryMovementEntryDialog(
        mode: TreasuryEntryMode.expense,
        treasuries: _treasuries,
        initialTreasuryId: treasuryId ?? _preferredTreasuryId,
        initialDate: date ?? DateTime.now(),
        initialCustomFields: const {},
      ),
    );
    if (!mounted || input == null) return;
    try {
      await _repo.addExpense(input);
      if (!mounted) return;
      _ensurePeriodCovers(input.date);
      setState(() => _tab = 1);
      await _refresh();
      _toast('تم تسجيل صرف ${_money(input.amount)}.');
    } catch (error) {
      _toast(_errorText(error));
    }
  }

  Future<void> _openTransfer({TreasuryMovement? existing}) async {
    if (_treasuries.length < 2) {
      _toast('أضف خزينة ثانية من إعدادات قاعدة البيانات لتنفيذ التحويل.');
      return;
    }
    TreasuryTransferInput? input;
    if (existing != null) {
      if (existing.transferGroup == null) {
        _toast('هذه الحركة ليست تحويلاً صالحاً.');
        return;
      }
      final legs = _repo.getTransferGroup(existing.transferGroup!);
      if (legs.length != 2) {
        _toast('لم يتم العثور على طرفي التحويل.');
        return;
      }
      final out = legs.firstWhere((leg) => leg.isOutgoing);
      final incoming = legs.firstWhere((leg) => leg.isIncoming);
      final description = _transferDescription(out.description);
      input = await showDialog<TreasuryTransferInput>(
        context: context,
        builder: (_) => TreasuryTransferDialog(
          treasuries: _treasuries,
          initialSourceId: out.treasuryId,
          initialDestinationId: incoming.treasuryId,
          initialAmount: out.amount,
          initialDate: out.date,
          initialDescription: description,
          initialCustomFields: DocumentCustomFields.values(
            DocumentTypes.treasuryTransfer,
            legs.firstWhere((leg) => leg.isIncoming).id,
          ),
          editing: true,
        ),
      );
      if (!mounted || input == null) return;
      try {
        await _repo.updateTransfer(existing.transferGroup!, input);
        if (!mounted) return;
        _ensurePeriodCovers(input.date);
        await _refresh();
        _toast('تم تعديل التحويل.');
      } catch (error) {
        _toast(_errorText(error));
      }
      return;
    }

    final preferred = _preferredTreasuryId;
    final source = _treasuries.any((t) => t.id == preferred)
        ? preferred!
        : _treasuries.first.id;
    final destination = _treasuries.firstWhere(
      (t) => t.id != source,
      orElse: () => _treasuries.first,
    );
    input = await showDialog<TreasuryTransferInput>(
      context: context,
      builder: (_) => TreasuryTransferDialog(
        treasuries: _treasuries,
        initialSourceId: source,
        initialDestinationId: destination.id,
        initialAmount: 0,
        initialDate: DateTime.now(),
        initialDescription: '',
        initialCustomFields: const {},
      ),
    );
    if (!mounted || input == null) return;
    try {
      await _repo.addTransfer(input);
      if (!mounted) return;
      _ensurePeriodCovers(input.date);
      setState(() => _tab = 1);
      await _refresh();
      _toast('تم تحويل ${_money(input.amount)} بين الخزائن.');
    } catch (error) {
      _toast(_errorText(error));
    }
  }

  String _transferDescription(String? description) {
    final raw = description?.trim() ?? '';
    final separator = raw.indexOf(': ');
    return separator >= 0 ? raw.substring(separator + 2).trim() : raw;
  }

  Future<void> _editSelected() async {
    final movement = _movementTable.selectedMovement;
    if (movement == null) {
      setState(() => _tab = 1);
      _toast('حدد حركة من تبويب «حركات» أولاً.');
      return;
    }
    if (movement.isTransfer) {
      await _openTransfer(existing: movement);
      return;
    }
    if (movement.hasReference) {
      _toast('لا يمكن تعديل حركة مرتبطة بفاتورة من هذه الشاشة.');
      return;
    }
    final input = await showDialog<TreasuryMovementInput>(
      context: context,
      builder: (_) => TreasuryMovementEntryDialog(
        mode: movement.isIncoming
            ? TreasuryEntryMode.receive
            : TreasuryEntryMode.expense,
        treasuries: _treasuries,
        initialTreasuryId: movement.treasuryId,
        initialDate: movement.date,
        initialAmount: movement.amount,
        initialDescription: movement.description ?? '',
        initialNotes: movement.notes ?? '',
        initialCategory: movement.category ?? '',
        initialCustomFields: DocumentCustomFields.values(
          movement.isIncoming
              ? DocumentTypes.treasuryReceive
              : DocumentTypes.treasuryExpense,
          movement.id,
        ),
        editing: true,
      ),
    );
    if (!mounted || input == null) return;
    try {
      await _repo.updateMovement(movement.id, input);
      if (!mounted) return;
      _ensurePeriodCovers(input.date);
      await _refresh();
      _toast('تم تعديل الحركة ${movement.referenceLabel}.');
    } catch (error) {
      _toast(_errorText(error));
    }
  }

  Future<void> _deleteSelected() async {
    final movement = _movementTable.selectedMovement;
    if (movement == null) {
      setState(() => _tab = 1);
      _toast('حدد حركة من تبويب «حركات» أولاً.');
      return;
    }
    if (movement.hasReference) {
      _toast('لا يمكن حذف حركة مرتبطة بفاتورة من هذه الشاشة.');
      return;
    }
    final ok = await showShopConfirm(
      context,
      title: movement.isTransfer ? 'حذف التحويل' : 'حذف الحركة',
      message: movement.isTransfer
          ? 'سيتم حذف طرفي التحويل ${movement.referenceLabel} '
                'بمبلغ ${_money(movement.amount)}. هل تريد المتابعة؟'
          : 'سيتم حذف الحركة ${movement.referenceLabel} '
                'بمبلغ ${_money(movement.amount)}. هل تريد المتابعة؟',
      confirmLabel: 'حذف',
    );
    if (!mounted || !ok) return;
    try {
      await _repo.deleteMovement(movement.id);
      await _refresh();
      _toast('تم حذف الحركة.');
    } catch (error) {
      _toast(_errorText(error));
    }
  }

  Future<void> _openDailyEntry() async {
    final day = _parseDate(_toDate.text) ?? DateTime.now();
    final from = DateTime(day.year, day.month, day.day);
    final to = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
    try {
      final report = _repo.buildReport(
        TreasuryFilters(
          from: from,
          to: to,
          treasuryId: _treasuryFilter == 0 ? null : _treasuryFilter,
        ),
      );
      if (!mounted) return;
      final action = await showDialog<String>(
        context: context,
        builder: (_) => TreasuryDailyEntryDialog(
          day: day,
          report: report,
          treasuries: _treasuries,
          treasuryFilter: _treasuryFilter,
        ),
      );
      if (!mounted || action == null) return;
      final now = DateTime.now();
      final entryDate = _sameDay(day, now) ? now : day;
      if (action == 'receive') {
        await _openReceive(
          date: entryDate,
          treasuryId: _treasuryFilter == 0 ? null : _treasuryFilter,
        );
      } else if (action == 'expense') {
        await _openExpense(
          date: entryDate,
          treasuryId: _treasuryFilter == 0 ? null : _treasuryFilter,
        );
      }
    } catch (error) {
      _toast(_errorText(error));
    }
  }

  Future<void> _openAnalysis({required bool expenses}) async {
    try {
      final filters = _currentFilters();
      final rows = expenses
          ? _repo.analyzeExpenses(filters)
          : _repo.analyzeReceipts(filters);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => TreasuryAnalysisDialog(
          title: expenses ? 'تحليل المصروفات' : 'تحليل المقبوضات',
          expenses: expenses,
          rows: rows,
          filters: filters,
          treasuryName: _report?.treasuryName ?? 'كل الخزائن',
        ),
      );
    } catch (error) {
      _toast(_errorText(error));
    }
  }

  // ---------------------------------------------------------------------------
  // Print / export / share.
  // ---------------------------------------------------------------------------
  static const _summaryColumns = [
    'الخزينة',
    'رصيد سابق',
    'وارد',
    'منصرف',
    'الرصيد',
  ];

  List<List<String>> _summaryRows(TreasuryReport report) {
    return report.summary
        .map(
          (row) => [
            row.treasuryName,
            _money(row.previousBalance),
            _money(row.incoming),
            _money(row.outgoing),
            _money(row.balance),
          ],
        )
        .toList();
  }

  String _reportPeriodText(TreasuryReport report) {
    return 'من ${_dateText(report.filters.from)} '
        '${_timeText(report.filters.from)} إلى '
        '${_dateText(report.filters.to)} ${_timeText(report.filters.to)}';
  }

  /// «عرض التقرير» opens the on-screen treasury summary report.
  Future<void> _viewReport() async {
    final loaded = await _loadReport();
    if (!loaded || !mounted) return;
    final report = _report;
    if (report == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => PrintPreviewDialog(
        title: 'ملخص حركة الخزينة',
        subtitle:
            '${report.treasuryName}  •  الفترة: ${_reportPeriodText(report)}  •  '
            'رصيد الخزينة الحالي: ${_money(report.currentBalance)}',
        columns: _summaryColumns,
        rows: _summaryRows(report),
        onPrint: () => _printSummary(report),
      ),
    );
  }

  /// «طباعة» prepares the same summary and hands it to the connected printer
  /// through the system print dialog.
  Future<void> _print() async {
    final loaded = await _loadReport();
    if (!loaded || !mounted) return;
    final report = _report;
    if (report == null) {
      _toast('اعرض التقرير أولاً.');
      return;
    }
    await _printSummary(report);
  }

  Future<void> _printSummary(TreasuryReport report) async {
    try {
      final doc = await buildTablePdfDocument(
        title: 'ملخص حركة الخزينة',
        subtitle: '${report.treasuryName} • ${_reportPeriodText(report)}',
        headers: _summaryColumns,
        rows: _summaryRows(report),
      );
      if (!mounted) return;
      if (doc == null) {
        _toast('تعذر تجهيز ملف الطباعة (خط عربي غير متوفر).');
        return;
      }
      final printed = await Printing.layoutPdf(
        onLayout: (format) => doc.save(),
        name: 'ملخص حركة الخزينة',
        windowsModernDialog: true,
      );
      if (!mounted) return;
      if (printed) {
        _toast('تم إرسال ملخص حركة الخزينة إلى الطباعة.');
      }
    } catch (_) {
      if (mounted) _toast('تعذر بدء الطباعة.');
    }
  }

  Future<void> _exportExcel() async {
    final report = _report;
    if (report == null) {
      _toast('اعرض التقرير أولاً.');
      return;
    }
    try {
      final dir = Directory('invoices');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/treasury_$stamp.csv');
      final buffer = StringBuffer('\uFEFF');
      if (_tab == 0) {
        buffer.writeln('الخزينة,رصيد سابق,وارد,منصرف,الرصيد');
        for (final row in report.summary) {
          buffer.writeln(
            '"${row.treasuryName}",${row.previousBalance},'
            '${row.incoming},${row.outgoing},${row.balance}',
          );
        }
      } else {
        buffer.writeln(
          'الحركة,التاريخ,الوقت,وارد,منصرف,الرصيد,القيمة,'
          'مصروف الخزينة,رقم الحركة',
        );
        for (final row in report.movements) {
          if (row.isSynthetic) continue;
          buffer.writeln(
            '"${row.typeLabel}",${_dateText(row.date)},${_timeText(row.date)},'
            '${row.displayIncoming == 0 ? '' : row.displayIncoming},'
            '${row.displayOutgoing == 0 ? '' : row.displayOutgoing},'
            '${row.balanceAfter},${row.amount},'
            '"${row.categoryLabel}","${row.referenceLabel}"',
          );
        }
      }
      await file.writeAsString(buffer.toString(), flush: true);
      if (!mounted) return;
      _toast('تم تصدير التقرير إلى ${file.path}');
    } catch (error) {
      _toast('تعذر التصدير إلى Excel: $error');
    }
  }

  ExportTable _summaryExportTable(TreasuryReport report) {
    final rows = _summaryRows(report);
    return ExportTable(
      headers: _summaryColumns,
      rows: rows,
      filePrefix: 'treasury_summary',
      printName: 'ملخص حركة الخزينة',
      printSentLabel: 'الملخص',
      emptyMessage: 'لا توجد خزائن لتصديرها.',
      whatsAppIntro:
          'ملخص حركة الخزينة (${report.treasuryName})\n'
          '${_reportPeriodText(report)}',
      whatsAppLine: (row) =>
          '${row[0]} | رصيد سابق: ${row[1]} | وارد: ${row[2]} | '
          'منصرف: ${row[3]} | الرصيد: ${row[4]}',
      pdfTitle: 'ملخص حركة الخزينة',
      pdfSubtitle: '${report.treasuryName} • ${_reportPeriodText(report)}',
    );
  }

  Future<void> _share() async {
    final loaded = await _loadReport();
    if (!loaded || !mounted) return;
    final report = _report;
    if (report == null) {
      _toast('اعرض التقرير أولاً.');
      return;
    }
    // The product share window captures the visible table; make sure the
    // summary table is the one mounted before opening it.
    if (_tab != 0) {
      _rebuild(() => _tab = 0);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    await showTableExportDialog(
      context,
      table: _summaryExportTable(report),
      tableBoundaryKey: _summaryBoundaryKey,
    );
  }

  // ---------------------------------------------------------------------------
  // Keyboard shortcuts.
  // ---------------------------------------------------------------------------
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isAltPressed) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.f2) {
      _openReceive();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f3) {
      _openExpense();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f4) {
      _print();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f5) {
      _refresh(initial: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f7) {
      _openTransfer();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f8) {
      _deleteSelected();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f9) {
      _editSelected();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f10) {
      _openDailyEntry();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f11) {
      _openAnalysis(expenses: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f12) {
      _openAnalysis(expenses: false);
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
          extraTabLabel: 'حركة الخزينة',
          extraTabColor: _kPanelGreen,
          extraTabTextColor: Colors.white,
          onExtraTabClose: _close,
          hideActiveTab: true,
          extraTabWidth: 210,
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                _buildToolbar(),
                _buildFilterPanel(),
                _buildFilterActions(),
                _buildCards(),
                _buildTabs(),
                Expanded(child: _buildTableArea()),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
