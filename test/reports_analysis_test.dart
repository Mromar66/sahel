import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:inventory_app/features/reports/data/profit_loss_repository.dart';
import 'package:inventory_app/features/reports/data/purchase_analysis_repository.dart';
import 'package:inventory_app/features/reports/data/sales_analysis_repository.dart';
import 'package:inventory_app/features/reports/domain/profit_loss_models.dart';
import 'package:inventory_app/features/reports/domain/purchase_analysis_models.dart';
import 'package:inventory_app/features/reports/domain/sales_analysis_models.dart';

const String _schema = '''
CREATE TABLE accounts (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  balance INTEGER DEFAULT 0,
  account_type TEXT,
  is_active INTEGER DEFAULT 1
);
CREATE TABLE categories (id INTEGER PRIMARY KEY, name TEXT NOT NULL);
CREATE TABLE products (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  category_id INTEGER,
  purchase_price INTEGER DEFAULT 0,
  current_stock INTEGER DEFAULT 0,
  is_active INTEGER DEFAULT 1
);
CREATE TABLE warehouses (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  is_active INTEGER DEFAULT 1
);
CREATE TABLE sales_invoices (
  id INTEGER PRIMARY KEY,
  invoice_number TEXT NOT NULL,
  account_id INTEGER,
  invoice_date TEXT NOT NULL,
  subtotal INTEGER NOT NULL,
  discount INTEGER DEFAULT 0,
  tax INTEGER DEFAULT 0,
  total INTEGER NOT NULL,
  remaining_amount INTEGER DEFAULT 0,
  is_return INTEGER DEFAULT 0,
  original_invoice_id INTEGER
);
CREATE TABLE sales_items (
  id INTEGER PRIMARY KEY,
  invoice_id INTEGER NOT NULL,
  product_id INTEGER,
  product_name TEXT NOT NULL,
  product_code TEXT DEFAULT '',
  quantity INTEGER NOT NULL,
  unit_price INTEGER NOT NULL,
  discount INTEGER DEFAULT 0,
  total INTEGER NOT NULL,
  unit_cost INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE stock_movements (
  id INTEGER PRIMARY KEY,
  product_id INTEGER,
  quantity INTEGER,
  movement_type TEXT,
  reference_id INTEGER,
  reference_type TEXT,
  from_warehouse_id INTEGER,
  to_warehouse_id INTEGER,
  movement_date TEXT
);
CREATE TABLE purchase_invoices (
  id INTEGER PRIMARY KEY,
  invoice_number TEXT NOT NULL,
  account_id INTEGER,
  invoice_date TEXT NOT NULL,
  subtotal INTEGER NOT NULL,
  discount INTEGER DEFAULT 0,
  tax INTEGER DEFAULT 0,
  total INTEGER NOT NULL,
  is_return INTEGER DEFAULT 0
);
CREATE TABLE purchase_items (
  id INTEGER PRIMARY KEY,
  invoice_id INTEGER NOT NULL,
  product_id INTEGER,
  product_name TEXT NOT NULL,
  product_code TEXT DEFAULT '',
  quantity INTEGER NOT NULL,
  unit_price INTEGER NOT NULL,
  discount INTEGER DEFAULT 0,
  total INTEGER NOT NULL
);
CREATE TABLE purchase_return_invoices (
  id INTEGER PRIMARY KEY,
  return_number TEXT NOT NULL,
  account_id INTEGER,
  original_invoice_id INTEGER,
  return_date TEXT NOT NULL,
  subtotal INTEGER NOT NULL,
  discount INTEGER DEFAULT 0,
  tax INTEGER DEFAULT 0,
  total INTEGER NOT NULL
);
CREATE TABLE purchase_return_items (
  id INTEGER PRIMARY KEY,
  return_id INTEGER NOT NULL,
  product_id INTEGER,
  product_name TEXT NOT NULL,
  product_code TEXT DEFAULT '',
  quantity INTEGER NOT NULL,
  unit_price INTEGER NOT NULL,
  discount INTEGER DEFAULT 0,
  total INTEGER NOT NULL
);
CREATE TABLE treasuries (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  opening_balance INTEGER DEFAULT 0,
  description TEXT,
  is_active INTEGER DEFAULT 1
);
CREATE TABLE treasury_transactions (
  id INTEGER PRIMARY KEY,
  transaction_number TEXT,
  transaction_date TEXT NOT NULL,
  transaction_time TEXT,
  amount INTEGER NOT NULL,
  transaction_type TEXT NOT NULL,
  description TEXT,
  notes TEXT,
  category TEXT,
  reference_id INTEGER,
  reference_type TEXT,
  balance_after INTEGER DEFAULT 0,
  created_at TEXT,
  treasury_id INTEGER,
  is_transfer INTEGER DEFAULT 0,
  transfer_group TEXT,
  peer_treasury_id INTEGER
);
''';

