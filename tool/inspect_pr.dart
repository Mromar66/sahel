import 'package:sqlite3/sqlite3.dart';
void main(){
 final db=sqlite3.open('database/inventory.sqlite');
 for(final r in db.select("SELECT * FROM purchase_return_invoices")){print('PRI $r');}
 for(final r in db.select("SELECT * FROM purchase_return_items")){print('PIT $r');}
 for(final r in db.select("SELECT * FROM payments WHERE id>3")){print('PAY $r');}
 for(final r in db.select("SELECT * FROM treasury_transactions WHERE id>3")){print('TRE $r');}
 for(final r in db.select("SELECT * FROM stock_movements WHERE id>7")){print('MOV $r');}
 db.dispose();
}
