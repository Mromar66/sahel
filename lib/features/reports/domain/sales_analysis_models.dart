/// Domain models for تقرير تحليل المبيعات.
///
/// The report is built from the same sales tables used by the بيع screen:
/// `sales_invoices`, `sales_items` and `products` (with `categories`,
/// `accounts`, `warehouses` and `stock_movements` for the filters).
library;

class SalesAnalysisException implements Exception {
  const SalesAnalysisException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A lightweight filter option (account, category, warehouse, …).
class SalesAnalysisOption {
  const SalesAnalysisOption({required this.id, required this.name});

  final int id;
  final String name;
}

/// Every filter the reference screen exposes.
class SalesAnalysisFilters {
  const SalesAnalysisFilters({
    required this.from,
    required this.to,
    this.accountId,
    this.categoryId,
    this.warehouseId,
    this.userId,
    this.salesRepId,
    this.paymentMethod = paymentAll,
  });

  static const String paymentAll = 'all';
  static const String paymentCash = 'cash';
  static const String paymentCredit = 'credit';

  final DateTime from;
  final DateTime to;
  final int? accountId;
  final int? categoryId;
  final int? warehouseId;

  /// Kept for the reference UI. The current schema has no users table, so the
  /// list is empty and selecting one is impossible.
  final int? userId;

  /// Kept for the reference UI. The current schema has no sales-representative
  /// field, so the list is empty and selecting one is impossible.
  final int? salesRepId;

  final String paymentMethod;
}

/// The green dimension tabs of the reference screen.
enum SalesAnalysisGroup {
  warehouse('المخزن'),
  account('الحساب'),
  product('الصنف'),
  month('الشهر'),
  day('اليوم'),
  salesRep('مندوب البيع'),
  user('المستخدم'),
  category('تصنيف الصنف'),
  year('العام'),
  time('الوقت'),
  weekday('يوم الأسبوع');

  const SalesAnalysisGroup(this.label);

  final String label;

  /// Dimensions that cannot be sourced from the current database.
  bool get isUnavailable =>
      this == SalesAnalysisGroup.user || this == SalesAnalysisGroup.salesRep;
}

enum SalesAnalysisMode { simple, detailed }

/// One numeric row of the report. The reference grid itself has no label
/// column; product/group names are rendered in the frozen left gutter.
class SalesAnalysisRow {
  const SalesAnalysisRow({
    required this.label,
    this.subtitle = '',
    required this.invoices,
    required this.currentQty,
    required this.qty,
    required this.total,
    required this.cost,
    required this.profit,
    required this.discount,
    required this.profitToTotal,
    required this.profitToCost,
    required this.totalToSales,
    required this.profitToProfit,
  });

  final String label;
  final String subtitle;
  final int invoices;
  final int currentQty;
  final int qty;
  final int total;
  final int cost;
  final int profit;
  final int discount;

  /// Relative percentages already resolved against the report grand totals.
  final double profitToTotal;
  final double profitToCost;
  final double totalToSales;
  final double profitToProfit;
}

/// Footer aggregates. The reference footer shows the two share percentages,
/// the amount columns and the quantity columns; it deliberately leaves
/// «نسبة الربح للتكلفة», «نسبة الربح للإجمالي» and «فواتير» empty.
class SalesAnalysisTotals {
  const SalesAnalysisTotals({
    required this.invoices,
    required this.currentQty,
    required this.qty,
    required this.total,
    required this.cost,
    required this.profit,
    required this.discount,
    required this.profitToProfit,
    required this.totalToSales,
  });

  final int invoices;
  final int currentQty;
  final int qty;
  final int total;
  final int cost;
  final int profit;
  final int discount;
  final double profitToProfit;
  final double totalToSales;
}

class SalesAnalysisReport {
  const SalesAnalysisReport({
    required this.rows,
    required this.totals,
    required this.filters,
    required this.group,
    required this.mode,
    required this.periodText,
    this.unavailableReason,
    this.accountName = 'كل الحسابات',
    this.categoryName = 'كل التصنيفات',
    this.warehouseName = 'كل المخازن',
    this.paymentName = 'الكل',
  });

  final List<SalesAnalysisRow> rows;
  final SalesAnalysisTotals totals;
  final SalesAnalysisFilters filters;
  final SalesAnalysisGroup group;
  final SalesAnalysisMode mode;
  final String periodText;

  /// Set when the selected grouping cannot be produced from the schema
  /// (المستخدم / مندوب البيع).
  final String? unavailableReason;

  final String accountName;
  final String categoryName;
  final String warehouseName;
  final String paymentName;

  bool get isEmpty => rows.isEmpty;
}
