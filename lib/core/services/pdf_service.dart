import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:inventory_app/core/database/sqlite_database.dart';

/// Service for generating PDF invoices locally.
class PdfService {
  PdfService._internal();

  static final PdfService _instance = PdfService._internal();

  factory PdfService() => _instance;

  final _db = SqliteDatabase();

  List<pw.Widget> _businessHeader() {
    String setting(String key) {
      final rows = _db.query('SELECT value FROM settings WHERE key=?', [key]);
      return rows.isEmpty ? '' : '${rows.first['value'] ?? ''}';
    }

    final name = setting('settings.project_name');
    final contacts = [
      setting('settings.contact'),
      setting('settings.phone'),
      setting('settings.address'),
    ].where((value) => value.isNotEmpty).join(' | ');
    return [
      if (name.isNotEmpty)
        pw.Center(
          child: pw.Text(
            name,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
        ),
      if (contacts.isNotEmpty)
        pw.Center(
          child: pw.Text(contacts, style: const pw.TextStyle(fontSize: 9)),
        ),
      if (name.isNotEmpty || contacts.isNotEmpty) pw.SizedBox(height: 10),
    ];
  }

  /// Generate a sales invoice PDF and return the file path.
  Future<String> generateSalesInvoicePdf({required int invoiceId}) async {
    final rows = _db.query('SELECT * FROM sales_invoices WHERE id = ?', [
      invoiceId,
    ]);
    if (rows.isEmpty) {
      throw Exception('Invoice not found');
    }
    final invoice = rows.first;

    final items = _db.query('SELECT * FROM sales_items WHERE invoice_id = ?', [
      invoiceId,
    ]);

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              ..._businessHeader(),
              pw.Text(
                'فاتورة مبيعات',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('رقم الفاتورة: ${invoice['invoice_number']}'),
              pw.Text('التاريخ: ${invoice['invoice_date']}'),
              pw.Text('العميل: ${invoice['customer_id']}'),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                context: context,
                data: <List<String>>[
                  ['المنتج', 'الكمية', 'سعر الوحدة', 'المجموع'],
                  ...items.map(
                    (item) => [
                      item['product_name'] ?? '',
                      item['quantity'].toString(),
                      '${item['unit_price']}',
                      '${item['total']}',
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text('المجموع الفرعي: ${invoice['subtotal']}'),
              pw.Text('الخصم: ${invoice['discount']}'),
              pw.Text('الضريبة: ${invoice['tax']}'),
              pw.Text(
                'الإجمالي: ${invoice['total']}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('المبلغ المدفوع: ${invoice['paid_amount']}'),
              pw.Text('المبلغ المتبقي: ${invoice['remaining_amount']}'),
            ],
          );
        },
      ),
    );

    final output = await getInvoiceFolder();
    final file = File(
      '${output.path}/invoice_${invoice['invoice_number']}.pdf',
    );
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  /// Print the invoice to a local printer.
  Future<void> printInvoice({required int invoiceId}) async {
    final rows = _db.query('SELECT * FROM sales_invoices WHERE id = ?', [
      invoiceId,
    ]);
    if (rows.isEmpty) {
      throw Exception('Invoice not found');
    }
    final invoice = rows.first;

    final items = _db.query('SELECT * FROM sales_items WHERE invoice_id = ?', [
      invoiceId,
    ]);

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              ..._businessHeader(),
              pw.Text(
                'فاتورة مبيعات',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('رقم الفاتورة: ${invoice['invoice_number']}'),
              pw.Text('التاريخ: ${invoice['invoice_date']}'),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                context: context,
                data: <List<String>>[
                  ['المنتج', 'الكمية', 'سعر الوحدة', 'المجموع'],
                  ...items.map(
                    (item) => [
                      item['product_name'] ?? '',
                      item['quantity'].toString(),
                      '${item['unit_price']}',
                      '${item['total']}',
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'الإجمالي: ${invoice['total']}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<Directory> getInvoiceFolder() async {
    final appDir = await getApplicationSupportDirectory();
    final invoiceFolder = Directory('${appDir.path}/invoices');
    if (!await invoiceFolder.exists()) {
      await invoiceFolder.create(recursive: true);
    }
    return invoiceFolder;
  }
}
