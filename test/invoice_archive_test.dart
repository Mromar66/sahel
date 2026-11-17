import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/features/invoices/data/invoice_archive_repository.dart';
import 'package:inventory_app/features/invoices/domain/invoice_archive_models.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    if (!Platform.isWindows) return;
    for (final path in const [
      'build/windows/x64/plugins/sqlite3_flutter_libs/Release/sqlite3.dll',
      'build/windows/x64/plugins/sqlite3_flutter_libs/Debug/sqlite3.dll',
      'build/windows/x64/runner/Release/sqlite3.dll',
      'build/windows/x64/runner/Debug/sqlite3.dll',
    ]) {
      final file = File(path);
      if (file.existsSync()) {
        open.overrideFor(
          OperatingSystem.windows,
          () => DynamicLibrary.open(file.absolute.path),
        );
        break;
      }
    }
  });

  late Database db;
  late InvoiceArchiveRepository repo;

  setUp(() {
    db = sqlite3.openInMemory();
    db.execute(_schema);
    repo = InvoiceArchiveRepository(database: db);
    _seed(db);
  });

  tearDown(() {
    db.dispose();
  });

  group('document search', () {
    test('each tab reads its own real document family', () async {
      final sales = await repo.searchDocuments(
        type: ArchiveDocType.sale,
        filters: const ArchiveFilters(),
      );
      expect(
        sales.rows.map((row) => row.number),
        containsAll(['INV-1', 'INV-2', 'INV-3']),
      );
      expect(sales.rows.map((row) => row.number), isNot(contains('SR-1')));
      expect(sales.totalCount, 3);

      final returns = await repo.searchDocuments(
        type: ArchiveDocType.salesReturn,
        filters: const ArchiveFilters(),
      );
      expect(returns.rows.single.number, 'SR-1');
      expect(returns.rows.single.originalNumber, 'INV-1');

      final purchases = await repo.searchDocuments(
        type: ArchiveDocType.purchase,
        filters: const ArchiveFilters(),
      );
      expect(purchases.rows.single.number, 'PUR-1');

      final receipts = await repo.searchDocuments(
        type: ArchiveDocType.receipt,
        filters: const ArchiveFilters(),
      );
      expect(receipts.rows.map((row) => row.number), ['RCV-1']);
      expect(
        receipts.rows.map((row) => row.number),
        isNot(contains('RCV-LINK')),
      );

      final payments = await repo.searchDocuments(
        type: ArchiveDocType.payment,
        filters: const ArchiveFilters(),
      );
      expect(payments.rows.single.number, 'PAY-1');

      final stocktaking = await repo.searchDocuments(
        type: ArchiveDocType.stocktaking,
        filters: const ArchiveFilters(),
      );
      expect(stocktaking.rows.length, 2);
    });

    test('all filters are combined with AND at the SQL level', () async {
      final page = await repo.searchDocuments(
        type: ArchiveDocType.sale,
        filters: ArchiveFilters(
          fromDate: DateTime(2026, 11, 16),
          toDate: DateTime(2026, 11, 16),
          fromTime: '00:00',
          toTime: '23:59',
          accountId: 1,
          accountType: 'customer',
          paymentStatus: 'paid',
          paymentMethod: 'cash',
          invoiceNumber: 'INV-1',
          partyName: 'عميل',
          notes: 'نقدية',
        ),
      );
      expect(page.rows.single.number, 'INV-1');
      expect(page.totalCount, 1);
      expect(page.totals.total, 300);
      expect(page.totals.paid, 300);
      expect(page.totals.remaining, 0);
    });

    test(
      'payment method and status filters read the real stored values',
      () async {
        final cash = await repo.searchDocuments(
          type: ArchiveDocType.sale,
          filters: const ArchiveFilters(paymentMethod: 'cash'),
        );
        expect(
          cash.rows.map((row) => row.number),
          containsAll(['INV-1', 'INV-3']),
        );
        expect(cash.totalCount, 2);

        final credit = await repo.searchDocuments(
          type: ArchiveDocType.sale,
          filters: const ArchiveFilters(paymentMethod: 'credit'),
        );
        expect(credit.rows.single.number, 'INV-2');

        final unpaid = await repo.searchDocuments(
          type: ArchiveDocType.sale,
          filters: const ArchiveFilters(paymentStatus: 'unpaid'),
        );
        expect(unpaid.rows.single.number, 'INV-2');
      },
    );

    test('item search returns lines, not duplicate document rows', () async {
      final page = await repo.searchItems(
        type: ArchiveDocType.sale,
        filters: const ArchiveFilters(invoiceNumber: 'INV-1'),
      );
      expect(page.rows.length, 2);
      expect(page.rows.every((row) => row.documentNumber == 'INV-1'), isTrue);
      expect(
        page.rows.map((row) => row.itemName),
        containsAll(['قلم جاف', 'دفتر']),
      );
      expect(page.totalCount, 2);
      expect(page.totals.quantity, 3);
      expect(page.totals.total, 300);

      final filtered = await repo.searchItems(
        type: ArchiveDocType.sale,
        filters: const ArchiveFilters(itemName: 'قلم'),
      );
      expect(filtered.rows.single.documentNumber, 'INV-1');
      expect(filtered.rows.single.itemName, 'قلم جاف');
    });

    test('paging returns stable slices and an honest hasMore flag', () async {
      final first = await repo.searchDocuments(
        type: ArchiveDocType.sale,
        filters: const ArchiveFilters(),
        sort: const ArchiveSort(field: ArchiveSortField.total, ascending: true),
        limit: 2,
      );
      expect(first.rows.map((row) => row.total), [100, 200]);
      expect(first.totalCount, 3);
      expect(first.hasMore, isTrue);

      final second = await repo.searchDocuments(
        type: ArchiveDocType.sale,
        filters: const ArchiveFilters(),
        sort: const ArchiveSort(field: ArchiveSortField.total, ascending: true),
        limit: 2,
        offset: 2,
      );
      expect(second.rows.single.total, 300);
      expect(second.hasMore, isFalse);
    });

    test(
      'stock documents filter by their real warehouse and applied state',
      () async {
        final byWarehouse = await repo.searchDocuments(
          type: ArchiveDocType.stocktaking,
          filters: const ArchiveFilters(warehouseId: 1),
        );
        expect(byWarehouse.rows.single.number, 'ST-1');

        final draft = await repo.searchDocuments(
          type: ArchiveDocType.stocktaking,
          filters: const ArchiveFilters(documentStatus: 'draft'),
        );
        expect(draft.rows.single.number, 'ST-2');

        final items = await repo.searchItems(
          type: ArchiveDocType.stocktaking,
          filters: const ArchiveFilters(warehouseId: 1),
        );
        expect(items.rows.length, 2);
        expect(items.totals.quantity, 5);
        expect(items.rows.first.warehouseName, 'المخزن الرئيسي');
      },
    );
  });

  group('filter validation', () {
    test('rejects a warehouse filter on an invoice with an Arabic reason', () {
      expect(
        repo.validateFilters(
          ArchiveDocType.sale,
          const ArchiveFilters(warehouseId: 1),
        ),
        'فلتر المخزن غير متاح لهذا النوع: المستند لا يسجل مخزناً.',
      );
    });

    test('rejects unsupported user and sales-rep filters honestly', () {
      expect(
        repo.validateFilters(
          ArchiveDocType.sale,
          const ArchiveFilters(userId: 1),
        ),
        'فلتر المستخدم غير متاح: المستندات الحالية لا تسجل منشئها.',
      );
      expect(
        repo.validateFilters(
          ArchiveDocType.sale,
          const ArchiveFilters(salesRepId: 1),
        ),
        'فلتر مندوب البيع غير متاح: المستندات الحالية لا تسجل مندوباً.',
      );
    });

    test('rejects inverted date and amount ranges', () {
      expect(
        repo.validateFilters(
          ArchiveDocType.sale,
          ArchiveFilters(
            fromDate: DateTime(2026, 11, 17),
            toDate: DateTime(2026, 11, 16),
          ),
        ),
        'تاريخ البداية يجب أن يكون قبل تاريخ النهاية.',
      );
      expect(
        repo.validateFilters(
          ArchiveDocType.sale,
          const ArchiveFilters(minAmount: 500, maxAmount: 100),
        ),
        'أقل مبلغ يجب أن يكون أقل من أكبر مبلغ.',
      );
    });

    test('rejects account and treasury filters where no relation exists', () {
      expect(
        repo.validateFilters(
          ArchiveDocType.stocktaking,
          const ArchiveFilters(accountId: 1),
        ),
        'فلتر الحساب غير متاح لهذا النوع: المستند لا يسجل حساباً.',
      );
      expect(
        repo.validateFilters(
          ArchiveDocType.receipt,
          const ArchiveFilters(treasuryId: 1),
        ),
        'فلتر الخزينة غير متاح لهذا النوع: المستند لا يسجل حركة خزينة.',
      );
    });

    test('accepts item filters only on documents with item lines', () {
      expect(
        repo.validateFilters(
          ArchiveDocType.sale,
          const ArchiveFilters(itemName: 'قلم'),
        ),
        isNull,
      );
      expect(
        repo.validateFilters(
          ArchiveDocType.receipt,
          const ArchiveFilters(itemName: 'قلم'),
        ),
        'البحث بالأصناف غير متاح لهذا النوع: المستند لا يحتوي سطور أصناف.',
      );
    });

    test(
      'exposes only the filters that each document type really supports',
      () {
        expect(ArchiveDocType.sale.hasPaymentStatus, isTrue);
        expect(ArchiveDocType.sale.hasPaymentMethod, isTrue);
        expect(ArchiveDocType.sale.hasDocumentStatus, isFalse);
        expect(ArchiveDocType.quotation.hasPaymentStatus, isFalse);
        expect(ArchiveDocType.quotation.hasPaymentMethod, isFalse);
        expect(ArchiveDocType.quotation.hasDocumentStatus, isTrue);
        expect(ArchiveDocType.receipt.hasPaymentMethod, isTrue);
        expect(ArchiveDocType.receipt.hasPaymentStatus, isFalse);
        expect(ArchiveDocType.transfer.hasWarehouse, isTrue);
        expect(ArchiveDocType.transfer.hasDocumentStatus, isTrue);
        expect(ArchiveDocType.transfer.hasAccount, isFalse);
      },
    );
  });

  group('deletion business rules', () {
    test(
      'deleting a sale reverses stock, payments, treasury and custom values',
      () async {
        final id = _seedDeletionSale(db);
        expect(_count(db, 'sales_invoices'), 5);

        await repo.deleteDocument(ArchiveDocType.sale, id);

        expect(_count(db, 'sales_invoices'), 4);
        expect(_count(db, 'sales_items'), 4);
        expect(_count(db, 'payments'), 3);
        expect(_count(db, 'treasury_transactions'), 2);
        expect(_count(db, 'document_custom_values'), 0);
        expect(
          db
              .select('SELECT current_stock FROM products WHERE id=1')
              .single['current_stock'],
          13,
        );
        expect(
          db.select(
            "SELECT COUNT(*) AS c FROM stock_movements "
            "WHERE reference_type='sales_invoice' AND reference_id=?",
            [id],
          ).single['c'],
          0,
        );
      },
    );

    test('a sale with a recorded return cannot be deleted', () async {
      await expectLater(
        repo.deleteDocument(ArchiveDocType.sale, 1),
        throwsA(
          isA<ArchiveException>().having(
            (error) => error.message,
            'message',
            contains('مرتجع بيع'),
          ),
        ),
      );
      expect(_count(db, 'sales_invoices'), 4);
      expect(_count(db, 'payments'), 3);
      expect(
        db
            .select('SELECT current_stock FROM products WHERE id=1')
            .single['current_stock'],
        10,
      );
    });

    test(
      'linked vouchers stay out of the archive and cannot be deleted',
      () async {
        await expectLater(
          repo.deleteDocument(ArchiveDocType.receipt, 11),
          throwsA(
            isA<ArchiveException>().having(
              (error) => error.message,
              'message',
              contains('مرتبطة بفاتورة'),
            ),
          ),
        );
        expect(_count(db, 'payments'), 3);

        await repo.deleteDocument(ArchiveDocType.receipt, 10);
        expect(_count(db, 'payments'), 2);
        expect(
          db
              .select('SELECT balance FROM accounts WHERE id=1')
              .single['balance'],
          0,
        );
        expect(_count(db, 'treasury_transactions'), 1);
        expect(
          db
              .select(
                'SELECT balance_after FROM treasury_transactions WHERE id=1',
              )
              .single['balance_after'],
          300,
        );
      },
    );

    test('deleting an applied stocktaking reverses its movements', () async {
      await repo.deleteDocument(ArchiveDocType.stocktaking, 1);

      expect(_count(db, 'stocktaking_sessions'), 1);
      expect(_count(db, 'stocktaking_items'), 1);
      expect(
        db
            .select('SELECT current_stock FROM products WHERE id=1')
            .single['current_stock'],
        8,
      );
      expect(
        db
            .select(
              "SELECT COUNT(*) AS c FROM stock_movements "
              "WHERE reference_type='stocktaking_session' AND reference_id=1",
            )
            .single['c'],
        0,
      );
    });

    test(
      'an applied stocktaking with insufficient stock stays untouched',
      () async {
        final sessionId = _insert(db, 'stocktaking_sessions', {
          'session_number': 'ST-BLOCKED',
          'warehouse_id': 1,
          'session_date': '2026-11-16T08:00:00.000',
          'total': 2000,
          'items_count': 1,
          'applied': 1,
          'notes': null,
          'created_at': '2026-11-16T08:00:00.000',
        });
        _insert(db, 'stock_movements', {
          'product_id': 2,
          'quantity': 20,
          'movement_type': 'stocktaking',
          'reference_id': sessionId,
          'reference_type': 'stocktaking_session',
          'movement_date': '2026-11-16T08:00:00.000',
          'notes': null,
        });

        await expectLater(
          repo.deleteDocument(ArchiveDocType.stocktaking, sessionId),
          throwsA(
            isA<ArchiveException>().having(
              (error) => error.message,
              'message',
              contains('المخزون الحالي غير كافٍ'),
            ),
          ),
        );
        expect(
          db.select('SELECT id FROM stocktaking_sessions WHERE id=?', [
            sessionId,
          ]),
          isNotEmpty,
        );
        expect(_count(db, 'stock_movements'), 2);
      },
    );

    test(
      'an applied transfer cannot be deleted after destination stock was used',
      () async {
        final sessionId = _insert(db, 'stock_transfer_sessions', {
          'session_number': 'TR-USED',
          'from_warehouse_id': 1,
          'to_warehouse_id': 2,
          'session_date': '2026-11-16T08:00:00.000',
          'total': 300,
          'items_count': 1,
          'applied': 1,
          'notes': null,
          'created_at': '2026-11-16T08:00:00.000',
        });
        _insert(db, 'stock_transfer_items', {
          'session_id': sessionId,
          'product_id': 2,
          'product_name': 'دفتر',
          'product_code': 'P2',
          'unit_name': 'حبة',
          'available_qty': 5,
          'transfer_qty': 3,
          'price': 100,
          'total': 300,
        });
        _insert(db, 'stock_movements', {
          'product_id': 2,
          'quantity': 3,
          'movement_type': 'transfer_out',
          'reference_id': sessionId,
          'reference_type': 'stock_transfer',
          'from_warehouse_id': 1,
          'to_warehouse_id': null,
          'movement_date': '2026-11-16T08:00:00.000',
          'notes': null,
        });
        _insert(db, 'stock_movements', {
          'product_id': 2,
          'quantity': 3,
          'movement_type': 'transfer_in',
          'reference_id': sessionId,
          'reference_type': 'stock_transfer',
          'from_warehouse_id': null,
          'to_warehouse_id': 2,
          'movement_date': '2026-11-16T08:00:00.000',
          'notes': null,
        });
        _insert(db, 'stock_movements', {
          'product_id': 2,
          'quantity': 2,
          'movement_type': 'sale',
          'reference_id': 90,
          'reference_type': 'sale',
          'from_warehouse_id': 2,
          'to_warehouse_id': null,
          'movement_date': '2026-11-16T09:00:00.000',
          'notes': null,
        });
        db.execute('UPDATE products SET current_stock=3 WHERE id=2');

        await expectLater(
          repo.deleteDocument(ArchiveDocType.transfer, sessionId),
          throwsA(
            isA<ArchiveException>().having(
              (error) => error.message,
              'message',
              contains('مخزن الوجهة'),
            ),
          ),
        );
        expect(
          db.select('SELECT id FROM stock_transfer_sessions WHERE id=?', [
            sessionId,
          ]),
          isNotEmpty,
        );
        expect(
          db.select(
            "SELECT COUNT(*) AS c FROM stock_movements "
            "WHERE reference_type='stock_transfer' AND reference_id=?",
            [sessionId],
          ).single['c'],
          2,
        );
      },
    );

    test(
      'quotations are deleted unless they were converted to a sale',
      () async {
        await repo.deleteDocument(ArchiveDocType.quotation, 1);
        expect(_count(db, 'quotations'), 1);
        expect(_count(db, 'quotation_items'), 0);

        await expectLater(
          repo.deleteDocument(ArchiveDocType.quotation, 2),
          throwsA(
            isA<ArchiveException>().having(
              (error) => error.message,
              'message',
              contains('محوّل إلى فاتورة بيع'),
            ),
          ),
        );
        expect(db.select('SELECT id FROM quotations WHERE id=2'), isNotEmpty);
      },
    );
  });
}