void main() {
  late Database db;

  setUp(() {
    db = sqlite3.openInMemory();
    db.execute(_schema);
    db.execute("INSERT INTO accounts VALUES (1, 'مورد أ', 0, 'supplier', 1)");
    db.execute("INSERT INTO accounts VALUES (2, 'عميل ب', 0, 'customer', 1)");
    db.execute("INSERT INTO categories VALUES (1, 'إلكترونيات')");
    db.execute("INSERT INTO products VALUES (1, 'صنف أ', 1, 900, 10, 1)");
    db.execute("INSERT INTO warehouses VALUES (1, 'المخزن الرئيسي', 1)");
  });

  tearDown(() => db.dispose());

  group('sales analysis historical cost', () {
    test('uses sales_items.unit_cost, not the current product price', () {
      db.execute(
        "INSERT INTO sales_invoices VALUES "
        "(1, 'INV-1', 2, '2026-11-05T10:00:00.000', 1000, 0, 0, 1000, 0, 0, NULL)",
      );
      db.execute(
        "INSERT INTO sales_invoices VALUES "
        "(2, 'SR-1', 2, '2026-11-06T10:00:00.000', 200, 0, 0, 200, 0, 1, 1)",
      );
      db.execute(
        "INSERT INTO sales_items VALUES "
        "(1, 1, 1, 'صنف أ', 'P1', 2, 500, 0, 1000, 300)",
      );
      db.execute(
        "INSERT INTO sales_items VALUES "
        "(2, 2, 1, 'صنف أ', 'P1', 1, 200, 0, 200, 300)",
      );

      final repo = SalesAnalysisRepository(database: db);
      final report = repo.buildReport(
        filters: SalesAnalysisFilters(
          from: DateTime(2026, 11, 1),
          to: DateTime(2026, 11, 30),
        ),
        group: SalesAnalysisGroup.product,
        mode: SalesAnalysisMode.simple,
      );

      expect(report.rows.single.qty, 1);
      expect(report.rows.single.total, 800);
      expect(report.rows.single.cost, 300);
      expect(report.rows.single.profit, 500);
      expect(report.totals.cost, 300);
    });
  });

  group('purchase analysis', () {
    setUp(() {
      db.execute(
        "INSERT INTO purchase_invoices VALUES "
        "(1, 'P-1', 1, '2026-11-04T10:00:00.000', 1000, 50, 30, 980, 0)",
      );
      db.execute(
        "INSERT INTO purchase_invoices VALUES "
        "(2, 'P-2', 1, '2026-11-05T10:00:00.000', 500, 0, 0, 500, 0)",
      );
      db.execute(
        "INSERT INTO purchase_items VALUES "
        "(1, 1, 1, 'صنف أ', 'P1', 2, 500, 0, 1000)",
      );
      db.execute(
        "INSERT INTO purchase_items VALUES "
        "(2, 2, 1, 'صنف أ', 'P1', 1, 500, 0, 500)",
      );
      db.execute(
        "INSERT INTO purchase_return_invoices VALUES "
        "(101, 'PR-1', 1, 1, '2026-11-10T10:00:00.000', 300, 0, 0, 300)",
      );
      db.execute(
        "INSERT INTO purchase_return_invoices VALUES "
        "(102, 'PR-2', 1, 1, '2026-11-11T10:00:00.000', 200, 0, 0, 200)",
      );
      db.execute(
        "INSERT INTO purchase_return_items VALUES "
        "(1, 101, 1, 'صنف أ', 'P1', 1, 300, 0, 300)",
      );
      db.execute(
        "INSERT INTO purchase_return_items VALUES "
        "(2, 102, 1, 'صنف أ', 'P1', 1, 200, 0, 200)",
      );
    });

    PurchaseAnalysisReport build({
      PurchaseAnalysisGroup group = PurchaseAnalysisGroup.account,
      PurchaseAnalysisMode mode = PurchaseAnalysisMode.simple,
      int? accountId,
    }) {
      return PurchaseAnalysisRepository(database: db).buildReport(
        filters: PurchaseAnalysisFilters(
          from: DateTime(2026, 11, 1),
          to: DateTime(2026, 11, 30),
          accountId: accountId,
        ),
        group: group,
        mode: mode,
      );
    }

    test('allocates invoice discount and addition into the ten columns', () {
      final report = build();
      final row = report.rows.single;
      expect(row.label, 'مورد أ');
      expect(row.invoices, 4);
      expect(row.purchaseQty, 3);
      expect(row.purchaseTotal, 1450);
      expect(row.returnQty, 2);
      expect(row.returnTotal, 500);
      expect(row.netQty, 1);
      expect(row.netTotal, 950);
      expect(row.expense, 30);
      expect(row.totalCost, 980);
      expect(row.shareOfTotal, 100);

      expect(report.totals.purchaseTotal, 1450);
      expect(report.totals.returnTotal, 500);
      expect(report.totals.netTotal, 950);
      expect(report.totals.totalCost, 980);
    });

    test('warehouse group is honestly unassigned', () {
      final report = build(group: PurchaseAnalysisGroup.warehouse);
      expect(report.rows.single.label, 'غير محدد');
    });

    test('user group reports that users do not exist', () {
      final report = build(group: PurchaseAnalysisGroup.user);
      expect(report.rows, isEmpty);
      expect(report.unavailableReason, isNotNull);
    });

    test('detailed mode lists every purchase and return line', () {
      final report = build(mode: PurchaseAnalysisMode.detailed);
      expect(report.rows.length, 4);
      expect(
        report.rows.map((row) => row.label),
        everyElement(contains('فاتورة')),
      );
    });

    test('date and account filters are applied in SQL', () {
      final empty = PurchaseAnalysisRepository(database: db).buildReport(
        filters: PurchaseAnalysisFilters(
          from: DateTime(2026, 12, 1),
          to: DateTime(2026, 12, 31),
        ),
        group: PurchaseAnalysisGroup.account,
        mode: PurchaseAnalysisMode.simple,
      );
      expect(empty.rows, isEmpty);
      expect(empty.totals.totalCost, 0);

      final otherAccount = build(accountId: 2);
      expect(otherAccount.rows, isEmpty);
    });
  });

  group('profit and loss', () {
    setUp(() {
      db.execute(
        "INSERT INTO sales_invoices VALUES "
        "(1, 'INV-1', 2, '2026-11-05T10:00:00.000', 1000, 0, 0, 1000, 0, 0, NULL)",
      );
      db.execute(
        "INSERT INTO sales_invoices VALUES "
        "(2, 'SR-1', 2, '2026-11-06T10:00:00.000', 200, 0, 0, 200, 0, 1, 1)",
      );
      db.execute(
        "INSERT INTO sales_invoices VALUES "
        "(3, 'INV-2', 2, '2026-11-07T10:00:00.000', 500, 0, 50, 550, 0, 0, NULL)",
      );
      db.execute(
        "INSERT INTO sales_items VALUES "
        "(1, 1, 1, 'صنف أ', 'P1', 2, 500, 0, 1000, 300)",
      );
      db.execute(
        "INSERT INTO sales_items VALUES "
        "(2, 2, 1, 'صنف أ', 'P1', 1, 200, 0, 200, 300)",
      );
      db.execute(
        "INSERT INTO sales_items VALUES "
        "(3, 3, 1, 'صنف أ', 'P1', 1, 500, 0, 500, 300)",
      );

      db.execute(
        "INSERT INTO treasuries VALUES (1, 'الخزينة الرئيسية', 0, NULL, 1)",
      );
      db.execute(
        "INSERT INTO treasuries VALUES (2, 'خزينة فرعية', 0, NULL, 1)",
      );
      db.execute(
        "INSERT INTO treasury_transactions (id, transaction_number, "
        "transaction_date, amount, transaction_type, description, category, "
        "reference_type, treasury_id, is_transfer) VALUES "
        "(1, 'EXP-1', '2026-11-02T10:00:00.000', 100, 'expense', 'إيجار', 'إيجار', 'manual', 1, 0)",
      );
      db.execute(
        "INSERT INTO treasury_transactions (id, transaction_number, "
        "transaction_date, amount, transaction_type, description, category, "
        "reference_type, treasury_id, is_transfer) VALUES "
        "(2, 'EXP-2', '2026-11-03T10:00:00.000', 50, 'expense', 'كهرباء', 'كهرباء', 'manual', 1, 0)",
      );
      db.execute(
        "INSERT INTO treasury_transactions (id, transaction_number, "
        "transaction_date, amount, transaction_type, description, category, "
        "reference_type, treasury_id, is_transfer) VALUES "
        "(3, 'EXP-3', '2026-11-04T10:00:00.000', 25, 'expense', 'إنترنت', 'إنترنت', 'manual', 1, 0)",
      );
      db.execute(
        "INSERT INTO treasury_transactions (id, transaction_number, "
        "transaction_date, amount, transaction_type, description, category, "
        "reference_type, treasury_id, is_transfer) VALUES "
        "(4, 'EXP-4', '2026-11-05T10:00:00.000', 10, 'expense', 'صيانة', 'صيانة', 'manual', 1, 0)",
      );
      db.execute(
        "INSERT INTO treasury_transactions (id, transaction_number, "
        "transaction_date, amount, transaction_type, description, category, "
        "reference_type, treasury_id, is_transfer) VALUES "
        "(5, 'EXP-5', '2026-11-06T10:00:00.000', 400, 'expense', 'دفعة مورد', 'مشتريات', 'purchase_invoice', 1, 0)",
      );
      db.execute(
        "INSERT INTO treasury_transactions (id, transaction_number, "
        "transaction_date, amount, transaction_type, description, category, "
        "reference_type, treasury_id, is_transfer) VALUES "
        "(6, 'REC-1', '2026-11-07T10:00:00.000', 40, 'receive', 'إيراد متنوع', 'إيراد متنوع', 'manual', 1, 0)",
      );
      db.execute(
        "INSERT INTO treasury_transactions (id, transaction_number, "
        "transaction_date, amount, transaction_type, description, category, "
        "reference_type, treasury_id, is_transfer) VALUES "
        "(7, 'RCV-1', '2026-11-08T10:00:00.000', 500, 'receive', 'تحصيل فاتورة', 'مبيعات', 'sales_invoice', 1, 0)",
      );
      db.execute(
        "INSERT INTO treasury_transactions (id, transaction_number, "
        "transaction_date, amount, transaction_type, description, category, "
        "reference_type, treasury_id, is_transfer) VALUES "
        "(8, 'TRF-1', '2026-11-09T10:00:00.000', 999, 'expense', 'تحويل', 'تحويل داخلي', 'treasury', 1, 1)",
      );
      db.execute(
        "INSERT INTO treasury_transactions (id, transaction_number, "
        "transaction_date, amount, transaction_type, description, category, "
        "reference_type, treasury_id, is_transfer) VALUES "
        "(9, 'EXP-6', '2026-11-10T10:00:00.000', 70, 'expense', 'إيجار فرع', 'إيجار', 'manual', 2, 0)",
      );
    });

    ProfitLossReport build({
      int? treasuryId,
      bool manualOnly = true,
      bool includeOtherIncome = true,
    }) {
      return ProfitLossRepository(database: db).buildReport(
        ProfitLossFilters(
          from: DateTime(2026, 11, 1),
          to: DateTime(2026, 11, 30),
          treasuryId: treasuryId,
          manualOnly: manualOnly,
          includeOtherIncome: includeOtherIncome,
        ),
      );
    }

    test('uses historical costs, excludes tax and transfer movements', () {
      final report = build();
      expect(report.sales, 1500);
      expect(report.salesReturns, 200);
      expect(report.netSales, 1300);
      expect(report.cogs, 900);
      expect(report.returnCogs, 300);
      expect(report.netCogs, 600);
      expect(report.otherIncome, 40);
      expect(report.totalExpenses, 255);
      expect(report.grossProfit, 740);
      expect(report.netProfit, 485);
    });

    test('statement has the exact 16 rows and real expense categories', () {
      final report = build();
      final statement = report.statement;
      expect(statement.length, 16);
      expect(statement[0].label, 'الإيرادات');
      expect(statement[2].amount, -200);
      expect(statement[7].amount, 300);
      expect(statement[9].label, 'إجمالي الإيرادات / الربح الإجمالي');
      expect(statement[9].amount, 740);
      expect(statement[10].label, 'المصروفات');
      expect(statement[11].label, 'إيجار');
      expect(statement[11].amount, 170);
      expect(statement[12].label, 'كهرباء');
      expect(statement[12].amount, 50);
      expect(statement[13].amount, 35);
      expect(statement[14].amount, 255);
      expect(statement[15].label, 'صافي الربح');
      expect(statement[15].amount, 485);
    });

    test('treasury filter limits expenses and income to that treasury', () {
      final report = build(treasuryId: 1);
      expect(report.totalExpenses, 185);
      expect(report.otherIncome, 40);
      expect(report.netProfit, 555);
    });

    test('manual-only checkbox excludes invoice linked movements', () {
      final report = build(manualOnly: false);
      expect(report.totalExpenses, 655);
      expect(report.otherIncome, 540);
      expect(report.netProfit, 585);
    });

    test('other income can be hidden', () {
      final report = build(includeOtherIncome: false);
      expect(report.otherIncome, 0);
      expect(report.statement[4].amount, 0);
      expect(report.netProfit, 445);
    });

    test('detail rows reconcile with net profit', () {
      final report = build();
      final debit = report.details.fold<int>(0, (sum, row) => sum + row.debit);
      final credit = report.details.fold<int>(
        0,
        (sum, row) => sum + row.credit,
      );
      expect(credit - debit, report.netProfit);
      expect(report.details, isNotEmpty);
    });
  });
}
