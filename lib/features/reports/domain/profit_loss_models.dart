/// Domain models for الأرباح والخسائر.
///
/// The statement is built from invoice revenue, historical line costs, sales
/// returns and the real treasury ledger. It never subtracts purchase totals
/// from sales totals: cost of goods sold comes from the cost snapshot stored on
/// each sold line.
library;

class ProfitLossException implements Exception {
  const ProfitLossException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProfitLossOption {
  const ProfitLossOption({required this.id, required this.name});

  final int id;
  final String name;
}

class ProfitLossFilters {
  const ProfitLossFilters({
    required this.from,
    required this.to,
    this.treasuryId,
    this.manualOnly = true,
    this.includeOtherIncome = true,
  });

  final DateTime from;
  final DateTime to;
  final int? treasuryId;

  /// When true, only manual treasury expenses/incomes are used. Invoice and
  /// account linked movements are ignored so they cannot overlap revenue/COGS.
  final bool manualOnly;
  final bool includeOtherIncome;
}

enum ProfitLossLineKind { header, normal, subtotal, total, profit }

class ProfitLossStatementLine {
  const ProfitLossStatementLine({
    required this.label,
    required this.amount,
    required this.kind,
  });

  final String label;
  final int amount;
  final ProfitLossLineKind kind;
}

class ProfitLossExpenseRow {
  const ProfitLossExpenseRow({required this.label, required this.amount});

  final String label;
  final int amount;
}

class ProfitLossDetailRow {
  const ProfitLossDetailRow({
    required this.date,
    required this.description,
    required this.type,
    this.debit = 0,
    this.credit = 0,
  });

  final DateTime date;
  final String description;
  final String type;
  final int debit;
  final int credit;
}

class ProfitLossReport {
  const ProfitLossReport({
    required this.filters,
    required this.sales,
    required this.salesReturns,
    required this.otherIncome,
    required this.cogs,
    required this.returnCogs,
    required this.expenses,
    required this.details,
    this.treasuryName = 'كل الخزائن',
  });

  final ProfitLossFilters filters;
  final int sales;
  final int salesReturns;
  final int otherIncome;
  final int cogs;
  final int returnCogs;

  /// Exactly three rows: the two biggest real treasury categories plus the
  /// remainder, padded with empty operational rows when data is sparse.
  final List<ProfitLossExpenseRow> expenses;
  final List<ProfitLossDetailRow> details;
  final String treasuryName;

  int get netSales => sales - salesReturns;
  int get netCogs => cogs - returnCogs;
  int get grossProfit => netSales + otherIncome - netCogs;
  int get totalExpenses => expenses.fold(0, (sum, row) => sum + row.amount);
  int get netProfit => grossProfit - totalExpenses;

  String get periodText =>
      '${filters.from.day.toString().padLeft(2, '0')}/'
      '${filters.from.month.toString().padLeft(2, '0')}/${filters.from.year}'
      ' - '
      '${filters.to.day.toString().padLeft(2, '0')}/'
      '${filters.to.month.toString().padLeft(2, '0')}/${filters.to.year}';

  /// The exact 16-row statement of the reference screen.
  List<ProfitLossStatementLine> get statement {
    final safeExpenses = List<ProfitLossExpenseRow>.from(expenses);
    final usedLabels = safeExpenses.map((row) => row.label).toSet();
    for (final fallback in const [
      'مصروفات أخرى',
      'مصروفات تشغيلية',
      'مصروفات إدارية',
    ]) {
      if (safeExpenses.length >= 3) break;
      if (usedLabels.add(fallback)) {
        safeExpenses.add(ProfitLossExpenseRow(label: fallback, amount: 0));
      }
    }
    return [
      const ProfitLossStatementLine(
        label: 'الإيرادات',
        amount: 0,
        kind: ProfitLossLineKind.header,
      ),
      ProfitLossStatementLine(
        label: 'المبيعات',
        amount: sales,
        kind: ProfitLossLineKind.normal,
      ),
      ProfitLossStatementLine(
        label: 'مرتجعات المبيعات',
        amount: -salesReturns,
        kind: ProfitLossLineKind.normal,
      ),
      ProfitLossStatementLine(
        label: 'صافي المبيعات',
        amount: netSales,
        kind: ProfitLossLineKind.subtotal,
      ),
      ProfitLossStatementLine(
        label: 'إيرادات أخرى',
        amount: otherIncome,
        kind: ProfitLossLineKind.normal,
      ),
      const ProfitLossStatementLine(
        label: 'تكلفة البضاعة المباعة',
        amount: 0,
        kind: ProfitLossLineKind.header,
      ),
      ProfitLossStatementLine(
        label: 'تكلفة المبيعات',
        amount: cogs,
        kind: ProfitLossLineKind.normal,
      ),
      ProfitLossStatementLine(
        label: 'مرتجعات التكلفة',
        amount: returnCogs,
        kind: ProfitLossLineKind.normal,
      ),
      ProfitLossStatementLine(
        label: 'صافي التكلفة',
        amount: netCogs,
        kind: ProfitLossLineKind.subtotal,
      ),
      ProfitLossStatementLine(
        label: 'إجمالي الإيرادات / الربح الإجمالي',
        amount: grossProfit,
        kind: ProfitLossLineKind.total,
      ),
      const ProfitLossStatementLine(
        label: 'المصروفات',
        amount: 0,
        kind: ProfitLossLineKind.header,
      ),
      ProfitLossStatementLine(
        label: safeExpenses[0].label,
        amount: safeExpenses[0].amount,
        kind: ProfitLossLineKind.normal,
      ),
      ProfitLossStatementLine(
        label: safeExpenses[1].label,
        amount: safeExpenses[1].amount,
        kind: ProfitLossLineKind.normal,
      ),
      ProfitLossStatementLine(
        label: safeExpenses[2].label,
        amount: safeExpenses[2].amount,
        kind: ProfitLossLineKind.normal,
      ),
      ProfitLossStatementLine(
        label: 'إجمالي المصروفات',
        amount: totalExpenses,
        kind: ProfitLossLineKind.total,
      ),
      ProfitLossStatementLine(
        label: 'صافي الربح',
        amount: netProfit,
        kind: ProfitLossLineKind.profit,
      ),
    ];
  }
}