int _seedDeletionSale(Database db) {
  final id = _insert(db, 'sales_invoices', {
    'invoice_number': 'INV-DEL',
    'account_id': 1,
    'invoice_date': '2026-11-16T14:00:00.000',
    'subtotal': 150,
    'discount': 0,
    'tax': 0,
    'total': 150,
    'paid_amount': 50,
    'remaining_amount': 100,
    'payment_status': 'partial',
    'notes': 'اختبار الحذف',
    'is_return': 0,
    'original_invoice_id': null,
    'created_at': '2026-11-16T14:00:00.000',
  });
  _insert(db, 'sales_items', {
    'invoice_id': id,
    'product_id': 1,
    'product_name': 'قلم جاف',
    'product_code': 'P1',
    'quantity': 3,
    'unit_price': 50,
    'discount': 0,
    'total': 150,
  });
  _insert(db, 'stock_movements', {
    'product_id': 1,
    'quantity': -3,
    'movement_type': 'sale',
    'reference_id': id,
    'reference_type': 'sales_invoice',
    'movement_date': '2026-11-16T14:00:00.000',
    'notes': 'بيع',
  });
  _insert(db, 'payments', {
    'payment_number': 'RCV-DEL',
    'account_id': 1,
    'payment_date': '2026-11-16T14:00:00.000',
    'amount': 50,
    'payment_type': 'receipt',
    'payment_method': 'cash',
    'description': 'دفعة اختبار',
    'reference_id': id,
    'reference_type': 'sales_invoice',
    'created_at': '2026-11-16T14:00:00.000',
  });
  _insert(db, 'treasury_transactions', {
    'transaction_number': 'TRX-DEL',
    'transaction_date': '2026-11-16T14:00:00.000',
    'amount': 50,
    'transaction_type': 'receive',
    'description': 'دفعة اختبار',
    'reference_id': id,
    'reference_type': 'sales_invoice',
    'balance_after': 50,
    'created_at': '2026-11-16T14:00:00.000',
    'treasury_id': 1,
  });
  _insert(db, 'document_custom_values', {
    'document_type': 'sale',
    'document_id': id,
    'field_id': 1,
    'value': 'قيمة مخصصة',
    'updated_at': '2026-11-16T14:00:00.000',
  });
  db.execute('UPDATE accounts SET balance=-50 WHERE id=1');
  return id;
}

