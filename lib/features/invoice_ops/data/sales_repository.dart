import 'package:safwa/core/services/document_custom_fields.dart';
import 'package:safwa/core/services/warehouse_stock.dart';
import 'package:safwa/features/invoice_ops/data/invoice_op_repository.dart';
import 'package:safwa/features/invoice_ops/domain/invoice_op_models.dart';

/// بيع جديد — sales invoices, selling prices, stock out and customer receipts.
class SalesRepository extends InvoiceRepositoryBase {
  SalesRepository() : super(InvoiceOpKind.sale);

  @override
  int? customerLastSoldPrice(int accountId, int productId) {
    final option = db.query('SELECT value FROM settings WHERE key=?', [
      'settings.customer_last_price',
    ]);
    if (option.isEmpty || option.first['value'] != '1') return null;
    final rows = db.query(
      '''
      SELECT si.unit_price
      FROM sales_items si
      JOIN sales_invoices invoice ON invoice.id=si.invoice_id
      WHERE invoice.account_id=? AND invoice.is_return=0 AND si.product_id=?
      ORDER BY invoice.invoice_date DESC,invoice.id DESC,si.id DESC
      LIMIT 1
      ''',
      [accountId, productId],
    );
    return rows.isEmpty ? null : rows.first['unit_price'] as int?;
  }

  @override
  String nextInvoiceNumber() {
    final rows = db.query(
      'SELECT invoice_number FROM sales_invoices WHERE is_return = 0 '
      'ORDER BY id DESC LIMIT 1',
    );
    if (rows.isEmpty) return '1';
    final raw = '${rows.first['invoice_number'] ?? ''}';
    final match = RegExp(r'\d+').firstMatch(raw);
    final next = match == null ? 1 : (int.tryParse(match.group(0)!) ?? 0) + 1;
    return '$next';
  }

