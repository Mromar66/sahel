import 'package:sqlite3/sqlite3.dart';

import 'package:inventory_app/core/database/sqlite_database.dart';
import 'package:inventory_app/features/reports/domain/profit_loss_models.dart';

/// Builds الأرباح والخسائر from real invoices, historical costs and the
/// treasury ledger.
///
/// Business rules:
/// - Revenue is `sales_invoices.total - tax`; `tax` is an invoice addition,
///   not VAT, and is not revenue.
/// - Returns are subtracted from revenue and their historical cost is
///   subtracted from COGS.
/// - COGS uses `sales_items.unit_cost`, the cost snapshot taken when the line
///   was sold, never the product's current price.
/// - Expenses and other income come from `treasury_transactions`. Transfers are
///   always excluded. By default only manual movements are used; the user can
///   opt into account/invoice linked movements, with the overlap that implies.
class ProfitLossRepository {
  ProfitLossRepository({Database? database})
    : _database = database ?? SqliteDatabase().db;

  final Database _database;

  Database get _db => _database;

  List<ProfitLossOption> getTreasuries() {
    final rows = _db.select(
      'SELECT id, name FROM treasuries ORDER BY name COLLATE NOCASE',
    );
    return [
      for (final row in rows)
        ProfitLossOption(
          id: (row['id'] as num?)?.toInt() ?? 0,
          name: '${row['name'] ?? ''}',
        ),
    ];
  }

  ProfitLossReport buildReport(ProfitLossFilters filters) {
    final salesRows = _loadSales(filters);
    var sales = 0;
    var salesReturns = 0;
    for (final row in salesRows) {
      if (row.isReturn) {
        salesReturns += row.revenue;
      } else {
        sales += row.revenue;
      }
    }

    final costRows = _loadCosts(filters);
    var cogs = 0;
    var returnCogs = 0;
    for (final row in costRows) {
      if (row.isReturn) {
        returnCogs += row.cost;
      } else {
        cogs += row.cost;
      }
    }

    final expenseMovements = _loadExpenses(filters);
    final incomeMovements = filters.includeOtherIncome
        ? _loadIncomes(filters)
        : const <_MoneyMovement>[];
    final otherIncome = incomeMovements.fold<int>(
      0,
      (sum, movement) => sum + movement.amount,
    );

    final details =
        <ProfitLossDetailRow>[
          for (final row in salesRows)
            row.isReturn
                ? ProfitLossDetailRow(
                    date: row.date,
                    description: row.number,
                    type: 'مرتجع بيع',
                    debit: row.revenue,
                  )
                : ProfitLossDetailRow(
                    date: row.date,
                    description: row.number,
                    type: 'فاتورة بيع',
                    credit: row.revenue,
                  ),
          for (final row in costRows)
            row.isReturn
                ? ProfitLossDetailRow(
                    date: row.date,
                    description: row.number,
                    type: 'تكلفة مرتجع',
                    credit: row.cost,
                  )
                : ProfitLossDetailRow(
                    date: row.date,
                    description: row.number,
                    type: 'تكلفة مبيعات',
                    debit: row.cost,
                  ),
          for (final movement in expenseMovements)
            ProfitLossDetailRow(
              date: movement.date,
              description: movement.description,
              type: 'مصروف',
              debit: movement.amount,
            ),
          for (final movement in incomeMovements)
            ProfitLossDetailRow(
              date: movement.date,
              description: movement.description,
              type: 'إيراد آخر',
              credit: movement.amount,
            ),
        ]..sort((a, b) {
          final byDate = a.date.compareTo(b.date);
          return byDate != 0 ? byDate : a.type.compareTo(b.type);
        });

    return ProfitLossReport(
      filters: filters,
      sales: sales,
      salesReturns: salesReturns,
      otherIncome: otherIncome,
      cogs: cogs,
      returnCogs: returnCogs,
      expenses: _expenseRows(expenseMovements),
      details: details,
      treasuryName: _nameOf(filters.treasuryId, getTreasuries()),
    );
  }

  // ---------------------------------------------------------------------------
  // Sales and cost.
  // ---------------------------------------------------------------------------
  List<_SalesRow> _loadSales(ProfitLossFilters filters) {
    final rows = _db.select(
      '''
      SELECT si.id, si.invoice_number, si.invoice_date,
             COALESCE(si.is_return, 0) AS is_return,
             si.total - COALESCE(si.tax, 0) AS revenue
      FROM sales_invoices si
      WHERE si.invoice_date >= ? AND si.invoice_date <= ?
      ORDER BY si.invoice_date, si.id
      ''',
      [
        _startOfDay(filters.from).toIso8601String(),
        _endOfDay(filters.to).toIso8601String(),
      ],
    );
    return [
      for (final row in rows)
        _SalesRow(
          number: '${row['invoice_number'] ?? ''}',
          date:
              DateTime.tryParse('${row['invoice_date'] ?? ''}') ??
              DateTime.now(),
          revenue: (row['revenue'] as num?)?.toInt() ?? 0,
          isReturn: ((row['is_return'] as num?)?.toInt() ?? 0) == 1,
        ),
    ];
  }

