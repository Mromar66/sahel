import 'package:sqlite3/sqlite3.dart';
void main(){
 final db=sqlite3.open('database/inventory.sqlite');
 db.execute('PRAGMA foreign_keys=ON');
 for(final r in db.select('SELECT id,name,product_code,purchase_price,selling_price,current_stock,is_active FROM products ORDER BY id')){print(r);}
 print('--- accounts');
 for(final r in db.select('SELECT id,name,account_type,balance,is_active FROM accounts ORDER BY id')){print(r);}
 print('--- sales invoices');
 for(final r in db.select('SELECT * FROM sales_invoices ORDER BY id LIMIT 10')){print(r);}
 print('--- purchase invoices');
 for(final r in db.select('SELECT id,invoice_number,account_id,total,paid_amount,payment_status FROM purchase_invoices ORDER BY id')){print(r);}
 print('--- purchase items');
 for(final r in db.select('SELECT * FROM purchase_items ORDER BY id')){print(r);}
 print('--- counts');
 for(final t in ['sales_invoices','sales_items','quotations','quotation_items','purchase_return_invoices','purchase_return_items','payments','treasury_transactions','stock_movements']){
  try{print('$t: ${db.select('SELECT COUNT(*) c FROM $t').first['c']}');}catch(e){print('$t: MISSING');}
 }
 db.dispose();
}
