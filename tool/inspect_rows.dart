import 'package:sqlite3/sqlite3.dart';
void main(){
 final db=sqlite3.open('database/inventory.sqlite');
 for(final r in db.select("SELECT * FROM payments ORDER BY id")){print('PAY $r');}
 for(final r in db.select("SELECT * FROM treasury_transactions ORDER BY id")){print('TRE $r');}
 for(final r in db.select("SELECT * FROM stock_movements ORDER BY id")){print('MOV $r');}
 for(final r in db.select("SELECT * FROM sales_items ORDER BY id")){print('SIT $r');}
 db.dispose();
}
