import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import 'package:printing/printing.dart';

import 'package:safwa/app/shell/app_top_bar.dart';
import 'package:safwa/app/theme/shop_colors.dart';
import 'package:safwa/app/widgets/hover_widgets.dart';
import 'package:safwa/features/products/presentation/export_dialog.dart';
import 'package:safwa/features/reports/data/purchase_analysis_repository.dart';
import 'package:safwa/features/reports/domain/purchase_analysis_models.dart';

part 'purchase_analysis_layout.dart';

const Color _kYellow = ShopColors.yellow;
const Color _kGreen = ShopColors.panelGreen;
const Color _kSoft = ShopColors.soft;
const Color _kInk = ShopColors.ink;
const Color _kHeader = Color(0xFFDDDDDD);

final intl.NumberFormat _kNumberFormat = intl.NumberFormat('#,##0', 'en');
final intl.NumberFormat _kPercentFormat = intl.NumberFormat('0.##', 'en');

String _money(int value) => _kNumberFormat.format(value);

String _percent(double value) {
  if (!value.isFinite || value == 0) return '0';
  return _kPercentFormat.format(value);
}

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

String _errorText(Object error) => error is PurchaseAnalysisException
    ? error.message
    : 'تعذر تنفيذ العملية: $error';

/// تقرير تحليل المشتريات — the Safwa purchase analysis screen, backed by the
/// real purchase invoices, purchase returns, accounts, products and categories.
class PurchaseAnalysisPage extends StatefulWidget {
  const PurchaseAnalysisPage({super.key});

  @override
  State<PurchaseAnalysisPage> createState() => _PurchaseAnalysisPageState();
}

class _PurchaseAnalysisPageState extends State<PurchaseAnalysisPage> {
  final _repo = PurchaseAnalysisRepository();
  final _pageFocus = FocusScopeNode(debugLabel: 'purchase-analysis-page');
  final _reportBoundaryKey = GlobalKey();
  final _rowsScroll = ScrollController();

  final _fromDate = TextEditingController();
  final _toDate = TextEditingController();

  List<PurchaseAnalysisOption> _accounts = const [];
  List<PurchaseAnalysisOption> _categories = const [];

  int? _accountId;
  int? _categoryId;
  String _period = 'هذا الشهر';

  PurchaseAnalysisGroup _group = PurchaseAnalysisGroup.warehouse;
  PurchaseAnalysisMode _mode = PurchaseAnalysisMode.simple;
  _SortField _sortField = _SortField.totalCost;
  bool _sortAscending = false;

  bool _loading = false;
  PurchaseAnalysisReport? _report;

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
    _toDate.text = _dateText(DateTime(now.year, now.month, now.day));
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

