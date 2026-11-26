import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart';

import 'package:safwa/features/reports/data/sales_analysis_repository.dart';
import 'package:safwa/features/reports/domain/sales_analysis_models.dart';

void main() {
  open.overrideFor(
    OperatingSystem.windows,
    () => DynamicLibrary.open(
      r'C:\sahl_app\build\windows\x64\runner\Release\sqlite3.dll',
    ),
  );
  final repo = SalesAnalysisRepository();
  final today = DateTime(2026, 11, 15);

  void show(String title, SalesAnalysisFilters filters,
      {SalesAnalysisGroup group = SalesAnalysisGroup.warehouse,
      SalesAnalysisMode mode = SalesAnalysisMode.simple}) {
    stdout.writeln('\n== $title');
    try {
      final report = repo.buildReport(
        filters: filters,
        group: group,
        mode: mode,
      );
      stdout.writeln(
        'rows=${report.rows.length} unavailable=${report.unavailableReason}',
      );
      for (final row in report.rows) {
        stdout.writeln(
          '${row.label} | ${row.subtitle} | inv=${row.invoices} '
          'stock=${row.currentQty} qty=${row.qty} total=${row.total} '
          'cost=${row.cost} profit=${row.profit} disc=${row.discount} '
          'pt=${row.profitToTotal.toStringAsFixed(2)} '
          'pc=${row.profitToCost.toStringAsFixed(2)} '
          'ts=${row.totalToSales.toStringAsFixed(2)} '
          'pp=${row.profitToProfit.toStringAsFixed(2)}',
        );
      }
      final t = report.totals;
      stdout.writeln(
        'TOTAL inv=${t.invoices} stock=${t.currentQty} qty=${t.qty} '
        'total=${t.total} cost=${t.cost} profit=${t.profit} disc=${t.discount} '
        'ts=${t.totalToSales.toStringAsFixed(2)} '
        'pp=${t.profitToProfit.toStringAsFixed(2)}',
      );
    } catch (error) {
      stdout.writeln('ERROR: $error');
    }
  }

  final base = SalesAnalysisFilters(from: today, to: today);
  show('today / warehouse / simple', base);
  show('today / warehouse / detailed', base,
      mode: SalesAnalysisMode.detailed);
  show('today / account / simple', base, group: SalesAnalysisGroup.account);
  show('today / product', base, group: SalesAnalysisGroup.product);
  show('today / month', base, group: SalesAnalysisGroup.month);
  show('today / day', base, group: SalesAnalysisGroup.day);
  show('today / year', base, group: SalesAnalysisGroup.year);
  show('today / weekday', base, group: SalesAnalysisGroup.weekday);
  show('today / time', base, group: SalesAnalysisGroup.time);
  show('today / user', base, group: SalesAnalysisGroup.user);
  show('today / salesRep', base, group: SalesAnalysisGroup.salesRep);

  SalesAnalysisFilters withAccount(int? id) => SalesAnalysisFilters(
        from: today,
        to: today,
        accountId: id,
      );
  show('account 2', withAccount(2));
  show('account 3', withAccount(3));
  show('account 6', withAccount(6));

  show(
    'payment cash',
    SalesAnalysisFilters(
      from: today,
      to: today,
      paymentMethod: SalesAnalysisFilters.paymentCash,
    ),
  );
  show(
    'payment credit',
    SalesAnalysisFilters(
      from: today,
      to: today,
      paymentMethod: SalesAnalysisFilters.paymentCredit,
    ),
  );
  show(
    'warehouse 1',
    SalesAnalysisFilters(from: today, to: today, warehouseId: 1),
  );
  show(
    'category 1',
    SalesAnalysisFilters(from: today, to: today, categoryId: 1),
  );
  show(
    'empty day',
    SalesAnalysisFilters(
      from: DateTime(2026, 11, 16),
      to: DateTime(2026, 11, 16),
    ),
  );
  show(
    'invalid range',
    SalesAnalysisFilters(
      from: DateTime(2026, 11, 16),
      to: DateTime(2026, 11, 15),
    ),
  );
  show(
    'full week',
    SalesAnalysisFilters(
      from: DateTime(2026, 11, 9),
      to: DateTime(2026, 11, 15),
    ),
  );
  show(
    'combined account 2 + cash + warehouse none',
    SalesAnalysisFilters(
      from: today,
      to: today,
      accountId: 2,
      paymentMethod: SalesAnalysisFilters.paymentCash,
    ),
    mode: SalesAnalysisMode.detailed,
  );
}