int _count(Database db, String table) =>
    (db.select('SELECT COUNT(*) AS c FROM $table').single['c'] as num).toInt();

int _insert(Database db, String table, Map<String, Object?> values) {
  final columns = values.keys.join(',');
  final marks = List.filled(values.length, '?').join(',');
  db.execute(
    'INSERT INTO $table ($columns) VALUES ($marks)',
    values.values.toList(),
  );
  return (db.select('SELECT last_insert_rowid() AS id').single['id'] as num)
      .toInt();
}

void _seed(Database db) {
  const now = '2026-11-16T10:00:00.000';
  _insert(db, 'categories', {'id': 1, 'name': 'قرطاسية'});
  _insert(db, 'units', {
    'id': 1,
    'name': 'حبة',
    'abbreviation': 'ح',
    'created_at': now,
  });
  _insert(db, 'products', {
    'id': 1,
    'name': 'قلم جاف',
    'product_code': 'P1',
    'barcode': '111',
    'category_id': 1,
    'unit_id': 1,
    'purchase_price': 60,
    'selling_price': 100,
    'current_stock': 10,
    'is_active': 1,
    'created_at': now,
  });
  _insert(db, 'products', {
    'id': 2,
    'name': 'دفتر',
    'product_code': 'P2',
    'barcode': '222',
    'category_id': 1,
    'unit_id': 1,
    'purchase_price': 80,
    'selling_price': 100,
    'current_stock': 5,
    'is_active': 1,
    'created_at': now,
  });
  _insert(db, 'accounts', {
    'id': 1,
    'name': 'عميل نقدي',
    'account_type': 'customer',
    'balance': -100,
    'is_active': 1,
    'created_at': now,
  });
  _insert(db, 'accounts', {
    'id': 2,
    'name': 'مورد رئيسي',
    'account_type': 'supplier',
    'balance': 0,
    'is_active': 1,
    'created_at': now,
  });
  _insert(db, 'warehouses', {
    'id': 1,
    'name': 'المخزن الرئيسي',
    'is_active': 1,
    'sort_order': 0,
    'created_at': now,
  });
  _insert(db, 'warehouses', {
    'id': 2,
    'name': 'مخزن الفرع',
    'is_active': 1,
    'sort_order': 1,
    'created_at': now,
  });
  _insert(db, 'treasuries', {
    'id': 1,
    'name': 'درج النقدية',
    'opening_balance': 0,
    'is_active': 1,
    'created_at': now,
  });

  _insert(db, 'sales_invoices', {
    'id': 1,
    'invoice_number': 'INV-1',
    'account_id': 1,
    'invoice_date': '2026-11-16T10:30:00.000',
    'subtotal': 300,
    'discount': 0,
    'tax': 0,
    'total': 300,
    'paid_amount': 300,
    'remaining_amount': 0,
    'payment_status': 'paid',
    'notes': 'فاتورة نقدية',
    'is_return': 0,
    'original_invoice_id': null,
    'created_at': '2026-11-16T10:30:00.000',
  });
  _insert(db, 'sales_items', {
    'invoice_id': 1,
    'product_id': 1,
    'product_name': 'قلم جاف',
    'product_code': 'P1',
    'quantity': 2,
    'unit_price': 100,
    'discount': 0,
    'total': 200,
  });
  _insert(db, 'sales_items', {
    'invoice_id': 1,
    'product_id': 2,
    'product_name': 'دفتر',
    'product_code': 'P2',
    'quantity': 1,
    'unit_price': 100,
    'discount': 0,
    'total': 100,
  });
  _insert(db, 'sales_invoices', {
    'id': 2,
    'invoice_number': 'INV-2',
    'account_id': 1,
    'invoice_date': '2026-11-15T09:00:00.000',
    'subtotal': 200,
    'discount': 0,
    'tax': 0,
    'total': 200,
    'paid_amount': 0,
    'remaining_amount': 200,
    'payment_status': 'unpaid',
    'notes': 'آجل',
    'is_return': 0,
    'original_invoice_id': null,
    'created_at': '2026-11-15T09:00:00.000',
  });
  _insert(db, 'sales_items', {
    'invoice_id': 2,
    'product_id': 2,
    'product_name': 'دفتر',
    'product_code': 'P2',
    'quantity': 2,
    'unit_price': 100,
    'discount': 0,
    'total': 200,
  });
  _insert(db, 'sales_invoices', {
    'id': 3,
    'invoice_number': 'INV-3',
    'account_id': 2,
    'invoice_date': '2026-11-14T12:00:00.000',
    'subtotal': 100,
    'discount': 0,
    'tax': 0,
    'total': 100,
    'paid_amount': 100,
    'remaining_amount': 0,
    'payment_status': 'paid',
    'notes': null,
    'is_return': 0,
    'original_invoice_id': null,
    'created_at': '2026-11-14T12:00:00.000',
  });
  _insert(db, 'sales_invoices', {
    'id': 4,
    'invoice_number': 'SR-1',
    'account_id': 1,
    'invoice_date': '2026-11-16T11:00:00.000',
    'subtotal': 100,
    'discount': 0,
    'tax': 0,
    'total': 100,
    'paid_amount': 0,
    'remaining_amount': 100,
    'payment_status': 'unpaid',
    'notes': 'مرتجع',
    'is_return': 1,
    'original_invoice_id': 1,
    'created_at': '2026-11-16T11:00:00.000',
  });
  _insert(db, 'sales_items', {
    'invoice_id': 4,
    'product_id': 1,
    'product_name': 'قلم جاف',
    'product_code': 'P1',
    'quantity': 1,
    'unit_price': 100,
    'discount': 0,
    'total': 100,
  });

  _insert(db, 'purchase_invoices', {
    'id': 1,
    'invoice_number': 'PUR-1',
    'account_id': 2,
    'invoice_date': '2026-11-16T08:00:00.000',
    'subtotal': 500,
    'discount': 0,
    'tax': 0,
    'total': 500,
    'paid_amount': 0,
    'remaining_amount': 500,
    'payment_status': 'unpaid',
    'notes': null,
    'is_return': 0,
    'original_invoice_id': null,
    'created_at': '2026-11-16T08:00:00.000',
  });
  _insert(db, 'purchase_items', {
    'invoice_id': 1,
    'product_id': 1,
    'product_name': 'قلم جاف',
    'product_code': 'P1',
    'quantity': 5,
    'unit_price': 100,
    'discount': 0,
    'total': 500,
  });

  _insert(db, 'quotations', {
    'id': 1,
    'quote_number': 'QT-1',
    'account_id': 1,
    'quote_date': '2026-11-16T09:00:00.000',
    'subtotal': 300,
    'discount': 0,
    'tax': 0,
    'total': 300,
    'status': 'open',
    'converted_invoice_id': null,
    'notes': null,
    'created_at': '2026-11-16T09:00:00.000',
    'updated_at': null,
  });
  _insert(db, 'quotation_items', {
    'quote_id': 1,
    'product_id': 1,
    'product_name': 'قلم جاف',
    'product_code': 'P1',
    'quantity': 1,
    'unit_price': 300,
    'discount': 0,
    'total': 300,
  });
  _insert(db, 'quotations', {
    'id': 2,
    'quote_number': 'QT-2',
    'account_id': 1,
    'quote_date': '2026-11-16T09:30:00.000',
    'subtotal': 100,
    'discount': 0,
    'tax': 0,
    'total': 100,
    'status': 'converted',
    'converted_invoice_id': 1,
    'notes': null,
    'created_at': '2026-11-16T09:30:00.000',
    'updated_at': null,
  });

  _insert(db, 'payments', {
    'id': 10,
    'payment_number': 'RCV-1',
    'account_id': 1,
    'payment_date': '2026-11-16T12:00:00.000',
    'amount': 100,
    'payment_type': 'receipt',
    'payment_method': 'cash',
    'description': 'سند قبض مستقل',
    'reference_id': null,
    'reference_type': null,
    'created_at': '2026-11-16T12:00:00.000',
  });
  _insert(db, 'payments', {
    'id': 11,
    'payment_number': 'RCV-LINK',
    'account_id': 1,
    'payment_date': '2026-11-16T10:30:00.000',
    'amount': 300,
    'payment_type': 'receipt',
    'payment_method': 'cash',
    'description': 'دفعة فاتورة',
    'reference_id': 1,
    'reference_type': 'sales_invoice',
    'created_at': '2026-11-16T10:30:00.000',
  });
  _insert(db, 'payments', {
    'id': 12,
    'payment_number': 'PAY-1',
    'account_id': 2,
    'payment_date': '2026-11-16T13:00:00.000',
    'amount': 50,
    'payment_type': 'payment',
    'payment_method': 'bank',
    'description': 'سند صرف مستقل',
    'reference_id': null,
    'reference_type': null,
    'created_at': '2026-11-16T13:00:00.000',
  });

  _insert(db, 'treasury_transactions', {
    'id': 1,
    'transaction_number': 'TRX-1',
    'transaction_date': '2026-11-16T10:30:00.000',
    'amount': 300,
    'transaction_type': 'receive',
    'description': 'تحصيل فاتورة',
    'reference_id': 1,
    'reference_type': 'sales_invoice',
    'balance_after': 300,
    'created_at': '2026-11-16T10:30:00.000',
    'treasury_id': 1,
  });
  _insert(db, 'treasury_transactions', {
    'id': 2,
    'transaction_number': 'TRX-VOUCHER',
    'transaction_date': '2026-11-16T12:00:00.000',
    'amount': 100,
    'transaction_type': 'receive',
    'description': 'سند قبض مستقل',
    'reference_id': 10,
    'reference_type': 'receipt_voucher',
    'balance_after': 400,
    'created_at': '2026-11-16T12:00:00.000',
    'treasury_id': 1,
  });

  _insert(db, 'stocktaking_sessions', {
    'id': 1,
    'session_number': 'ST-1',
    'warehouse_id': 1,
    'session_date': '2026-11-16T09:00:00.000',
    'total': 500,
    'items_count': 2,
    'applied': 1,
    'notes': null,
    'created_at': '2026-11-16T09:00:00.000',
  });
  _insert(db, 'stocktaking_items', {
    'session_id': 1,
    'product_id': 1,
    'product_name': 'قلم جاف',
    'product_code': 'P1',
    'unit_name': 'حبة',
    'available_qty': 2,
    'counted_qty': 4,
    'price': 100,
    'total': 400,
  });
  _insert(db, 'stocktaking_items', {
    'session_id': 1,
    'product_id': 2,
    'product_name': 'دفتر',
    'product_code': 'P2',
    'unit_name': 'حبة',
    'available_qty': 1,
    'counted_qty': 1,
    'price': 100,
    'total': 100,
  });
  _insert(db, 'stocktaking_sessions', {
    'id': 2,
    'session_number': 'ST-2',
    'warehouse_id': 2,
    'session_date': '2026-11-15T09:00:00.000',
    'total': 100,
    'items_count': 1,
    'applied': 0,
    'notes': null,
    'created_at': '2026-11-15T09:00:00.000',
  });
  _insert(db, 'stocktaking_items', {
    'session_id': 2,
    'product_id': 2,
    'product_name': 'دفتر',
    'product_code': 'P2',
    'unit_name': 'حبة',
    'available_qty': 1,
    'counted_qty': 1,
    'price': 100,
    'total': 100,
  });
  _insert(db, 'stock_movements', {
    'product_id': 1,
    'quantity': 2,
    'movement_type': 'stocktaking',
    'reference_id': 1,
    'reference_type': 'stocktaking_session',
    'movement_date': '2026-11-16T09:00:00.000',
    'notes': 'جرد',
  });
}