  void _close() {
    removeCurrentAppTab(context);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _refreshFilterLists() {
    try {
      final accounts = _repo.getAccounts();
      final categories = _repo.getCategories();
      if (!mounted) return;
      _rebuild(() {
        _accounts = accounts;
        _categories = categories;
        if (_accountId != null &&
            !accounts.any((item) => item.id == _accountId)) {
          _accountId = null;
        }
        if (_categoryId != null &&
            !categories.any((item) => item.id == _categoryId)) {
          _categoryId = null;
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
        filters: PurchaseAnalysisFilters(
          from: fromDate,
          to: toDate,
          accountId: _accountId,
          categoryId: _categoryId,
        ),
        group: _group,
        mode: _mode,
      );
      if (!mounted) return false;
      _rebuild(() {
        _report = report;
        _loading = false;
        _applySortInPlace();
      });
      if (showToast) _toast('تم تحديث تقرير تحليل المشتريات.');
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
  void _applyPeriod(String period) {
    final now = DateTime.now();
    DateTime from;
    DateTime to;
    switch (period) {
      case 'أمس':
        final yesterday = now.subtract(const Duration(days: 1));
        from = DateTime(yesterday.year, yesterday.month, yesterday.day);
        to = DateTime(yesterday.year, yesterday.month, yesterday.day);
      case 'هذا الأسبوع':
        final start = now.subtract(
          Duration(days: (now.weekday - DateTime.saturday) % 7),
        );
        from = DateTime(start.year, start.month, start.day);
        to = DateTime(now.year, now.month, now.day);
      case 'هذا الشهر':
        from = DateTime(now.year, now.month, 1);
        to = DateTime(now.year, now.month, now.day);
      case 'هذا العام':
        from = DateTime(now.year, 1, 1);
        to = DateTime(now.year, now.month, now.day);
      case 'فترة مخصصة':
        _rebuild(() => _period = period);
        return;
      default:
        from = DateTime(now.year, now.month, now.day);
        to = DateTime(now.year, now.month, now.day);
    }
    _rebuild(() {
      _period = period;
      _fromDate.text = _dateText(from);
      _toDate.text = _dateText(to);
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
    _rebuild(() {
      controller.text = _dateText(picked);
      _period = 'فترة مخصصة';
    });
    _loadReport();
  }

  void _setAccount(int? value) {
    _rebuild(() => _accountId = value);
    _loadReport();
  }

  void _setCategory(int? value) {
    _rebuild(() => _categoryId = value);
    _loadReport();
  }

  void _setGroup(PurchaseAnalysisGroup group) {
    _rebuild(() => _group = group);
    _loadReport();
  }

  void _setMode(PurchaseAnalysisMode mode) {
    if (_mode == mode) {
      _loadReport(showToast: true);
      return;
    }
    _rebuild(() => _mode = mode);
    _loadReport(showToast: true);
  }

  // ---------------------------------------------------------------------------
  // Sorting.
  // ---------------------------------------------------------------------------
  void _sortBy(_SortField field) {
    _rebuild(() {
      if (_sortField == field) {
        _sortAscending = !_sortAscending;
      } else {
        _sortField = field;
        _sortAscending = field == _SortField.label;
      }
      _applySortInPlace();
    });
  }

  void _applySortInPlace() {
    final report = _report;
    if (report == null) return;
    final rows = List<PurchaseAnalysisRow>.from(report.rows);
    int compare(PurchaseAnalysisRow a, PurchaseAnalysisRow b) {
      switch (_sortField) {
        case _SortField.label:
          return a.label.compareTo(b.label);
        case _SortField.invoices:
          return a.invoices.compareTo(b.invoices);
        case _SortField.purchaseQty:
          return a.purchaseQty.compareTo(b.purchaseQty);
        case _SortField.purchaseTotal:
          return a.purchaseTotal.compareTo(b.purchaseTotal);
        case _SortField.returnQty:
          return a.returnQty.compareTo(b.returnQty);
        case _SortField.returnTotal:
          return a.returnTotal.compareTo(b.returnTotal);
        case _SortField.netQty:
          return a.netQty.compareTo(b.netQty);
        case _SortField.netTotal:
          return a.netTotal.compareTo(b.netTotal);
        case _SortField.expense:
          return a.expense.compareTo(b.expense);
        case _SortField.totalCost:
          return a.totalCost.compareTo(b.totalCost);
        case _SortField.share:
          return a.shareOfTotal.compareTo(b.shareOfTotal);
      }
    }

    rows.sort((a, b) {
      final result = compare(a, b);
      return _sortAscending ? result : -result;
    });
    _report = PurchaseAnalysisReport(
      rows: rows,
      totals: report.totals,
      filters: report.filters,
      group: report.group,
      mode: report.mode,
      periodText: report.periodText,
      unavailableReason: report.unavailableReason,
      accountName: report.accountName,
      categoryName: report.categoryName,
      warehouseName: report.warehouseName,
    );
  }

  // ---------------------------------------------------------------------------
  // Print / share.
  // ---------------------------------------------------------------------------
  static const List<String> _exportHeaders = [
    'البيان',
    'فواتير',
    'المشتريات (كمية)',
    'المشتريات (إجمالي)',
    'المرتجعات (كمية)',
    'المرتجعات (إجمالي)',
    'الصافي (كمية)',
    'الصافي (إجمالي)',
    'مصروف',
    'إجمالي التكلفة',
    'نسبة الإجمالي للكل',
  ];

  String _subtitle(PurchaseAnalysisReport report) {
    return '${report.periodText}  •  ${report.mode.label}  '
        '•  التجميع: ${report.group.label}  '
        '•  الحساب: ${report.accountName}  '
        '•  التصنيف: ${report.categoryName}';
  }

  List<List<String>> _exportRows(PurchaseAnalysisReport report) {
    final rows = <List<String>>[
      for (final row in report.rows)
        [
          row.label,
          '${row.invoices}',
          _money(row.purchaseQty),
          _money(row.purchaseTotal),
          _money(row.returnQty),
          _money(row.returnTotal),
          _money(row.netQty),
          _money(row.netTotal),
          _money(row.expense),
          _money(row.totalCost),
          _percent(row.shareOfTotal),
        ],
    ];
    final totals = report.totals;
    rows.add([
      'الإجمالي',
      '${totals.invoices}',
      _money(totals.purchaseQty),
      _money(totals.purchaseTotal),
      _money(totals.returnQty),
      _money(totals.returnTotal),
      _money(totals.netQty),
      _money(totals.netTotal),
      _money(totals.expense),
      _money(totals.totalCost),
      totals.totalCost == 0 ? '' : '100',
    ]);
    return rows;
  }

  ExportTable _exportTable(PurchaseAnalysisReport report) {
    return ExportTable(
      headers: _exportHeaders,
      rows: _exportRows(report),
      filePrefix: 'purchase_analysis',
      printName: 'تقرير تحليل المشتريات',
      printSentLabel: 'التقرير',
      emptyMessage: 'لا توجد مشتريات لتصديرها.',
      whatsAppIntro:
          'تقرير تحليل المشتريات\n'
          '${_subtitle(report)}\n'
          'عدد الفواتير: ${report.totals.invoices} — '
          'إجمالي التكلفة: ${_money(report.totals.totalCost)}',
      whatsAppLine: (row) {
        if (row[0].trim().isEmpty) return '';
        return '${row[0]} | الصافي: ${row[7]} | إجمالي التكلفة: ${row[9]}';
      },
      pdfTitle: 'تقرير تحليل المشتريات',
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
        title: 'تقرير تحليل المشتريات',
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
        name: 'تقرير تحليل المشتريات',
        windowsModernDialog: true,
      );
      if (!mounted) return;
      if (printed) _toast('تم إرسال تقرير تحليل المشتريات إلى الطباعة.');
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
          extraTabLabel: 'تقرير تحليل المشتريات',
          extraTabColor: Colors.white,
          extraTabTextColor: _kInk,
          onExtraTabClose: _close,
          hideActiveTab: true,
          extraTabWidth: 220,
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
                        _buildGroupTabs(),
                        _buildFilters(),
                        _buildActions(),
                        Expanded(
                          child: RepaintBoundary(
                            key: _reportBoundaryKey,
                            child: _buildReportTable(),
                          ),
                        ),
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

enum _SortField {
  label,
  invoices,
  purchaseQty,
  purchaseTotal,
  returnQty,
  returnTotal,
  netQty,
  netTotal,
  expense,
  totalCost,
  share,
}
