import 'package:inventory_app/core/services/document_custom_fields.dart';
import 'package:inventory_app/core/services/warehouse_stock.dart';
import 'package:inventory_app/features/invoice_ops/data/invoice_op_repository.dart';
import 'package:inventory_app/features/invoice_ops/domain/invoice_op_models.dart';

/// مرتجع بيع — builds a return document from a saved sales invoice, puts the
/// returned quantities back into stock and records any refund to the customer.
class SalesReturnRepository extends InvoiceRepositoryBase {
  SalesReturnRepository({super.database}) : super(InvoiceOpKind.salesReturn);

  @override
  bool get supportsOriginalInvoice => true;

  @override
  String nextInvoiceNumber() => nextNumber(
    table: 'sales_invoices',
    column: 'invoice_number',
    where: 'is_return = 1',
    prefix: 'SR-',
  );

  @override
  Future<List<OriginalInvoiceSummary>> searchOriginalInvoices(
    String term,
  ) async {
    final key = term.trim();
    final pattern = '%${key.replaceAll('%', '\\%')}%';
    final rows = db.query(
      '''
      SELECT si.id, si.invoice_number, si.invoice_date, si.total,
             COALESCE(a.name, '') AS party_name
      FROM sales_invoices si
      LEFT JOIN accounts a ON a.id = si.account_id
      WHERE si.is_return = 0
        AND (
          si.invoice_number LIKE ? ESCAPE '\\'
          OR IFNULL(a.name, '') LIKE ? ESCAPE '\\'
        )
      ORDER BY si.id DESC
      LIMIT 60
      ''',
      [pattern, pattern],
    );
    return rows
        .map(
          (r) => OriginalInvoiceSummary(
            id: r['id'] as int,
            number: '${r['invoice_number'] ?? ''}',
            date: '${r['invoice_date'] ?? ''}',
            partyName: '${r['party_name'] ?? ''}',
            total: (r['total'] as int?) ?? 0,
          ),
        )
        .toList();
  }

