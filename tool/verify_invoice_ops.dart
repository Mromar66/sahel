import 'package:sqlite3/sqlite3.dart';
void main(){
 final db=sqlite3.open('database/inventory.sqlite');
 db.execute('PRAGMA foreign_keys=ON');
 void check(String label,String sql){
  final rows=db.select(sql);
  print('$label: ${rows.length}');
  for(final r in rows.take(10)){print('  $r');}
 }
 check('sales_items orphan invoice', 'SELECT si.id FROM sales_items si LEFT JOIN sales_invoices inv ON inv.id=si.invoice_id WHERE inv.id IS NULL');
 check('sales_items orphan product', 'SELECT si.id FROM sales_items si LEFT JOIN products p ON p.id=si.product_id WHERE p.id IS NULL');
 check('quotation_items orphan quote', 'SELECT qi.id FROM quotation_items qi LEFT JOIN quotations q ON q.id=qi.quote_id WHERE q.id IS NULL');
 check('quotation_items orphan product', 'SELECT qi.id FROM quotation_items qi LEFT JOIN products p ON p.id=qi.product_id WHERE p.id IS NULL');
 check('purchase_return_items orphan return', 'SELECT ri.id FROM purchase_return_items ri LEFT JOIN purchase_return_invoices r ON r.id=ri.return_id WHERE r.id IS NULL');
 check('purchase_return_items orphan product', 'SELECT ri.id FROM purchase_return_items ri LEFT JOIN products p ON p.id=ri.product_id WHERE p.id IS NULL');
 check('payments orphan sales_invoice', "SELECT pay.id FROM payments pay LEFT JOIN sales_invoices si ON si.id=pay.reference_id WHERE pay.reference_type='sales_invoice' AND si.id IS NULL");
 check('payments orphan sales_return', "SELECT pay.id FROM payments pay LEFT JOIN sales_invoices si ON si.id=pay.reference_id WHERE pay.reference_type='sales_return' AND si.id IS NULL");
 check('payments orphan purchase_return', "SELECT pay.id FROM payments pay LEFT JOIN purchase_return_invoices r ON r.id=pay.reference_id WHERE pay.reference_type='purchase_return' AND r.id IS NULL");
 check('treasury orphan sales_invoice', "SELECT t.id FROM treasury_transactions t LEFT JOIN sales_invoices si ON si.id=t.reference_id WHERE t.reference_type='sales_invoice' AND si.id IS NULL");
 check('treasury orphan sales_return', "SELECT t.id FROM treasury_transactions t LEFT JOIN sales_invoices si ON si.id=t.reference_id WHERE t.reference_type='sales_return' AND si.id IS NULL");
 check('treasury orphan purchase_return', "SELECT t.id FROM treasury_transactions t LEFT JOIN purchase_return_invoices r ON r.id=t.reference_id WHERE t.reference_type='purchase_return' AND r.id IS NULL");
 check('sale movements orphan invoice', "SELECT m.id FROM stock_movements m LEFT JOIN sales_invoices si ON si.id=m.reference_id WHERE m.reference_type='sales_invoice' AND si.id IS NULL");
 check('sales return movements orphan invoice', "SELECT m.id FROM stock_movements m LEFT JOIN sales_invoices si ON si.id=m.reference_id WHERE m.reference_type='sales_return' AND si.id IS NULL");
 check('purchase return movements orphan invoice', "SELECT m.id FROM stock_movements m LEFT JOIN purchase_return_invoices r ON r.id=m.reference_id WHERE m.reference_type='purchase_return' AND r.id IS NULL");
 check('duplicate sale numbers', 'SELECT invoice_number, COUNT(*) c FROM sales_invoices WHERE is_return=0 GROUP BY invoice_number HAVING c>1');
 check('duplicate sales return numbers', 'SELECT invoice_number, COUNT(*) c FROM sales_invoices WHERE is_return=1 GROUP BY invoice_number HAVING c>1');
 check('duplicate purchase return numbers', 'SELECT return_number, COUNT(*) c FROM purchase_return_invoices GROUP BY return_number HAVING c>1');
 check('duplicate quotation numbers', 'SELECT quote_number, COUNT(*) c FROM quotations GROUP BY quote_number HAVING c>1');
 check('invalid payment statuses', "SELECT id,payment_status FROM sales_invoices WHERE payment_status NOT IN ('paid','partial','unpaid')");
 for(final r in db.select('''SELECT p.id,p.product_code,p.current_stock,
   COALESCE((SELECT SUM(quantity) FROM stock_movements m WHERE m.product_id=p.id),0) AS movement_net
   FROM products p ORDER BY p.id''')){
   print('STOCK ${r['product_code']}: current=${r['current_stock']} movements=${r['movement_net']}');
 }
 db.dispose();
}