  @override
  Future<InvoiceSaveResult> saveInvoice({
    required int? accountId,
    required String invoiceNumber,
    required List<InvoiceLine> lines,
    required int discount,
    required int addition,
    required String notes,
    required String paymentMethod,
    InvoicePaymentInput? payment,
    DateTime? invoiceDate,
    int? warehouseId,
    int? salesRepresentativeId,
    int? originalInvoiceId,
    int? quotationId,
    Map<int, String> customFields = const {},
  }) async {
    final totals = validateInvoiceTotals(
      lines: lines,
      discount: discount,
      addition: addition,
    );
    final paymentInfo = validatePayment(
      total: totals.total,
      payment: payment,
      accountId: accountId,
    );
    _requireSalesRepresentative(salesRepresentativeId);
    final selectedWarehouseId =
        warehouseId ?? WarehouseStock.defaultWarehouseId(db);

    return db.transaction<InvoiceSaveResult>(() async {
      final now = DateTime.now().toIso8601String();
      final documentDate = (invoiceDate ?? DateTime.now()).toIso8601String();

      if (quotationId != null) {
        final quoteRows = db.query(
          'SELECT quote_number, converted_invoice_id FROM quotations WHERE id = ?',
          [quotationId],
        );
        if (quoteRows.isEmpty) {
          throw InvoiceValidationException('عرض السعر غير موجود.');
        }
        if (quoteRows.first['converted_invoice_id'] != null) {
          throw InvoiceValidationException(
            'تم تحويل عرض السعر هذا إلى فاتورة بيع بالفعل.',
          );
        }
      }

      final requested = aggregateInvoiceQuantities(lines);
      for (final entry in requested.entries) {
        final line = lines.firstWhere((line) => line.productId == entry.key);
        final stock = selectedWarehouseId == null
            ? currentStock(entry.key)
            : WarehouseStock.quantityInWarehouse(
                db,
                entry.key,
                selectedWarehouseId,
              );
        if (stock < entry.value) {
          throw InvoiceValidationException(
            'الكمية غير متاحة للصنف «${line.name}» — المتاح $stock فقط.',
          );
        }
      }

      final invoiceId = db.insert(
        '''
        INSERT INTO sales_invoices
          (invoice_number, customer_id, account_id, invoice_date, subtotal,
           discount, tax, total, paid_amount, remaining_amount,
           payment_status, notes, is_return, original_invoice_id,
           created_at, updated_at, warehouse_id, sales_rep_account_id)
        VALUES (?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, NULL, ?, ?, ?, ?)
        ''',
        [
          invoiceNumber,
          accountId,
          documentDate,
          totals.subtotal,
          totals.discount,
          totals.addition,
          totals.total,
          paymentInfo.paid,
          paymentInfo.remaining,
          paymentInfo.status,
          notes.isEmpty ? null : notes,
          now,
          now,
          selectedWarehouseId,
          salesRepresentativeId,
        ],
      );

      for (final line in lines) {
        final productId = line.productId!;
        final lineId = db.insert(
          '''
          INSERT INTO sales_items
            (invoice_id, product_id, product_name, product_code, quantity,
             unit_price, discount, total, unit_cost)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            invoiceId,
            productId,
            line.name,
            line.code,
            line.qty,
            line.price,
            line.discount,
            line.net,
            productPurchasePrice(productId),
          ],
        );
        DocumentCustomFields.saveLineValues(
          DocumentTypes.sale,
          invoiceId,
          lineId,
          line.customFields,
        );
        db.execute(
          'UPDATE products SET current_stock = current_stock - ?, '
          'last_selling_price = ?, last_qty = ?, updated_at = ? WHERE id = ?',
          [line.qty, line.price, line.qty, now, productId],
        );
        db.insert(
          '''
          INSERT INTO stock_movements
            (product_id, quantity, movement_type, reference_id,
             reference_type, from_warehouse_id, movement_date, notes)
          VALUES (?, ?, 'sale', ?, 'sales_invoice', ?, ?, ?)
          ''',
          [
            productId,
            -line.qty,
            invoiceId,
            selectedWarehouseId,
            documentDate,
            'بيع - فاتورة $invoiceNumber',
          ],
        );
      }

      if (quotationId != null) {
        db.execute(
          'UPDATE quotations SET status = ?, converted_invoice_id = ?, '
          'updated_at = ? WHERE id = ?',
          ['converted', invoiceId, now, quotationId],
        );
      }

      if (paymentInfo.paid > 0 && accountId != null) {
        recordPaymentRows(
          referenceId: invoiceId,
          referenceType: 'sales_invoice',
          accountId: accountId,
          amount: paymentInfo.paid,
          method: payment?.method ?? paymentMethod,
          description: 'تحصيل فاتورة بيع رقم $invoiceNumber',
          moneyIn: true,
          numberPrefix: 'RCV',
          now: now,
          treasuryId: payment?.treasuryId,
        );
      }

      DocumentCustomFields.saveValues(
        DocumentTypes.sale,
        invoiceId,
        customFields,
      );

      return InvoiceSaveResult(
        invoiceId: invoiceId,
        invoiceNumber: invoiceNumber,
        total: totals.total,
        paid: paymentInfo.paid,
        remaining: paymentInfo.remaining,
      );
    });
  }

  @override
  Future<InvoiceSaveResult> updateInvoice({
    required int invoiceId,
    required int? accountId,
    required String invoiceNumber,
    required List<InvoiceLine> lines,
    required int discount,
    required int addition,
    required String notes,
    required String paymentMethod,
    DateTime? invoiceDate,
    int? warehouseId,
    int? salesRepresentativeId,
    int? originalInvoiceId,
    Map<int, String> customFields = const {},
  }) async {
    final totals = validateInvoiceTotals(
      lines: lines,
      discount: discount,
      addition: addition,
    );
    _requireSalesRepresentative(salesRepresentativeId);
    return db.transaction<InvoiceSaveResult>(() async {
      final rows = db.query(
        'SELECT account_id, paid_amount, warehouse_id '
        'FROM sales_invoices WHERE id = ? AND is_return = 0',
        [invoiceId],
      );
      if (rows.isEmpty) {
        throw InvoiceValidationException('فاتورة البيع غير موجودة.');
      }
      final oldPaid = (rows.first['paid_amount'] as num?)?.toInt() ?? 0;
      final oldAccount = (rows.first['account_id'] as num?)?.toInt();
      if (oldPaid > 0 && accountId != oldAccount) {
        throw InvoiceValidationException(
          'لا يمكن تغيير الحساب بعد تسجيل مدفوعات على الفاتورة.',
        );
      }
      if (totals.total < oldPaid) {
        throw InvoiceValidationException(
          'إجمالي الفاتورة لا يمكن أن يكون أقل من المبلغ المسدد ($oldPaid).',
        );
      }
      final returns = db.query(
        'SELECT COUNT(*) AS c FROM sales_invoices WHERE is_return=1 AND original_invoice_id=?',
        [invoiceId],
      );
      if (((returns.first['c'] as num?)?.toInt() ?? 0) > 0) {
        throw InvoiceValidationException(
          'لا يمكن تعديل الفاتورة لأن عليها مرتجع بيع مسجل.',
        );
      }
      var oldWarehouseId = (rows.first['warehouse_id'] as num?)?.toInt();
      if (oldWarehouseId == null) {
        final movement = db.query(
          "SELECT from_warehouse_id FROM stock_movements WHERE reference_type='sales_invoice' "
          'AND reference_id=? AND from_warehouse_id IS NOT NULL LIMIT 1',
          [invoiceId],
        );
        if (movement.isNotEmpty) {
          oldWarehouseId = (movement.first['from_warehouse_id'] as num?)
              ?.toInt();
        }
      }
      final selectedWarehouseId =
          warehouseId ??
          oldWarehouseId ??
          WarehouseStock.defaultWarehouseId(db);
      final oldItems = db.query(
        'SELECT product_id, quantity FROM sales_items WHERE invoice_id=?',
        [invoiceId],
      );
      final restored = <int, int>{};
      for (final item in oldItems) {
        final productId = (item['product_id'] as num?)?.toInt();
        if (productId != null) {
          restored[productId] =
              (restored[productId] ?? 0) +
              ((item['quantity'] as num?)?.toInt() ?? 0);
        }
      }
      final requested = aggregateInvoiceQuantities(lines);
      for (final entry in requested.entries) {
        final stock = selectedWarehouseId == null
            ? currentStock(entry.key)
            : WarehouseStock.quantityInWarehouse(
                db,
                entry.key,
                selectedWarehouseId,
              );
        final available =
            stock +
            (selectedWarehouseId == oldWarehouseId
                ? (restored[entry.key] ?? 0)
                : 0);
        if (available < entry.value) {
          final line = lines.firstWhere((line) => line.productId == entry.key);
          throw InvoiceValidationException(
            'الكمية غير متاحة للصنف «${line.name}» — المتاح $available فقط.',
          );
        }
      }
      final now = DateTime.now().toIso8601String();
      final documentDate = (invoiceDate ?? DateTime.now()).toIso8601String();
      for (final item in oldItems) {
        final productId = (item['product_id'] as num?)?.toInt();
        if (productId != null) {
          db.execute(
            'UPDATE products SET current_stock=current_stock+?, updated_at=? WHERE id=?',
            [(item['quantity'] as num?)?.toInt() ?? 0, now, productId],
          );
        }
      }
      db.execute(
        "DELETE FROM stock_movements WHERE reference_type='sales_invoice' AND reference_id=?",
        [invoiceId],
      );
      db.execute(
        "DELETE FROM document_custom_line_values WHERE document_type='sale' AND document_id=?",
        [invoiceId],
      );
      db.execute('DELETE FROM sales_items WHERE invoice_id=?', [invoiceId]);
      for (final line in lines) {
        final productId = line.productId!;
        final lineId = db.insert(
          '''
          INSERT INTO sales_items
            (invoice_id, product_id, product_name, product_code, quantity,
             unit_price, discount, total, unit_cost)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            invoiceId,
            productId,
            line.name,
            line.code,
            line.qty,
            line.price,
            line.discount,
            line.net,
            productPurchasePrice(productId),
          ],
        );
        DocumentCustomFields.saveLineValues(
          DocumentTypes.sale,
          invoiceId,
          lineId,
          line.customFields,
        );
        db.execute(
          'UPDATE products SET current_stock=current_stock-?, last_selling_price=?, last_qty=?, updated_at=? WHERE id=?',
          [line.qty, line.price, line.qty, now, productId],
        );
        db.insert(
          '''
          INSERT INTO stock_movements
            (product_id, quantity, movement_type, reference_id,
             reference_type, from_warehouse_id, movement_date, notes)
          VALUES (?, ?, 'sale', ?, 'sales_invoice', ?, ?, ?)
          ''',
          [
            productId,
            -line.qty,
            invoiceId,
            selectedWarehouseId,
            documentDate,
            'بيع - فاتورة $invoiceNumber',
          ],
        );
      }
      final remaining = totals.total - oldPaid;
      final status = remaining <= 0
          ? 'paid'
          : (oldPaid > 0 ? 'partial' : 'unpaid');
      db.execute(
        '''
        UPDATE sales_invoices SET invoice_number=?, account_id=?, invoice_date=?, subtotal=?,
          discount=?, tax=?, total=?, paid_amount=?, remaining_amount=?,
          payment_status=?, notes=?, updated_at=?, warehouse_id=?, sales_rep_account_id=? WHERE id=?
        ''',
        [
          invoiceNumber,
          accountId,
          documentDate,
          totals.subtotal,
          totals.discount,
          totals.addition,
          totals.total,
          oldPaid,
          remaining,
          status,
          notes.isEmpty ? null : notes,
          now,
          selectedWarehouseId,
          salesRepresentativeId,
          invoiceId,
        ],
      );
      db.execute(
        "DELETE FROM document_custom_values WHERE document_type='sale' AND document_id=?",
        [invoiceId],
      );
      DocumentCustomFields.saveValues(
        DocumentTypes.sale,
        invoiceId,
        customFields,
      );
      return InvoiceSaveResult(
        invoiceId: invoiceId,
        invoiceNumber: invoiceNumber,
        total: totals.total,
        paid: oldPaid,
        remaining: remaining,
      );
    });
  }

  void _requireSalesRepresentative(int? accountId) {
    if (accountId == null) return;
    final rows = db.query(
      "SELECT id FROM accounts WHERE id=? AND account_type='rep' AND is_active=1",
      [accountId],
    );
    if (rows.isEmpty) {
      throw InvoiceValidationException(
        'مندوب البيع المحدد غير موجود أو غير نشط.',
      );
    }
  }

  @override
  Future<({int paid, int remaining})> recordPayment({
    required int invoiceId,
    required int accountId,
    required int amount,
    required String method,
    int? treasuryId,
  }) async {
    if (amount <= 0) {
      throw InvoiceValidationException('أدخل مبلغ تحصيل أكبر من صفر.');
    }
    requireAccount(accountId);
    final rows = db.query(
      'SELECT total, paid_amount, invoice_number, is_return FROM sales_invoices '
      'WHERE id = ?',
      [invoiceId],
    );
    if (rows.isEmpty) {
      throw InvoiceValidationException('الفاتورة غير موجودة.');
    }
    if ((rows.first['is_return'] as int? ?? 0) == 1) {
      throw InvoiceValidationException('هذا المستند مرتجع وليس فاتورة بيع.');
    }
    final total = (rows.first['total'] as int?) ?? 0;
    final alreadyPaid = (rows.first['paid_amount'] as int?) ?? 0;
    final invoiceNumber = '${rows.first['invoice_number'] ?? ''}';
    final remaining = total - alreadyPaid;
    if (remaining <= 0) {
      throw InvoiceValidationException('الفاتورة محصلة بالكامل.');
    }
    if (amount > remaining) {
      throw InvoiceValidationException(
        'المبلغ أكبر من المتبقي على الفاتورة ($remaining).',
      );
    }

    return db.transaction(() async {
      final now = DateTime.now().toIso8601String();
      recordPaymentRows(
        referenceId: invoiceId,
        referenceType: 'sales_invoice',
        accountId: accountId,
        amount: amount,
        method: method,
        description: 'تحصيل إضافي لفاتورة بيع رقم $invoiceNumber',
        moneyIn: true,
        numberPrefix: 'RCV',
        now: now,
        treasuryId: treasuryId,
      );
      final newPaid = alreadyPaid + amount;
      final newRemaining = total - newPaid;
      final status = newRemaining <= 0
          ? 'paid'
          : (newPaid > 0 ? 'partial' : 'unpaid');
      db.execute(
        'UPDATE sales_invoices SET paid_amount = ?, remaining_amount = ?, '
        'payment_status = ?, updated_at = ? WHERE id = ?',
        [newPaid, newRemaining, status, now, invoiceId],
      );
      return (paid: newPaid, remaining: newRemaining);
    });
  }

  @override
  Future<Map<String, Object?>?> getInvoice(int invoiceId) async {
    final rows = db.query(
      '''
      SELECT si.*, a.name AS account_name
      FROM sales_invoices si
      LEFT JOIN accounts a ON a.id = si.account_id
      WHERE si.id = ?
      ''',
      [invoiceId],
    );
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<List<Map<String, Object?>>> getInvoiceItems(int invoiceId) async {
    return db.query(
      'SELECT * FROM sales_items WHERE invoice_id = ? ORDER BY id',
      [invoiceId],
    );
  }

  /// Load a saved quotation so it can be turned into a sales invoice.
  @override
  Future<OriginalInvoiceData?> loadQuotation(int id) async {
    final rows = db.query(
      '''
      SELECT q.*, COALESCE(a.name, '') AS account_name
      FROM quotations q
      LEFT JOIN accounts a ON a.id = q.account_id
      WHERE q.id = ?
      ''',
      [id],
    );
    if (rows.isEmpty) return null;
    final quote = rows.first;
    final items = db.query(
      '''
      SELECT qi.*, p.current_stock,
             COALESCE(u.name, '') AS unit_name
      FROM quotation_items qi
      LEFT JOIN products p ON p.id = qi.product_id
      LEFT JOIN units u ON u.id = p.unit_id
      WHERE qi.quote_id = ?
      ORDER BY qi.id
      ''',
      [id],
    );
    return OriginalInvoiceData(
      id: id,
      number: '${quote['quote_number'] ?? ''}',
      accountId: quote['account_id'] as int?,
      accountName: '${quote['account_name'] ?? ''}',
      notes: '${quote['notes'] ?? ''}',
      lines: items.map((r) {
        final qty = (r['quantity'] as int?) ?? 0;
        return OriginalInvoiceLine(
          productId: (r['product_id'] as int?) ?? 0,
          name: '${r['product_name'] ?? ''}',
          code: '${r['product_code'] ?? ''}',
          unit: '${r['unit_name'] ?? ''}',
          quantity: qty,
          returnedQuantity: 0,
          available: (r['current_stock'] as int?) ?? 0,
          unitPrice: (r['unit_price'] as int?) ?? 0,
          discount: (r['discount'] as int?) ?? 0,
        );
      }).toList(),
    );
  }
}