  @override
  Future<OriginalInvoiceData?> loadOriginalInvoice(int id) async {
    final rows = db.query(
      '''
      SELECT si.*, COALESCE(a.name, '') AS account_name
      FROM sales_invoices si
      LEFT JOIN accounts a ON a.id = si.account_id
      WHERE si.id = ? AND si.is_return = 0
      ''',
      [id],
    );
    if (rows.isEmpty) {
      throw InvoiceValidationException('فاتورة البيع غير موجودة.');
    }
    final invoice = rows.first;
    final items = db.query(
      '''
      SELECT si.invoice_id, si.product_id, si.product_name, si.product_code,
             si.quantity, si.unit_price, si.discount,
             COALESCE(u.name, '') AS unit_name,
             COALESCE((
               SELECT SUM(ri.quantity)
               FROM sales_items ri
               JOIN sales_invoices rinv ON rinv.id = ri.invoice_id
               WHERE rinv.is_return = 1
                 AND rinv.original_invoice_id = si.invoice_id
                 AND ri.product_id = si.product_id
             ), 0) AS returned_qty
      FROM sales_items si
      LEFT JOIN products p ON p.id = si.product_id
      LEFT JOIN units u ON u.id = p.unit_id
      WHERE si.invoice_id = ?
      ORDER BY si.id
      ''',
      [id],
    );
    final lines = <OriginalInvoiceLine>[];
    for (final r in items) {
      final qty = (r['quantity'] as int?) ?? 0;
      final returned = (r['returned_qty'] as int?) ?? 0;
      final returnable = qty - returned;
      if (returnable <= 0) continue;
      lines.add(
        OriginalInvoiceLine(
          productId: (r['product_id'] as int?) ?? 0,
          name: '${r['product_name'] ?? ''}',
          code: '${r['product_code'] ?? ''}',
          unit: '${r['unit_name'] ?? ''}',
          quantity: qty,
          returnedQuantity: returned,
          available: returnable,
          unitPrice: (r['unit_price'] as int?) ?? 0,
          discount: (r['discount'] as int?) ?? 0,
        ),
      );
    }
    if (lines.isEmpty) {
      throw InvoiceValidationException(
        'تم إرجاع كل كميات هذه الفاتورة بالفعل.',
      );
    }
    return OriginalInvoiceData(
      id: id,
      number: '${invoice['invoice_number'] ?? ''}',
      accountId: invoice['account_id'] as int?,
      accountName: '${invoice['account_name'] ?? ''}',
      notes: '${invoice['notes'] ?? ''}',
      lines: lines,
    );
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
    int? originalInvoiceId,
    int? quotationId,
    Map<int, String> customFields = const {},
  }) async {
    if (originalInvoiceId == null) {
      throw InvoiceValidationException('اختر فاتورة البيع الأصلية أولاً.');
    }
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

    return db.transaction<InvoiceSaveResult>(() async {
      final now = DateTime.now().toIso8601String();
      final invoiceRows = db.query(
        'SELECT invoice_number, account_id FROM sales_invoices '
        'WHERE id = ? AND is_return = 0',
        [originalInvoiceId],
      );
      if (invoiceRows.isEmpty) {
        throw InvoiceValidationException('فاتورة البيع الأصلية غير موجودة.');
      }
      final originalNumber = '${invoiceRows.first['invoice_number'] ?? ''}';
      final originalAccount = invoiceRows.first['account_id'] as int?;

      final requestedByProduct = aggregateInvoiceQuantities(lines);
      for (final entry in requestedByProduct.entries) {
        final productId = entry.key;
        final line = lines.firstWhere((line) => line.productId == productId);
        final originalQtyRows = db.query(
          'SELECT COALESCE(SUM(quantity), 0) AS qty FROM sales_items '
          'WHERE invoice_id = ? AND product_id = ?',
          [originalInvoiceId, productId],
        );
        final originalQty = (originalQtyRows.first['qty'] as int?) ?? 0;
        final returnedRows = db.query(
          '''
          SELECT COALESCE(SUM(ri.quantity), 0) AS qty
          FROM sales_items ri
          JOIN sales_invoices rinv ON rinv.id = ri.invoice_id
          WHERE rinv.is_return = 1
            AND rinv.original_invoice_id = ?
            AND ri.product_id = ?
          ''',
          [originalInvoiceId, productId],
        );
        final returned = (returnedRows.first['qty'] as int?) ?? 0;
        final remaining = originalQty - returned;
        if (entry.value > remaining) {
          throw InvoiceValidationException(
            'الكمية المرتجعة من «${line.name}» أكبر من المتبقي ($remaining).',
          );
        }
      }

      final invoiceId = db.insert(
        '''
        INSERT INTO sales_invoices
          (invoice_number, customer_id, account_id, invoice_date, subtotal,
           discount, tax, total, paid_amount, remaining_amount,
           payment_status, notes, is_return, original_invoice_id,
           created_at, updated_at)
        VALUES (?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?)
        ''',
        [
          invoiceNumber,
          accountId ?? originalAccount,
          now,
          totals.subtotal,
          totals.discount,
          totals.addition,
          totals.total,
          paymentInfo.paid,
          paymentInfo.remaining,
          paymentInfo.status,
          notes.isEmpty ? null : notes,
          originalInvoiceId,
          now,
          now,
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
            salesReturnUnitCost(originalInvoiceId, productId),
          ],
        );
        DocumentCustomFields.saveLineValues(
          DocumentTypes.salesReturn,
          invoiceId,
          lineId,
          line.customFields,
        );
        db.execute(
          'UPDATE products SET current_stock = current_stock + ?, '
          'updated_at = ? WHERE id = ?',
          [line.qty, now, productId],
        );
        db.insert(
          '''
          INSERT INTO stock_movements
            (product_id, quantity, movement_type, reference_id,
             reference_type, to_warehouse_id, movement_date, notes)
          VALUES (?, ?, 'return', ?, 'sales_return', ?, ?, ?)
          ''',
          [
            productId,
            line.qty,
            invoiceId,
            WarehouseStock.defaultWarehouseId(db),
            now,
            'مرتجع بيع - فاتورة $originalNumber',
          ],
        );
      }

      final payAccount = accountId ?? originalAccount;
      if (paymentInfo.paid > 0 && payAccount != null) {
        recordPaymentRows(
          referenceId: invoiceId,
          referenceType: 'sales_return',
          accountId: payAccount,
          amount: paymentInfo.paid,
          method: payment?.method ?? paymentMethod,
          description: 'استرداد قيمة مرتجع بيع رقم $invoiceNumber',
          moneyIn: false,
          numberPrefix: 'REF',
          now: now,
        );
      }

      DocumentCustomFields.saveValues(
        DocumentTypes.salesReturn,
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
    int? originalInvoiceId,
    Map<int, String> customFields = const {},
  }) async {
    final totals = validateInvoiceTotals(
      lines: lines,
      discount: discount,
      addition: addition,
    );
    return db.transaction<InvoiceSaveResult>(() async {
      final rows = db.query(
        'SELECT account_id, paid_amount, original_invoice_id '
        'FROM sales_invoices WHERE id = ? AND is_return = 1',
        [invoiceId],
      );
      if (rows.isEmpty) {
        throw InvoiceValidationException('مرتجع البيع غير موجود.');
      }
      final oldPaid = (rows.first['paid_amount'] as int?) ?? 0;
      final oldAccount = rows.first['account_id'] as int?;
      if (oldPaid > 0 && accountId != null && accountId != oldAccount) {
        throw InvoiceValidationException(
          'لا يمكن تغيير الحساب بعد تسجيل مبالغ استرداد على المرتجع.',
        );
      }
      if (totals.total < oldPaid) {
        throw InvoiceValidationException(
          'إجمالي المرتجع لا يمكن أن يكون أقل من المبلغ المسترد ($oldPaid).',
        );
      }
      final originalId =
          originalInvoiceId ??
          (rows.first['original_invoice_id'] as num?)?.toInt();
      if (originalId == null) {
        throw InvoiceValidationException('فاتورة البيع الأصلية غير موجودة.');
      }
      final invoiceRows = db.query(
        'SELECT invoice_number, account_id FROM sales_invoices '
        'WHERE id = ? AND is_return = 0',
        [originalId],
      );
      if (invoiceRows.isEmpty) {
        throw InvoiceValidationException('فاتورة البيع الأصلية غير موجودة.');
      }
      final originalAccount = invoiceRows.first['account_id'] as int?;
      final requestedByProduct = aggregateInvoiceQuantities(lines);
      for (final entry in requestedByProduct.entries) {
        final productId = entry.key;
        final line = lines.firstWhere((line) => line.productId == productId);
        final originalQtyRows = db.query(
          'SELECT COALESCE(SUM(quantity), 0) AS qty FROM sales_items '
          'WHERE invoice_id = ? AND product_id = ?',
          [originalId, productId],
        );
        final originalQty = (originalQtyRows.first['qty'] as int?) ?? 0;
        final returnedRows = db.query(
          '''
          SELECT COALESCE(SUM(ri.quantity), 0) AS qty
          FROM sales_items ri
          JOIN sales_invoices rinv ON rinv.id = ri.invoice_id
          WHERE rinv.is_return = 1
            AND rinv.original_invoice_id = ?
            AND rinv.id <> ?
            AND ri.product_id = ?
          ''',
          [originalId, invoiceId, productId],
        );
        final returned = (returnedRows.first['qty'] as int?) ?? 0;
        final available = originalQty - returned;
        if (entry.value > available) {
          throw InvoiceValidationException(
            'الكمية المرتجعة من «${line.name}» أكبر من المتبقي ($available).',
          );
        }
      }
      final now = DateTime.now().toIso8601String();
      final oldItems = db.query(
        'SELECT product_id, quantity FROM sales_items WHERE invoice_id = ?',
        [invoiceId],
      );
      for (final item in oldItems) {
        final productId = (item['product_id'] as num?)?.toInt();
        final qty = (item['quantity'] as int?) ?? 0;
        if (productId == null) continue;
        final stockRows = db.query(
          'SELECT current_stock FROM products WHERE id = ?',
          [productId],
        );
        final stock = stockRows.isEmpty
            ? 0
            : (stockRows.first['current_stock'] as int? ?? 0);
        if (stock < qty) {
          throw InvoiceValidationException(
            'لا يمكن تعديل المرتجع لأن بعض الكميات تم بيعها. '
            'المخزون الحالي غير كافٍ للتراجع.',
          );
        }
        db.execute(
          'UPDATE products SET current_stock = current_stock - ?, '
          'updated_at = ? WHERE id = ?',
          [qty, now, productId],
        );
      }
      db.execute(
        "DELETE FROM stock_movements WHERE reference_type='sales_return' "
        'AND reference_id = ?',
        [invoiceId],
      );
      db.execute(
        "DELETE FROM document_custom_line_values WHERE document_type='sales_return' AND document_id=?",
        [invoiceId],
      );
      db.execute('DELETE FROM sales_items WHERE invoice_id = ?', [invoiceId]);
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
            salesReturnUnitCost(originalId, productId),
          ],
        );
        DocumentCustomFields.saveLineValues(
          DocumentTypes.salesReturn,
          invoiceId,
          lineId,
          line.customFields,
        );
        db.execute(
          'UPDATE products SET current_stock = current_stock + ?, '
          'updated_at = ? WHERE id = ?',
          [line.qty, now, productId],
        );
        db.insert(
          '''
          INSERT INTO stock_movements
            (product_id, quantity, movement_type, reference_id,
             reference_type, to_warehouse_id, movement_date, notes)
          VALUES (?, ?, 'return', ?, 'sales_return', ?, ?, ?)
          ''',
          [
            productId,
            line.qty,
            invoiceId,
            WarehouseStock.defaultWarehouseId(db),
            now,
            'مرتجع بيع - فاتورة ${invoiceRows.first['invoice_number'] ?? ''}',
          ],
        );
      }
      final remaining = totals.total - oldPaid;
      final status = remaining <= 0
          ? 'paid'
          : (oldPaid > 0 ? 'partial' : 'unpaid');
      db.execute(
        '''
        UPDATE sales_invoices
        SET invoice_number = ?, account_id = ?, subtotal = ?, discount = ?,
            tax = ?, total = ?, paid_amount = ?, remaining_amount = ?,
            payment_status = ?, notes = ?, original_invoice_id = ?,
            updated_at = ?
        WHERE id = ?
        ''',
        [
          invoiceNumber,
          accountId ?? originalAccount,
          totals.subtotal,
          totals.discount,
          totals.addition,
          totals.total,
          oldPaid,
          remaining,
          status,
          notes.isEmpty ? null : notes,
          originalId,
          now,
          invoiceId,
        ],
      );
      db.execute(
        "DELETE FROM document_custom_values WHERE document_type='sales_return' "
        'AND document_id = ?',
        [invoiceId],
      );
      DocumentCustomFields.saveValues(
        DocumentTypes.salesReturn,
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

  @override
  Future<({int paid, int remaining})> recordPayment({
    required int invoiceId,
    required int accountId,
    required int amount,
    required String method,
  }) async {
    if (amount <= 0) {
      throw InvoiceValidationException('أدخل مبلغ استرداد أكبر من صفر.');
    }
    requireAccount(accountId);
    final rows = db.query(
      'SELECT total, paid_amount, invoice_number, is_return FROM sales_invoices '
      'WHERE id = ?',
      [invoiceId],
    );
    if (rows.isEmpty) {
      throw InvoiceValidationException('المستند غير موجود.');
    }
    if ((rows.first['is_return'] as int? ?? 0) != 1) {
      throw InvoiceValidationException('هذا المستند ليس مرتجع بيع.');
    }
    final total = (rows.first['total'] as int?) ?? 0;
    final alreadyPaid = (rows.first['paid_amount'] as int?) ?? 0;
    final invoiceNumber = '${rows.first['invoice_number'] ?? ''}';
    final remaining = total - alreadyPaid;
    if (remaining <= 0) {
      throw InvoiceValidationException('تم استرداد قيمة المرتجع بالكامل.');
    }
    if (amount > remaining) {
      throw InvoiceValidationException(
        'المبلغ أكبر من المتبقي على المرتجع ($remaining).',
      );
    }

    return db.transaction(() async {
      final now = DateTime.now().toIso8601String();
      recordPaymentRows(
        referenceId: invoiceId,
        referenceType: 'sales_return',
        accountId: accountId,
        amount: amount,
        method: method,
        description: 'استرداد إضافي لمرتجع بيع رقم $invoiceNumber',
        moneyIn: false,
        numberPrefix: 'REF',
        now: now,
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
}
