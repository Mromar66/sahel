import 'package:safwa/core/services/document_custom_fields.dart';
import 'package:safwa/core/services/warehouse_stock.dart';
import 'package:safwa/features/invoice_ops/data/invoice_op_repository.dart';
import 'package:safwa/features/invoice_ops/domain/invoice_op_models.dart';

/// مرتجع شراء — builds a return document from a saved purchase invoice, takes
/// the returned quantities out of stock and records any refund from the
/// supplier. It uses its own document tables so the purchase invoice numbering
/// used by the شراء screen is never disturbed.
class PurchaseReturnRepository extends InvoiceRepositoryBase {
  PurchaseReturnRepository({super.database})
    : super(InvoiceOpKind.purchaseReturn);

  @override
  bool get supportsOriginalInvoice => true;

  @override
  String nextInvoiceNumber() => nextNumber(
    table: 'purchase_return_invoices',
    column: 'return_number',
    where: '',
    prefix: 'PR-',
  );

  @override
  Future<List<OriginalInvoiceSummary>> searchOriginalInvoices(
    String term,
  ) async {
    final key = term.trim();
    final pattern = '%${key.replaceAll('%', '\\%')}%';
    final rows = db.query(
      '''
      SELECT pi.id, pi.invoice_number, pi.invoice_date, pi.total,
             COALESCE(a.name, '') AS party_name
      FROM purchase_invoices pi
      LEFT JOIN accounts a ON a.id = pi.account_id
      WHERE pi.is_return = 0
        AND (
          pi.invoice_number LIKE ? ESCAPE '\\'
          OR IFNULL(a.name, '') LIKE ? ESCAPE '\\'
        )
      ORDER BY pi.id DESC
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
      SELECT pi.*, COALESCE(a.name, '') AS account_name
      FROM purchase_invoices pi
      LEFT JOIN accounts a ON a.id = pi.account_id
      WHERE pi.id = ? AND pi.is_return = 0
      ''',
      [id],
    );
    if (rows.isEmpty) {
      throw InvoiceValidationException('فاتورة الشراء غير موجودة.');
    }
    final invoice = rows.first;
    final items = db.query(
      '''
      SELECT pi.invoice_id, pi.product_id, pi.product_name, pi.product_code,
             pi.quantity, pi.unit_price, pi.discount,
             p.current_stock,
             COALESCE(u.name, '') AS unit_name,
             COALESCE((
               SELECT SUM(ri.quantity)
               FROM purchase_return_items ri
               JOIN purchase_return_invoices rinv ON rinv.id = ri.return_id
               WHERE rinv.original_invoice_id = pi.invoice_id
                 AND ri.product_id = pi.product_id
             ), 0) AS returned_qty
      FROM purchase_items pi
      LEFT JOIN products p ON p.id = pi.product_id
      LEFT JOIN units u ON u.id = p.unit_id
      WHERE pi.invoice_id = ?
      ORDER BY pi.id
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
          available: (r['current_stock'] as int?) ?? 0,
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
    DateTime? invoiceDate,
    int? warehouseId,
    int? salesRepresentativeId,
    int? originalInvoiceId,
    int? quotationId,
    Map<int, String> customFields = const {},
  }) async {
    if (originalInvoiceId == null) {
      throw InvoiceValidationException('اختر فاتورة الشراء الأصلية أولاً.');
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
        'SELECT invoice_number, account_id FROM purchase_invoices '
        'WHERE id = ? AND is_return = 0',
        [originalInvoiceId],
      );
      if (invoiceRows.isEmpty) {
        throw InvoiceValidationException('فاتورة الشراء الأصلية غير موجودة.');
      }
      final originalNumber = '${invoiceRows.first['invoice_number'] ?? ''}';
      final originalAccount = invoiceRows.first['account_id'] as int?;

      final requestedByProduct = aggregateInvoiceQuantities(lines);
      for (final entry in requestedByProduct.entries) {
        final productId = entry.key;
        final line = lines.firstWhere((line) => line.productId == productId);
        final originalQtyRows = db.query(
          'SELECT COALESCE(SUM(quantity), 0) AS qty FROM purchase_items '
          'WHERE invoice_id = ? AND product_id = ?',
          [originalInvoiceId, productId],
        );
        final originalQty = (originalQtyRows.first['qty'] as int?) ?? 0;
        final returnedRows = db.query(
          '''
          SELECT COALESCE(SUM(ri.quantity), 0) AS qty
          FROM purchase_return_items ri
          JOIN purchase_return_invoices rinv ON rinv.id = ri.return_id
          WHERE rinv.original_invoice_id = ? AND ri.product_id = ?
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
        final stock = currentStockInDefaultWarehouse(productId);
        if (stock < entry.value) {
          throw InvoiceValidationException(
            'الكمية غير متاحة للصنف «${line.name}» — المتاح $stock فقط.',
          );
        }
      }

      final returnId = db.insert(
        '''
        INSERT INTO purchase_return_invoices
          (return_number, account_id, original_invoice_id, return_date,
           subtotal, discount, tax, total, refunded_amount, remaining_amount,
           payment_status, notes, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          invoiceNumber,
          accountId ?? originalAccount,
          originalInvoiceId,
          now,
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
        ],
      );

      for (final line in lines) {
        final productId = line.productId!;
        final lineId = db.insert(
          '''
          INSERT INTO purchase_return_items
            (return_id, product_id, product_name, product_code, quantity,
             unit_price, discount, total)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            returnId,
            productId,
            line.name,
            line.code,
            line.qty,
            line.price,
            line.discount,
            line.net,
          ],
        );
        DocumentCustomFields.saveLineValues(
          DocumentTypes.purchaseReturn,
          returnId,
          lineId,
          line.customFields,
        );
        db.execute(
          'UPDATE products SET current_stock = current_stock - ?, '
          'updated_at = ? WHERE id = ?',
          [line.qty, now, productId],
        );
        db.insert(
          '''
          INSERT INTO stock_movements
            (product_id, quantity, movement_type, reference_id,
             reference_type, from_warehouse_id, movement_date, notes)
          VALUES (?, ?, 'return', ?, 'purchase_return', ?, ?, ?)
          ''',
          [
            productId,
            -line.qty,
            returnId,
            WarehouseStock.defaultWarehouseId(db),
            now,
            'مرتجع شراء - فاتورة $originalNumber',
          ],
        );
      }

      final payAccount = accountId ?? originalAccount;
      if (paymentInfo.paid > 0 && payAccount != null) {
        recordPaymentRows(
          referenceId: returnId,
          referenceType: 'purchase_return',
          accountId: payAccount,
          amount: paymentInfo.paid,
          method: payment?.method ?? paymentMethod,
          description: 'تحصيل قيمة مرتجع شراء رقم $invoiceNumber',
          moneyIn: true,
          numberPrefix: 'RCV',
          now: now,
          treasuryId: payment?.treasuryId,
        );
      }

      DocumentCustomFields.saveValues(
        DocumentTypes.purchaseReturn,
        returnId,
        customFields,
      );

      return InvoiceSaveResult(
        invoiceId: returnId,
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
    return db.transaction<InvoiceSaveResult>(() async {
      final rows = db.query(
        'SELECT account_id, refunded_amount, original_invoice_id '
        'FROM purchase_return_invoices WHERE id = ?',
        [invoiceId],
      );
      if (rows.isEmpty) {
        throw InvoiceValidationException('مرتجع الشراء غير موجود.');
      }
      final oldPaid = (rows.first['refunded_amount'] as int?) ?? 0;
      final oldAccount = rows.first['account_id'] as int?;
      if (oldPaid > 0 && accountId != null && accountId != oldAccount) {
        throw InvoiceValidationException(
          'لا يمكن تغيير الحساب بعد تسجيل مبالغ تحصيل على المرتجع.',
        );
      }
      if (totals.total < oldPaid) {
        throw InvoiceValidationException(
          'إجمالي المرتجع لا يمكن أن يكون أقل من المبلغ المحصل ($oldPaid).',
        );
      }
      final originalId =
          originalInvoiceId ??
          (rows.first['original_invoice_id'] as num?)?.toInt();
      if (originalId == null) {
        throw InvoiceValidationException('فاتورة الشراء الأصلية غير موجودة.');
      }
      final invoiceRows = db.query(
        'SELECT invoice_number, account_id FROM purchase_invoices '
        'WHERE id = ? AND is_return = 0',
        [originalId],
      );
      if (invoiceRows.isEmpty) {
        throw InvoiceValidationException('فاتورة الشراء الأصلية غير موجودة.');
      }
      final originalAccount = invoiceRows.first['account_id'] as int?;
      final oldItems = db.query(
        'SELECT product_id, quantity FROM purchase_return_items '
        'WHERE return_id = ?',
        [invoiceId],
      );
      final restored = <int, int>{};
      for (final item in oldItems) {
        final productId = (item['product_id'] as num?)?.toInt();
        if (productId != null) {
          restored[productId] =
              (restored[productId] ?? 0) + ((item['quantity'] as int?) ?? 0);
        }
      }
      final requestedByProduct = aggregateInvoiceQuantities(lines);
      for (final entry in requestedByProduct.entries) {
        final productId = entry.key;
        final line = lines.firstWhere((line) => line.productId == productId);
        final originalQtyRows = db.query(
          'SELECT COALESCE(SUM(quantity), 0) AS qty FROM purchase_items '
          'WHERE invoice_id = ? AND product_id = ?',
          [originalId, productId],
        );
        final originalQty = (originalQtyRows.first['qty'] as int?) ?? 0;
        final returnedRows = db.query(
          '''
          SELECT COALESCE(SUM(ri.quantity), 0) AS qty
          FROM purchase_return_items ri
          JOIN purchase_return_invoices rinv ON rinv.id = ri.return_id
          WHERE rinv.original_invoice_id = ?
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
        final stock =
            currentStockInDefaultWarehouse(productId) +
            (restored[productId] ?? 0);
        if (stock < entry.value) {
          throw InvoiceValidationException(
            'الكمية غير متاحة للصنف «${line.name}» — المتاح $stock فقط.',
          );
        }
      }
      final now = DateTime.now().toIso8601String();
      for (final item in oldItems) {
        final productId = (item['product_id'] as num?)?.toInt();
        if (productId == null) continue;
        db.execute(
          'UPDATE products SET current_stock = current_stock + ?, '
          'updated_at = ? WHERE id = ?',
          [(item['quantity'] as int?) ?? 0, now, productId],
        );
      }
      db.execute(
        "DELETE FROM stock_movements WHERE reference_type='purchase_return' "
        'AND reference_id = ?',
        [invoiceId],
      );
      db.execute('DELETE FROM purchase_return_items WHERE return_id = ?', [
        invoiceId,
      ]);
      db.execute(
        "DELETE FROM document_custom_line_values WHERE document_type='purchase_return' AND document_id=?",
        [invoiceId],
      );
      for (final line in lines) {
        final productId = line.productId!;
        final lineId = db.insert(
          '''
          INSERT INTO purchase_return_items
            (return_id, product_id, product_name, product_code, quantity,
             unit_price, discount, total)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
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
          ],
        );
        DocumentCustomFields.saveLineValues(
          DocumentTypes.purchaseReturn,
          invoiceId,
          lineId,
          line.customFields,
        );
        db.execute(
          'UPDATE products SET current_stock = current_stock - ?, '
          'updated_at = ? WHERE id = ?',
          [line.qty, now, productId],
        );
        db.insert(
          '''
          INSERT INTO stock_movements
            (product_id, quantity, movement_type, reference_id,
             reference_type, from_warehouse_id, movement_date, notes)
          VALUES (?, ?, 'return', ?, 'purchase_return', ?, ?, ?)
          ''',
          [
            productId,
            -line.qty,
            invoiceId,
            WarehouseStock.defaultWarehouseId(db),
            now,
            'مرتجع شراء - فاتورة ${invoiceRows.first['invoice_number'] ?? ''}',
          ],
        );
      }
      final remaining = totals.total - oldPaid;
      final status = remaining <= 0
          ? 'paid'
          : (oldPaid > 0 ? 'partial' : 'unpaid');
      db.execute(
        '''
        UPDATE purchase_return_invoices
        SET return_number = ?, account_id = ?, subtotal = ?, discount = ?,
            tax = ?, total = ?, refunded_amount = ?, remaining_amount = ?,
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
        "DELETE FROM document_custom_values "
        "WHERE document_type='purchase_return' AND document_id = ?",
        [invoiceId],
      );
      DocumentCustomFields.saveValues(
        DocumentTypes.purchaseReturn,
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
    int? treasuryId,
  }) async {
    if (amount <= 0) {
      throw InvoiceValidationException('أدخل مبلغ تحصيل أكبر من صفر.');
    }
    requireAccount(accountId);
    final rows = db.query(
      'SELECT total, refunded_amount, remaining_amount, return_number '
      'FROM purchase_return_invoices WHERE id = ?',
      [invoiceId],
    );
    if (rows.isEmpty) {
      throw InvoiceValidationException('المستند غير موجود.');
    }
    final total = (rows.first['total'] as int?) ?? 0;
    final alreadyPaid = (rows.first['refunded_amount'] as int?) ?? 0;
    final invoiceNumber = '${rows.first['return_number'] ?? ''}';
    final remaining = total - alreadyPaid;
    if (remaining <= 0) {
      throw InvoiceValidationException('تم تحصيل قيمة المرتجع بالكامل.');
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
        referenceType: 'purchase_return',
        accountId: accountId,
        amount: amount,
        method: method,
        description: 'تحصيل إضافي لمرتجع شراء رقم $invoiceNumber',
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
        'UPDATE purchase_return_invoices SET refunded_amount = ?, '
        'remaining_amount = ?, payment_status = ?, updated_at = ? WHERE id = ?',
        [newPaid, newRemaining, status, now, invoiceId],
      );
      return (paid: newPaid, remaining: newRemaining);
    });
  }

  @override
  Future<Map<String, Object?>?> getInvoice(int invoiceId) async {
    final rows = db.query(
      '''
      SELECT ri.*, a.name AS account_name
      FROM purchase_return_invoices ri
      LEFT JOIN accounts a ON a.id = ri.account_id
      WHERE ri.id = ?
      ''',
      [invoiceId],
    );
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<List<Map<String, Object?>>> getInvoiceItems(int invoiceId) async {
    return db.query(
      'SELECT * FROM purchase_return_items WHERE return_id = ? ORDER BY id',
      [invoiceId],
    );
  }
}
