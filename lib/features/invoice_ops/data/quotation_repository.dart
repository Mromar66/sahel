import 'package:inventory_app/core/services/document_custom_fields.dart';
import 'package:inventory_app/features/invoice_ops/data/invoice_op_repository.dart';
import 'package:inventory_app/features/invoice_ops/domain/invoice_op_models.dart';

/// عرض أسعار — saves a priced offer for a customer. It never moves stock and
/// never records a payment; conversion to a real sale happens on the sale page.
class QuotationRepository extends InvoiceRepositoryBase {
  QuotationRepository() : super(InvoiceOpKind.quotation);

  @override
  String nextInvoiceNumber() => nextNumber(
    table: 'quotations',
    column: 'quote_number',
    where: '',
    prefix: 'Q-',
  );

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
    if (payment != null && payment.amount > 0) {
      throw InvoiceValidationException(
        'عرض السعر لا يسجل مدفوعات. حوّله إلى فاتورة بيع لتحصيل المبلغ.',
      );
    }
    final totals = validateInvoiceTotals(
      lines: lines,
      discount: discount,
      addition: addition,
    );

    return db.transaction<InvoiceSaveResult>(() async {
      final now = DateTime.now().toIso8601String();
      final quoteId = db.insert(
        '''
        INSERT INTO quotations
          (quote_number, account_id, quote_date, subtotal, discount, tax,
           total, status, notes, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, 'open', ?, ?, ?)
        ''',
        [
          invoiceNumber,
          accountId,
          now,
          totals.subtotal,
          totals.discount,
          totals.addition,
          totals.total,
          notes.isEmpty ? null : notes,
          now,
          now,
        ],
      );
      for (final line in lines) {
        final lineId = db.insert(
          '''
          INSERT INTO quotation_items
            (quote_id, product_id, product_name, product_code, quantity,
             unit_price, discount, total)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            quoteId,
            line.productId,
            line.name,
            line.code,
            line.qty,
            line.price,
            line.discount,
            line.net,
          ],
        );
        DocumentCustomFields.saveLineValues(
          DocumentTypes.quotation,
          quoteId,
          lineId,
          line.customFields,
        );
      }
      DocumentCustomFields.saveValues(
        DocumentTypes.quotation,
        quoteId,
        customFields,
      );
      return InvoiceSaveResult(
        invoiceId: quoteId,
        invoiceNumber: invoiceNumber,
        total: totals.total,
        paid: 0,
        remaining: totals.total,
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
        'SELECT converted_invoice_id FROM quotations WHERE id = ?',
        [invoiceId],
      );
      if (rows.isEmpty) {
        throw InvoiceValidationException('عرض السعر غير موجود.');
      }
      if (rows.first['converted_invoice_id'] != null) {
        throw InvoiceValidationException(
          'عرض السعر محوّل إلى فاتورة بيع ولا يمكن تعديله.',
        );
      }
      final now = DateTime.now().toIso8601String();
      db.execute(
        "DELETE FROM document_custom_line_values WHERE document_type='quotation' AND document_id=?",
        [invoiceId],
      );
      db.execute('DELETE FROM quotation_items WHERE quote_id = ?', [invoiceId]);
      for (final line in lines) {
        final lineId = db.insert(
          '''
          INSERT INTO quotation_items
            (quote_id, product_id, product_name, product_code, quantity,
             unit_price, discount, total)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            invoiceId,
            line.productId,
            line.name,
            line.code,
            line.qty,
            line.price,
            line.discount,
            line.net,
          ],
        );
        DocumentCustomFields.saveLineValues(
          DocumentTypes.quotation,
          invoiceId,
          lineId,
          line.customFields,
        );
      }
      db.execute(
        '''
        UPDATE quotations
        SET quote_number = ?, account_id = ?, subtotal = ?, discount = ?,
            tax = ?, total = ?, notes = ?, updated_at = ?
        WHERE id = ?
        ''',
        [
          invoiceNumber,
          accountId,
          totals.subtotal,
          totals.discount,
          totals.addition,
          totals.total,
          notes.isEmpty ? null : notes,
          now,
          invoiceId,
        ],
      );
      db.execute(
        "DELETE FROM document_custom_values WHERE document_type='quotation' "
        'AND document_id = ?',
        [invoiceId],
      );
      DocumentCustomFields.saveValues(
        DocumentTypes.quotation,
        invoiceId,
        customFields,
      );
      return InvoiceSaveResult(
        invoiceId: invoiceId,
        invoiceNumber: invoiceNumber,
        total: totals.total,
        paid: 0,
        remaining: totals.total,
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
    throw InvoiceValidationException(
      'عرض السعر لا يسجل مدفوعات. حوّله إلى فاتورة بيع أولاً.',
    );
  }

  @override
  Future<Map<String, Object?>?> getInvoice(int invoiceId) async {
    final rows = db.query(
      '''
      SELECT q.id, q.quote_number AS invoice_number, q.account_id,
             q.quote_date AS invoice_date, q.subtotal, q.discount, q.tax,
             q.total, 0 AS paid_amount, q.total AS remaining_amount,
             q.status AS payment_status, q.notes, q.status, q.created_at,
             q.updated_at, a.name AS account_name
      FROM quotations q
      LEFT JOIN accounts a ON a.id = q.account_id
      WHERE q.id = ?
      ''',
      [invoiceId],
    );
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<List<Map<String, Object?>>> getInvoiceItems(int invoiceId) async {
    return db.query(
      'SELECT * FROM quotation_items WHERE quote_id = ? ORDER BY id',
      [invoiceId],
    );
  }
}
