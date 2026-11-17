import 'package:inventory_app/core/database/sqlite_database.dart';
import 'package:inventory_app/features/reports/domain/daily_movement_models.dart';

/// Aggregates the daily movement report straight from the same tables used by
/// the بيع / شراء / الخزينة / المخزن screens. Nothing is cached: pressing
/// «عرض التقرير» always recalculates from the database.
class DailyMovementRepository {
  DailyMovementRepository._internal();

  static final DailyMovementRepository _instance =
      DailyMovementRepository._internal();

  factory DailyMovementRepository() => _instance;

  final _db = SqliteDatabase();

  // ---------------------------------------------------------------------------
  // Filter lookups.
  // ---------------------------------------------------------------------------
  List<DailyMovementOption> getTreasuries({bool activeOnly = true}) {
    final rows = _db.query(
      'SELECT id, name FROM treasuries '
      '${activeOnly ? 'WHERE is_active = 1 ' : ''}'
      'ORDER BY id',
    );
    return rows
        .map(
          (row) => DailyMovementOption(
            id: (row['id'] as num).toInt(),
            name: (row['name'] as String?) ?? 'خزينة',
          ),
        )
        .toList();
  }

  List<DailyMovementOption> getWarehouses({bool activeOnly = true}) {
    final rows = _db.query(
      'SELECT id, name FROM warehouses '
      '${activeOnly ? 'WHERE is_active = 1 ' : ''}'
      'ORDER BY id',
    );
    return rows
        .map(
          (row) => DailyMovementOption(
            id: (row['id'] as num).toInt(),
            name: (row['name'] as String?) ?? 'مخزن',
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Report.
  // ---------------------------------------------------------------------------
  DailyMovementReport buildReport({
    required DateTime from,
    required DateTime to,
    int? treasuryId,
    int? warehouseId,
  }) {
    if (from.isAfter(to)) {
      throw const DailyMovementException(
        'تاريخ البداية يجب أن يكون قبل تاريخ النهاية.',
      );
    }

    final fromIso = from.toIso8601String();
    final toIso = to.toIso8601String();
    final range = <Object?>[fromIso, toIso];

    final treasuryName = _treasuryName(treasuryId);
    final warehouseName = _warehouseName(warehouseId);

    // -----------------------------------------------------------------------
    // Main summary.
    // -----------------------------------------------------------------------
    final sales = _invoiceTotals(
      'SELECT COUNT(*) AS c, COALESCE(SUM(total), 0) AS total, '
      'COALESCE(SUM(paid_amount), 0) AS cash, '
      'COALESCE(SUM(remaining_amount), 0) AS credit '
      'FROM sales_invoices '
      'WHERE invoice_date >= ? AND invoice_date <= ? '
      'AND COALESCE(is_return, 0) = 0',
      range,
    );
    final salesReturns = _invoiceTotals(
      'SELECT COUNT(*) AS c, COALESCE(SUM(total), 0) AS total, '
      'COALESCE(SUM(paid_amount), 0) AS cash, '
      'COALESCE(SUM(remaining_amount), 0) AS credit '
      'FROM sales_invoices '
      'WHERE invoice_date >= ? AND invoice_date <= ? '
      'AND COALESCE(is_return, 0) = 1',
      range,
    );
    final purchases = _invoiceTotals(
      'SELECT COUNT(*) AS c, COALESCE(SUM(total), 0) AS total, '
      'COALESCE(SUM(paid_amount), 0) AS cash, '
      'COALESCE(SUM(remaining_amount), 0) AS credit '
      'FROM purchase_invoices '
      'WHERE invoice_date >= ? AND invoice_date <= ? '
      'AND COALESCE(is_return, 0) = 0',
      range,
    );
    final purchaseReturns = _invoiceTotals(
      'SELECT COUNT(*) AS c, COALESCE(SUM(total), 0) AS total, '
      'COALESCE(SUM(refunded_amount), 0) AS cash, '
      'COALESCE(SUM(remaining_amount), 0) AS credit '
      'FROM purchase_return_invoices '
      'WHERE return_date >= ? AND return_date <= ?',
      range,
    );

    // Standalone قبض / صرف vouchers only. Invoice receipts and refunds already
    // appear in the بيع / شراء / مرتجع rows, so counting them again here would
    // double the report.
    final receipts = _invoiceTotals(
      "SELECT COUNT(*) AS c, COALESCE(SUM(amount), 0) AS total, "
      "COALESCE(SUM(CASE WHEN payment_method = 'cash' THEN amount ELSE 0 END), 0) AS cash, "
      '0 AS credit '
      'FROM payments '
      'WHERE payment_date >= ? AND payment_date <= ? '
      "AND payment_type = 'receipt' "
      'AND (reference_type IS NULL OR reference_type NOT IN '
      "('sales_invoice', 'purchase_return'))",
      range,
    );
    final payments = _invoiceTotals(
      "SELECT COUNT(*) AS c, COALESCE(SUM(amount), 0) AS total, "
      "COALESCE(SUM(CASE WHEN payment_method = 'cash' THEN amount ELSE 0 END), 0) AS cash, "
      '0 AS credit '
      'FROM payments '
      'WHERE payment_date >= ? AND payment_date <= ? '
      "AND payment_type = 'payment' "
      'AND (reference_type IS NULL OR reference_type NOT IN '
      "('purchase_invoice', 'sales_return'))",
      range,
    );

    final warehouseExpenses = _invoiceTotals(
      'SELECT COUNT(*) AS c, COALESCE(SUM(amount), 0) AS total, '
      "COALESCE(SUM(CASE WHEN payment_id IS NOT NULL THEN amount ELSE 0 END), 0) AS cash, "
      '0 AS credit '
      'FROM expenses '
      'WHERE expense_date >= ? AND expense_date <= ?',
      range,
    );

    final stocktaking = _stockCount(
      'stocktaking_sessions',
      range,
      warehouseColumn: 'warehouse_id',
      warehouseId: warehouseId,
    );
    final transfers = _transferCount(range, warehouseId);
    final adjustments = _stockCount(
      'stock_adjustment_sessions',
      range,
      warehouseColumn: 'warehouse_id',
      warehouseId: warehouseId,
    );

    final rows = <DailyMovementRow>[
      _totalsRow('بيع', sales),
      _totalsRow('مرتجع بيع', salesReturns),
      _totalsRow('شراء', purchases),
      _totalsRow('مرتجع شراء', purchaseReturns),
      DailyMovementRow(
        label: 'قبض',
        count: receipts.count,
        total: receipts.total,
        cash: receipts.cash,
        credit: receipts.credit,
        visibleCells: 2,
      ),
      DailyMovementRow(
        label: 'صرف',
        count: payments.count,
        total: payments.total,
        cash: payments.cash,
        credit: payments.credit,
        visibleCells: 2,
      ),
      DailyMovementRow(
        label: 'مصروف مخزن',
        count: warehouseExpenses.count,
        total: warehouseExpenses.total,
        cash: warehouseExpenses.cash,
        credit: warehouseExpenses.credit,
        visibleCells: 2,
      ),
      DailyMovementRow(label: 'جرد مخزن', count: stocktaking, visibleCells: 1),
      DailyMovementRow(label: 'تحويل مخزن', count: transfers, visibleCells: 1),
      DailyMovementRow(
        label: 'تسوية مخزن',
        count: adjustments,
        visibleCells: 1,
      ),
    ];

    // -----------------------------------------------------------------------
    // Treasury summary.
    // -----------------------------------------------------------------------
    final treasury = _buildTreasurySummary(fromIso, toIso, treasuryId);

    return DailyMovementReport(
      from: from,
      to: to,
      treasuryId: treasuryId,
      warehouseId: warehouseId,
      treasuryName: treasuryName,
      warehouseName: warehouseName,
      rows: rows,
      treasury: treasury,
    );
  }

  DailyTreasurySummary _buildTreasurySummary(
    String fromIso,
    String toIso,
    int? treasuryId,
  ) {
    final treasuryClause = treasuryId == null ? '' : 'AND treasury_id = ? ';
    final periodParams = <Object?>[fromIso, toIso, ?treasuryId];

    final opening = _openingBalance(treasuryId);
    final previous = opening + _signedBefore(fromIso, treasuryId);

    final cashSales = _treasuryAmount(
      fromIso,
      toIso,
      treasuryId,
      'reference_type = ?',
      ['sales_invoice'],
      incoming: true,
    );
    final cashSalesReturn = _treasuryAmount(
      fromIso,
      toIso,
      treasuryId,
      'reference_type = ?',
      ['sales_return'],
      incoming: false,
    );
    final cashPurchases = _treasuryAmount(
      fromIso,
      toIso,
      treasuryId,
      'reference_type = ?',
      ['purchase_invoice'],
      incoming: false,
    );
    final cashPurchaseReturn = _treasuryAmount(
      fromIso,
      toIso,
      treasuryId,
      'reference_type = ?',
      ['purchase_return'],
      incoming: true,
    );

    final receipts = _treasuryAmount(
      fromIso,
      toIso,
      treasuryId,
      '(reference_type IS NULL OR reference_type NOT IN '
      "('sales_invoice', 'purchase_return')) "
      'AND COALESCE(is_transfer, 0) = 0',
      const [],
      incoming: true,
    );
    final payments = _treasuryAmount(
      fromIso,
      toIso,
      treasuryId,
      '(reference_type IS NULL OR reference_type NOT IN '
      "('purchase_invoice', 'sales_return')) "
      'AND COALESCE(is_transfer, 0) = 0',
      const [],
      incoming: false,
    );

    // Expense documents are stored separately from the cash ledger.
    final expensesRows = _db.query(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM expenses '
      'WHERE expense_date >= ? AND expense_date <= ?',
      [fromIso, toIso],
    );
    final expenses = _int(expensesRows.first['total']);

    final period = _db.query(
      'SELECT '
      "COALESCE(SUM(CASE WHEN transaction_type = 'receive' THEN amount ELSE 0 END), 0) AS incoming, "
      "COALESCE(SUM(CASE WHEN transaction_type = 'expense' THEN amount ELSE 0 END), 0) AS outgoing "
      'FROM treasury_transactions '
      'WHERE transaction_date >= ? AND transaction_date <= ? $treasuryClause',
      periodParams,
    );
    final incoming = _int(period.first['incoming']);
    final outgoing = _int(period.first['outgoing']);

    return DailyTreasurySummary(
      cashSales: cashSales,
      cashSalesReturn: cashSalesReturn,
      cashPurchases: cashPurchases,
      cashPurchaseReturn: cashPurchaseReturn,
      receipts: receipts,
      payments: payments,
      expenses: expenses,
      previousBalance: previous,
      incoming: incoming,
      outgoing: outgoing,
      netMovement: incoming - outgoing,
      finalBalance: previous + incoming - outgoing,
    );
  }

  int _treasuryAmount(
    String fromIso,
    String toIso,
    int? treasuryId,
    String extraWhere,
    List<Object?> extraParams, {
    required bool incoming,
  }) {
    final type = incoming ? 'receive' : 'expense';
    final treasuryClause = treasuryId == null ? '' : 'AND treasury_id = ? ';
    final rows = _db.query(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM treasury_transactions '
      "WHERE transaction_date >= ? AND transaction_date <= ? "
      "AND transaction_type = '$type' AND $extraWhere $treasuryClause",
      [fromIso, toIso, ...extraParams, ?treasuryId],
    );
    return _int(rows.first['total']);
  }

  int _openingBalance(int? treasuryId) {
    if (treasuryId != null) {
      final rows = _db.query(
        'SELECT opening_balance FROM treasuries WHERE id = ?',
        [treasuryId],
      );
      if (rows.isEmpty) {
        throw const DailyMovementException('الخزينة المحددة غير موجودة.');
      }
      return _int(rows.first['opening_balance']);
    }
    final rows = _db.query(
      'SELECT COALESCE(SUM(opening_balance), 0) AS total '
      'FROM treasuries WHERE is_active = 1',
    );
    return _int(rows.first['total']);
  }

  int _signedBefore(String beforeIso, int? treasuryId) {
    final treasuryClause = treasuryId == null ? '' : 'AND treasury_id = ? ';
    final rows = _db.query(
      "SELECT COALESCE(SUM(CASE WHEN transaction_type = 'receive' "
      'THEN amount ELSE -amount END), 0) AS total '
      'FROM treasury_transactions '
      'WHERE transaction_date < ? $treasuryClause',
      [beforeIso, ?treasuryId],
    );
    return _int(rows.first['total']);
  }

  DailyMovementRow _totalsRow(String label, _Totals totals) {
    return DailyMovementRow(
      label: label,
      count: totals.count,
      total: totals.total,
      cash: totals.cash,
      credit: totals.credit,
    );
  }

  _Totals _invoiceTotals(String sql, List<Object?> params) {
    final rows = _db.query(sql, params);
    final row = rows.first;
    return _Totals(
      count: _int(row['c']),
      total: _int(row['total']),
      cash: _int(row['cash']),
      credit: _int(row['credit']),
    );
  }

  int _stockCount(
    String table,
    List<Object?> range, {
    String? warehouseColumn,
    int? warehouseId,
  }) {
    var sql =
        'SELECT COUNT(*) AS c FROM $table '
        'WHERE session_date >= ? AND session_date <= ?';
    final params = <Object?>[...range];
    if (warehouseId != null && warehouseColumn != null) {
      sql += ' AND $warehouseColumn = ?';
      params.add(warehouseId);
    }
    final rows = _db.query(sql, params);
    return _int(rows.first['c']);
  }

  int _transferCount(List<Object?> range, int? warehouseId) {
    var sql =
        'SELECT COUNT(*) AS c FROM stock_transfer_sessions '
        'WHERE session_date >= ? AND session_date <= ?';
    final params = <Object?>[...range];
    if (warehouseId != null) {
      sql += ' AND (from_warehouse_id = ? OR to_warehouse_id = ?)';
      params.addAll([warehouseId, warehouseId]);
    }
    final rows = _db.query(sql, params);
    return _int(rows.first['c']);
  }

  String _treasuryName(int? id) {
    if (id == null) return 'كل الخزائن';
    final rows = _db.query('SELECT name FROM treasuries WHERE id = ?', [id]);
    if (rows.isEmpty) return 'كل الخزائن';
    return (rows.first['name'] as String?) ?? 'خزينة';
  }

  String _warehouseName(int? id) {
    if (id == null) return 'كل المخازن';
    final rows = _db.query('SELECT name FROM warehouses WHERE id = ?', [id]);
    if (rows.isEmpty) return 'كل المخازن';
    return (rows.first['name'] as String?) ?? 'مخزن';
  }

  static int _int(Object? value) => (value as num?)?.toInt() ?? 0;
}

class _Totals {
  const _Totals({
    this.count = 0,
    this.total = 0,
    this.cash = 0,
    this.credit = 0,
  });

  final int count;
  final int total;
  final int cash;
  final int credit;
}