  List<_CostRow> _loadCosts(ProfitLossFilters filters) {
    final rows = _db.select(
      '''
      SELECT si.invoice_number, si.invoice_date,
             COALESCE(si.is_return, 0) AS is_return,
             COALESCE(SUM(
               it.quantity * COALESCE(NULLIF(it.unit_cost, 0), p.purchase_price, 0)
             ), 0) AS cost
      FROM sales_invoices si
      JOIN sales_items it ON it.invoice_id = si.id
      LEFT JOIN products p ON p.id = it.product_id
      WHERE si.invoice_date >= ? AND si.invoice_date <= ?
      GROUP BY si.id
      ORDER BY si.invoice_date, si.id
      ''',
      [
        _startOfDay(filters.from).toIso8601String(),
        _endOfDay(filters.to).toIso8601String(),
      ],
    );
    return [
      for (final row in rows)
        _CostRow(
          number: '${row['invoice_number'] ?? ''}',
          date:
              DateTime.tryParse('${row['invoice_date'] ?? ''}') ??
              DateTime.now(),
          cost: (row['cost'] as num?)?.toInt() ?? 0,
          isReturn: ((row['is_return'] as num?)?.toInt() ?? 0) == 1,
        ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Treasury expenses and income.
  // ---------------------------------------------------------------------------
  List<_MoneyMovement> _loadExpenses(ProfitLossFilters filters) {
    return _loadMovements(filters, 'expense', 'مصروف');
  }

  List<_MoneyMovement> _loadIncomes(ProfitLossFilters filters) {
    return _loadMovements(filters, 'receive', 'إيراد آخر');
  }

  List<_MoneyMovement> _loadMovements(
    ProfitLossFilters filters,
    String type,
    String fallbackDescription,
  ) {
    final where = <String>[
      'transaction_type = ?',
      'COALESCE(is_transfer, 0) = 0',
      'transaction_date >= ?',
      'transaction_date <= ?',
    ];
    final args = <Object?>[
      type,
      _startOfDay(filters.from).toIso8601String(),
      _endOfDay(filters.to).toIso8601String(),
    ];
    if (filters.treasuryId != null) {
      where.add('treasury_id = ?');
      args.add(filters.treasuryId);
    }
    if (filters.manualOnly) {
      where.add("COALESCE(reference_type, '') = 'manual'");
    }

    final rows = _db.select('''
      SELECT id, transaction_number, transaction_date, amount, description,
             notes, category
      FROM treasury_transactions
      WHERE ${where.join(' AND ')}
      ORDER BY transaction_date, id
      ''', args);
    return [
      for (final row in rows)
        _MoneyMovement(
          date:
              DateTime.tryParse('${row['transaction_date'] ?? ''}') ??
              DateTime.now(),
          amount: (row['amount'] as num?)?.toInt() ?? 0,
          category: '${row['category'] ?? ''}'.trim(),
          description: _movementDescription(row, fallbackDescription),
        ),
    ];
  }

  String _movementDescription(Map<String, dynamic> row, String fallback) {
    final number = '${row['transaction_number'] ?? ''}'.trim();
    final description = '${row['description'] ?? ''}'.trim();
    final category = '${row['category'] ?? ''}'.trim();
    final parts = <String>[
      if (number.isNotEmpty) number,
      if (category.isNotEmpty) category,
      if (description.isNotEmpty) description,
    ];
    return parts.isEmpty ? fallback : parts.join(' — ');
  }

  List<ProfitLossExpenseRow> _expenseRows(List<_MoneyMovement> movements) {
    final totals = <String, int>{};
    for (final movement in movements) {
      final label = movement.category.isEmpty
          ? 'مصروفات أخرى'
          : movement.category;
      totals[label] = (totals[label] ?? 0) + movement.amount;
    }
    if (totals.isEmpty) {
      return const [ProfitLossExpenseRow(label: 'مصروفات أخرى', amount: 0)];
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.length <= 2) {
      return [
        for (final entry in sorted)
          ProfitLossExpenseRow(label: entry.key, amount: entry.value),
      ];
    }
    var other = 0;
    for (var index = 2; index < sorted.length; index++) {
      other += sorted[index].value;
    }
    return [
      ProfitLossExpenseRow(label: sorted[0].key, amount: sorted[0].value),
      ProfitLossExpenseRow(label: sorted[1].key, amount: sorted[1].value),
      ProfitLossExpenseRow(label: 'مصروفات أخرى', amount: other),
    ];
  }

  String _nameOf(int? id, List<ProfitLossOption> options) {
    if (id == null) return 'كل الخزائن';
    for (final option in options) {
      if (option.id == id) return option.name;
    }
    return 'كل الخزائن';
  }

  static DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
}

class _SalesRow {
  const _SalesRow({
    required this.number,
    required this.date,
    required this.revenue,
    required this.isReturn,
  });

  final String number;
  final DateTime date;
  final int revenue;
  final bool isReturn;
}

class _CostRow {
  const _CostRow({
    required this.number,
    required this.date,
    required this.cost,
    required this.isReturn,
  });

  final String number;
  final DateTime date;
  final int cost;
  final bool isReturn;
}

class _MoneyMovement {
  const _MoneyMovement({
    required this.date,
    required this.amount,
    required this.category,
    required this.description,
  });

  final DateTime date;
  final int amount;
  final String category;
  final String description;
}
