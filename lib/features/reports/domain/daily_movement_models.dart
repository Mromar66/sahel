/// Domain models for the daily movement report (تقرير الحركة اليومية).
///
/// The report is a read-only aggregation over the existing invoices, payment
/// vouchers, warehouse documents and the treasury ledger. Amounts are whole
/// pounds, exactly like the rest of the application.
class DailyMovementException implements Exception {
  const DailyMovementException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A treasury or warehouse entry shown in the filter combos.
class DailyMovementOption {
  const DailyMovementOption({required this.id, required this.name});

  final int id;
  final String name;
}

/// One line of the main summary grid.
class DailyMovementRow {
  const DailyMovementRow({
    required this.label,
    this.count = 0,
    this.total = 0,
    this.cash = 0,
    this.credit = 0,
    this.visibleCells = 4,
  });

  final String label;
  final int count;
  final int total;
  final int cash;
  final int credit;

  /// 4 = عدد الفواتير + الإجمالي + نقدي + أجل
  /// 2 = عدد الفواتير + الإجمالي
  /// 1 = عدد الفواتير only
  final int visibleCells;
}

/// The values of «ملخص حركة الخزينة» panel.
class DailyTreasurySummary {
  const DailyTreasurySummary({
    required this.cashSales,
    required this.cashSalesReturn,
    required this.cashPurchases,
    required this.cashPurchaseReturn,
    required this.receipts,
    required this.payments,
    required this.expenses,
    required this.previousBalance,
    required this.incoming,
    required this.outgoing,
    required this.netMovement,
    required this.finalBalance,
  });

  final int cashSales;
  final int cashSalesReturn;
  final int cashPurchases;
  final int cashPurchaseReturn;
  final int receipts;
  final int payments;
  final int expenses;
  final int previousBalance;
  final int incoming;
  final int outgoing;
  final int netMovement;
  final int finalBalance;
}

/// Everything the page needs to paint one report.
class DailyMovementReport {
  const DailyMovementReport({
    required this.from,
    required this.to,
    required this.treasuryId,
    required this.warehouseId,
    required this.treasuryName,
    required this.warehouseName,
    required this.rows,
    required this.treasury,
  });

  final DateTime from;
  final DateTime to;
  final int? treasuryId;
  final int? warehouseId;
  final String treasuryName;
  final String warehouseName;
  final List<DailyMovementRow> rows;
  final DailyTreasurySummary treasury;
}
