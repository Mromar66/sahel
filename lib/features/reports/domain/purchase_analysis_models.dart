/// Domain models for تقرير تحليل المشتريات.
///
/// The report reads the real purchase document tables:
/// `purchase_invoices` + `purchase_items` for what was bought, and
/// `purchase_return_invoices` + `purchase_return_items` for what was returned.
/// Neither table stores a warehouse, so the «المخزن» dimension has one honest
/// bucket: «غير محدد».
library;

class PurchaseAnalysisException implements Exception {
  const PurchaseAnalysisException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PurchaseAnalysisOption {
  const PurchaseAnalysisOption({required this.id, required this.name});

  final int id;
  final String name;
}

class PurchaseAnalysisFilters {
  const PurchaseAnalysisFilters({
    required this.from,
    required this.to,
    this.accountId,
    this.categoryId,
    this.warehouseId,
  });

  final DateTime from;
  final DateTime to;
  final int? accountId;
  final int? categoryId;
  final int? warehouseId;
}

/// The seven dimensions of the reference screen, in visual order.
enum PurchaseAnalysisGroup {
  warehouse('المخزن'),
  account('الحساب'),
  product('الصنف'),
  month('الشهور'),
  day('الأيام'),
  user('المستخدم', isUnavailable: true),
  category('تصنيف الصنف');

  const PurchaseAnalysisGroup(this.label, {this.isUnavailable = false});

  final String label;
  final bool isUnavailable;
}

enum PurchaseAnalysisMode {
  simple('تقرير مبسط'),
  detailed('تقرير تفصيلي');

  const PurchaseAnalysisMode(this.label);

  final String label;
}

/// One grouped row of the 10-column purchase grid.
class PurchaseAnalysisRow {
  const PurchaseAnalysisRow({
    required this.label,
    this.subtitle = '',
    required this.invoices,
    required this.purchaseQty,
    required this.purchaseTotal,
    required this.returnQty,
    required this.returnTotal,
    required this.netQty,
    required this.netTotal,
    required this.expense,
    required this.totalCost,
    required this.shareOfTotal,
  });

  final String label;
  final String subtitle;
  final int invoices;
  final int purchaseQty;
  final int purchaseTotal;
  final int returnQty;
  final int returnTotal;
  final int netQty;
  final int netTotal;

  /// The invoice-level addition (stored in `purchase_invoices.tax`) allocated
  /// to the group. It is not a tax; it is the expense column of the report.
  final int expense;
  final int totalCost;

  /// Percentage of this row's total cost out of the report grand total.
  final double shareOfTotal;
}

class PurchaseAnalysisTotals {
  const PurchaseAnalysisTotals({
    required this.invoices,
    required this.purchaseQty,
    required this.purchaseTotal,
    required this.returnQty,
    required this.returnTotal,
    required this.netQty,
    required this.netTotal,
    required this.expense,
    required this.totalCost,
  });

  final int invoices;
  final int purchaseQty;
  final int purchaseTotal;
  final int returnQty;
  final int returnTotal;
  final int netQty;
  final int netTotal;
  final int expense;
  final int totalCost;
}

class PurchaseAnalysisReport {
  const PurchaseAnalysisReport({
    required this.rows,
    required this.totals,
    required this.filters,
    required this.group,
    required this.mode,
    required this.periodText,
    this.unavailableReason,
    this.accountName = 'الكل',
    this.categoryName = 'الكل',
    this.warehouseName = 'الكل',
  });

  final List<PurchaseAnalysisRow> rows;
  final PurchaseAnalysisTotals totals;
  final PurchaseAnalysisFilters filters;
  final PurchaseAnalysisGroup group;
  final PurchaseAnalysisMode mode;
  final String periodText;
  final String? unavailableReason;
  final String accountName;
  final String categoryName;
  final String warehouseName;
}
