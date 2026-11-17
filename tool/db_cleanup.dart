import 'package:sqlite3/sqlite3.dart';

/// Removes the automated test products created while verifying the form and
/// the table column alignment. Never touches the user's real products.
void main() {
  final db = sqlite3.open('database/inventory.sqlite');
  db.execute("DELETE FROM products WHERE name LIKE 'TestItem%'");
  db.execute("DELETE FROM products WHERE name LIKE 'صف تجربة%'");
  final rows = db.select('SELECT id, name FROM products');
  print('remaining products: ${rows.length}');
  db.dispose();
}
