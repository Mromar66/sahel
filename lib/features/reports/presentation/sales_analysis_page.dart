import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import 'package:printing/printing.dart';

import 'package:safwa/app/shell/app_top_bar.dart';
import 'package:safwa/app/theme/shop_colors.dart';
import 'package:safwa/app/widgets/hover_widgets.dart';
import 'package:safwa/features/products/presentation/export_dialog.dart';
import 'package:safwa/features/reports/data/sales_analysis_repository.dart';
import 'package:safwa/features/reports/domain/sales_analysis_models.dart';

part 'sales_analysis_layout.dart';

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

String _errorText(Object error) => error is SalesAnalysisException
    ? error.message
    : 'تعذر تنفيذ العملية: $error';

/// تقرير تحليل المبيعات — a fully interactive replica of the Safwa sales
/// analysis screen, backed by the real sales, return, product and account
/// tables of the application.
class SalesAnalysisPage extends StatefulWidget {
  const SalesAnalysisPage({super.key});

  @override
  State<SalesAnalysisPage> createState() => _SalesAnalysisPageState();
}

class _SalesAnalysisPageState extends State<SalesAnalysisPage> {
  final _repo = SalesAnalysisRepository();
  final _pageFocus = FocusScopeNode(debugLabel: 'sales-analysis-page');
  final _reportBoundaryKey = GlobalKey();
  final _rowsScroll = ScrollController();

  final _fromDate = TextEditingController();
  final _toDate = TextEditingController();

  List<SalesAnalysisOption> _accounts = const [];
  List<SalesAnalysisOption> _categories = const [];
  List<SalesAnalysisOption> _warehouses = const [];
  List<SalesAnalysisOption> _users = const [];
  List<SalesAnalysisOption> _salesReps = const [];

  int? _accountId;
  int? _categoryId;
  int? _warehouseId;
  int? _userId;
  int? _salesRepId;
  String _paymentMethod = SalesAnalysisFilters.paymentAll;
  String _period = 'اليوم';

  SalesAnalysisGroup _group = SalesAnalysisGroup.warehouse;
  SalesAnalysisMode _mode = SalesAnalysisMode.simple;
  _SortField _sortField = _SortField.total;
  bool _sortAscending = false;

