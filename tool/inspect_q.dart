import 'package:sqlite3/sqlite3.dart';
void main(){
 final db=sqlite3.open('database/inventory.sqlite');
 for(final r in db.select("SELECT id,name,current_stock FROM products WHERE id IN (5,6,7)")){print('PROD $r');}
 for(final r in db.select("SELECT id,name,balance FROM accounts ORDER BY id")){print('ACC $r');}
 for(final r in db.select("SELECT * FROM quotations")){print('QUO $r');}
 for(final r in db.select("SELECT * FROM quotation_items")){print('QIT $r');}
 print('payments=${db.select('SELECT COUNT(*) c FROM payments').first['c']} treasury=${db.select('SELECT COUNT(*) c FROM treasury_transactions').first['c']} mov=${db.select('SELECT COUNT(*) c FROM stock_movements').first['c']}');
 db.dispose();
}
