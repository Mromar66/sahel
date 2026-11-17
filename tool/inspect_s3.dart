import 'package:sqlite3/sqlite3.dart';
void main(){
 final db=sqlite3.open('database/inventory.sqlite');
 for(final r in db.select("SELECT id,name,balance FROM accounts WHERE id IN (2,3,6)")){print('ACC $r');}
 for(final r in db.select("SELECT id,invoice_number,total,paid_amount,remaining_amount,payment_status,account_id FROM sales_invoices ORDER BY id")){print('SI $r');}
 print('payments=${db.select('SELECT COUNT(*) c FROM payments').first['c']} treasury=${db.select('SELECT COUNT(*) c FROM treasury_transactions').first['c']}');
 for(final r in db.select("SELECT * FROM payments WHERE id>4")){print('PAY $r');}
 for(final r in db.select("SELECT * FROM treasury_transactions WHERE id>4")){print('TRE $r');}
 for(final r in db.select("SELECT id,name,current_stock FROM products WHERE id=6")){print('PROD $r');}
 db.dispose();
}