const String _schema = '''
CREATE TABLE categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL
);
CREATE TABLE units (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  abbreviation TEXT,
  created_at TEXT NOT NULL
);
CREATE TABLE products (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  product_code TEXT NOT NULL,
  barcode TEXT,
  category_id INTEGER,
  unit_id INTEGER,
  purchase_price INTEGER NOT NULL DEFAULT 0,
  selling_price INTEGER NOT NULL DEFAULT 0,
  current_stock INTEGER DEFAULT 0,
  is_active INTEGER DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT
);
CREATE TABLE accounts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  account_type TEXT NOT NULL,
  balance INTEGER DEFAULT 0,
  is_active INTEGER DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT
);
CREATE TABLE sales_invoices (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  invoice_number TEXT NOT NULL,
  account_id INTEGER,
  invoice_date TEXT NOT NULL,
  subtotal INTEGER NOT NULL,
  discount INTEGER DEFAULT 0,
  tax INTEGER DEFAULT 0,
  total INTEGER NOT NULL,
  paid_amount INTEGER DEFAULT 0,
  remaining_amount INTEGER NOT NULL,
  payment_status TEXT NOT NULL,
  notes TEXT,
  is_return INTEGER DEFAULT 0,
  original_invoice_id INTEGER,
  created_at TEXT NOT NULL,
  updated_at TEXT
);
CREATE TABLE sales_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  invoice_id INTEGER NOT NULL,
  product_id INTEGER,
  product_name TEXT NOT NULL,
  product_code TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unit_price INTEGER NOT NULL,
  discount INTEGER DEFAULT 0,
  total INTEGER NOT NULL
);
CREATE TABLE purchase_invoices (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  invoice_number TEXT NOT NULL,
  supplier_id INTEGER,
  account_id INTEGER,
  invoice_date TEXT NOT NULL,
  subtotal INTEGER NOT NULL,
  discount INTEGER DEFAULT 0,
  tax INTEGER DEFAULT 0,
  total INTEGER NOT NULL,
  paid_amount INTEGER DEFAULT 0,
  remaining_amount INTEGER NOT NULL,
  payment_status TEXT NOT NULL,
  notes TEXT,
  is_return INTEGER DEFAULT 0,
  original_invoice_id INTEGER,
  created_at TEXT NOT NULL,
  updated_at TEXT
);
CREATE TABLE purchase_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  invoice_id INTEGER NOT NULL,
  product_id INTEGER,
  product_name TEXT NOT NULL,
  product_code TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unit_price INTEGER NOT NULL,
  discount INTEGER DEFAULT 0,
  total INTEGER NOT NULL
);
CREATE TABLE purchase_return_invoices (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  return_number TEXT NOT NULL,
  account_id INTEGER,
  original_invoice_id INTEGER,
  return_date TEXT NOT NULL,
  subtotal INTEGER NOT NULL,
  discount INTEGER DEFAULT 0,
  tax INTEGER DEFAULT 0,
  total INTEGER NOT NULL,
  refunded_amount INTEGER DEFAULT 0,
  remaining_amount INTEGER NOT NULL,
  payment_status TEXT NOT NULL,
  notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT
);
CREATE TABLE purchase_return_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  return_id INTEGER NOT NULL,
  product_id INTEGER,
  product_name TEXT NOT NULL,
  product_code TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unit_price INTEGER NOT NULL,
  discount INTEGER DEFAULT 0,
  total INTEGER NOT NULL
);
CREATE TABLE quotations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  quote_number TEXT NOT NULL,
  account_id INTEGER,
  quote_date TEXT NOT NULL,
  subtotal INTEGER NOT NULL,
  discount INTEGER DEFAULT 0,
  tax INTEGER DEFAULT 0,
  total INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'open',
  converted_invoice_id INTEGER,
  notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT
);
CREATE TABLE quotation_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  quote_id INTEGER NOT NULL,
  product_id INTEGER,
  product_name TEXT NOT NULL,
  product_code TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unit_price INTEGER NOT NULL,
  discount INTEGER DEFAULT 0,
  total INTEGER NOT NULL
);
CREATE TABLE payments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  payment_number TEXT NOT NULL,
  account_id INTEGER NOT NULL,
  payment_date TEXT NOT NULL,
  amount INTEGER NOT NULL,
  payment_type TEXT NOT NULL,
  payment_method TEXT NOT NULL,
  description TEXT,
  reference_id INTEGER,
  reference_type TEXT,
  created_at TEXT NOT NULL
);
CREATE TABLE account_checks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id INTEGER NOT NULL,
  payment_id INTEGER,
  treasury_id INTEGER,
  direction TEXT,
  amount INTEGER,
  due_date TEXT,
  collected_date TEXT,
  bank TEXT,
  check_number TEXT,
  status TEXT,
  notes TEXT,
  created_at TEXT
);
CREATE TABLE expenses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  payment_id INTEGER
);
CREATE TABLE treasuries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  opening_balance INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL
);
CREATE TABLE treasury_transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  transaction_number TEXT NOT NULL,
  transaction_date TEXT NOT NULL,
  amount INTEGER NOT NULL,
  transaction_type TEXT NOT NULL,
  description TEXT,
  reference_id INTEGER,
  reference_type TEXT,
  balance_after INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  treasury_id INTEGER
);
CREATE TABLE stock_movements (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  product_id INTEGER NOT NULL,
  quantity INTEGER NOT NULL,
  movement_type TEXT NOT NULL,
  reference_id INTEGER,
  reference_type TEXT,
  from_warehouse_id INTEGER,
  to_warehouse_id INTEGER,
  movement_date TEXT NOT NULL,
  notes TEXT
);
CREATE TABLE warehouses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  location TEXT,
  description TEXT,
  is_active INTEGER DEFAULT 1,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);
CREATE TABLE stocktaking_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_number TEXT NOT NULL,
  warehouse_id INTEGER,
  session_date TEXT NOT NULL,
  total INTEGER NOT NULL DEFAULT 0,
  items_count INTEGER NOT NULL DEFAULT 0,
  applied INTEGER DEFAULT 0,
  notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT
);
CREATE TABLE stocktaking_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id INTEGER NOT NULL,
  product_id INTEGER,
  product_name TEXT NOT NULL,
  product_code TEXT NOT NULL,
  unit_name TEXT,
  available_qty INTEGER NOT NULL DEFAULT 0,
  counted_qty INTEGER NOT NULL DEFAULT 0,
  price INTEGER NOT NULL DEFAULT 0,
  total INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE stock_adjustment_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_number TEXT NOT NULL,
  warehouse_id INTEGER,
  session_date TEXT NOT NULL,
  total INTEGER NOT NULL DEFAULT 0,
  items_count INTEGER NOT NULL DEFAULT 0,
  applied INTEGER DEFAULT 0,
  notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT
);
CREATE TABLE stock_adjustment_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id INTEGER NOT NULL,
  product_id INTEGER,
  product_name TEXT NOT NULL,
  product_code TEXT NOT NULL,
  unit_name TEXT,
  available_qty INTEGER NOT NULL DEFAULT 0,
  adjusted_qty INTEGER NOT NULL DEFAULT 0,
  difference INTEGER NOT NULL DEFAULT 0,
  price INTEGER NOT NULL DEFAULT 0,
  total INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE stock_transfer_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_number TEXT NOT NULL,
  from_warehouse_id INTEGER,
  to_warehouse_id INTEGER,
  session_date TEXT NOT NULL,
  total INTEGER NOT NULL DEFAULT 0,
  items_count INTEGER NOT NULL DEFAULT 0,
  applied INTEGER DEFAULT 0,
  notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT
);
CREATE TABLE stock_transfer_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id INTEGER NOT NULL,
  product_id INTEGER,
  product_name TEXT NOT NULL,
  product_code TEXT NOT NULL,
  unit_name TEXT,
  available_qty INTEGER NOT NULL DEFAULT 0,
  transfer_qty INTEGER NOT NULL DEFAULT 0,
  price INTEGER NOT NULL DEFAULT 0,
  total INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE document_custom_values (
  document_type TEXT NOT NULL,
  document_id INTEGER NOT NULL,
  field_id INTEGER NOT NULL,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (document_type, document_id, field_id)
);
''';