  bool _loading = false;
  SalesAnalysisReport? _report;

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
    _fromDate.text = _dateText(DateTime(now.year, now.month, now.day));
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
      final warehouses = _repo.getWarehouses();
      final users = _repo.getUsers();
      final salesReps = _repo.getSalesReps();
      if (!mounted) return;
      _rebuild(() {
        _accounts = accounts;
        _categories = categories;
        _warehouses = warehouses;
        _users = users;
        _salesReps = salesReps;
        if (_accountId != null &&
            !accounts.any((item) => item.id == _accountId)) {
          _accountId = null;
        }
        if (_categoryId != null &&
            !categories.any((item) => item.id == _categoryId)) {
          _categoryId = null;
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
        filters: SalesAnalysisFilters(
          from: fromDate,
          to: toDate,
          accountId: _accountId,
          categoryId: _categoryId,
          warehouseId: _warehouseId,
          userId: _userId,
          salesRepId: _salesRepId,
          paymentMethod: _paymentMethod,
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
      if (showToast) _toast('تم تحديث تقرير تحليل المبيعات.');
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

  void _setWarehouse(int? value) {
    _rebuild(() => _warehouseId = value);
    _loadReport();
  }

  void _setUser(int? value) {
    if (_users.isEmpty) {
      _toast('لا توجد بيانات مستخدمين في قاعدة البيانات الحالية.');
      return;
    }
    _rebuild(() => _userId = value);
    _loadReport();
  }

  void _setSalesRep(int? value) {
    if (_salesReps.isEmpty) {
      _toast('لا توجد بيانات مندوبي بيع في قاعدة البيانات الحالية.');
      return;
    }
    _rebuild(() => _salesRepId = value);
    _loadReport();
  }

  void _setPaymentMethod(String value) {
    _rebuild(() => _paymentMethod = value);
    _loadReport();
  }

  void _setGroup(SalesAnalysisGroup group) {
    _rebuild(() => _group = group);
    _loadReport();
  }

  void _setMode(SalesAnalysisMode mode) {
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
    final rows = List<SalesAnalysisRow>.from(report.rows);
    int compare(SalesAnalysisRow a, SalesAnalysisRow b) {
      switch (_sortField) {
        case _SortField.label:
          return a.label.compareTo(b.label);
        case _SortField.invoices:
          return a.invoices.compareTo(b.invoices);
        case _SortField.currentQty:
          return a.currentQty.compareTo(b.currentQty);
        case _SortField.qty:
          return a.qty.compareTo(b.qty);
        case _SortField.total:
          return a.total.compareTo(b.total);
        case _SortField.cost:
          return a.cost.compareTo(b.cost);
        case _SortField.profit:
          return a.profit.compareTo(b.profit);
        case _SortField.discount:
          return a.discount.compareTo(b.discount);
        case _SortField.profitToProfit:
          return a.profitToProfit.compareTo(b.profitToProfit);
        case _SortField.totalToSales:
          return a.totalToSales.compareTo(b.totalToSales);
        case _SortField.profitToCost:
          return a.profitToCost.compareTo(b.profitToCost);
        case _SortField.profitToTotal:
          return a.profitToTotal.compareTo(b.profitToTotal);
      }
    }

    rows.sort((a, b) {
      final result = compare(a, b);
      return _sortAscending ? result : -result;
    });
    _report = SalesAnalysisReport(
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
      paymentName: report.paymentName,
    );
  }

  // ---------------------------------------------------------------------------
  // Print / share.
  // ---------------------------------------------------------------------------
  static const List<String> _exportHeaders = [
    'البيان',
    'فواتير',
    'الكمية الحالية',
    'الكمية',
    'الإجمالي',
    'التكلفة',
    'الربح',
    'الخصم',
    'نسبة الربح للإجمالي',
    'نسبة الربح للتكلفة',
    'نسبة الإجمالي للمبيعات',
    'نسبة الربح لإجمالي الربح',
  ];

  String _subtitle(SalesAnalysisReport report) {
    final mode = report.mode == SalesAnalysisMode.simple
        ? 'تقرير مبسط'
        : 'تقرير تفصيلي';
    return '${report.periodText}  •  $mode  •  التجميع: ${report.group.label}  '
        '•  الحساب: ${report.accountName}  •  المخزن: ${report.warehouseName}  '
        '•  التصنيف: ${report.categoryName}  •  السداد: ${report.paymentName}';
  }

  List<List<String>> _exportRows(SalesAnalysisReport report) {
    final rows = <List<String>>[
      for (final row in report.rows)
        [
          row.label,
          '${row.invoices}',
          _money(row.currentQty),
          _money(row.qty),
          _money(row.total),
          _money(row.cost),
          _money(row.profit),
          _money(row.discount),
          _percent(row.profitToTotal),
          _percent(row.profitToCost),
          _percent(row.totalToSales),
          _percent(row.profitToProfit),
        ],
    ];
    final totals = report.totals;
    rows.add([
      'الإجمالي',
      '',
      _money(totals.currentQty),
      _money(totals.qty),
      _money(totals.total),
      _money(totals.cost),
      _money(totals.profit),
      _money(totals.discount),
      '',
      '',
      _percent(totals.totalToSales),
      _percent(totals.profitToProfit),
    ]);
    return rows;
  }

  ExportTable _exportTable(SalesAnalysisReport report) {
    return ExportTable(
      headers: _exportHeaders,
      rows: _exportRows(report),
      filePrefix: 'sales_analysis',
      printName: 'تقرير تحليل المبيعات',
      printSentLabel: 'التقرير',
      emptyMessage: 'لا توجد مبيعات لتصديرها.',
      whatsAppIntro:
          'تقرير تحليل المبيعات\n'
          '${_subtitle(report)}\n'
          'عدد الفواتير: ${report.totals.invoices} — '
          'الإجمالي: ${_money(report.totals.total)}',
      whatsAppLine: (row) {
        if (row[0].trim().isEmpty) return '';
        return '${row[0]} | الإجمالي: ${row[4]} | الربح: ${row[6]}';
      },
      pdfTitle: 'تقرير تحليل المبيعات',
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
        title: 'تقرير تحليل المبيعات',
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
        name: 'تقرير تحليل المبيعات',
        windowsModernDialog: true,
      );
      if (!mounted) return;
      if (printed) _toast('تم إرسال تقرير تحليل المبيعات إلى الطباعة.');
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
          extraTabLabel: 'تقرير تحليل المبيعات',
          extraTabColor: Colors.white,
          extraTabTextColor: _kInk,
          onExtraTabClose: _close,
          hideActiveTab: true,
          extraTabWidth: 210,
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
  currentQty,
  qty,
  total,
  cost,
  profit,
  discount,
  profitToTotal,
  profitToCost,
  totalToSales,
  profitToProfit,
}
