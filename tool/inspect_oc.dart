import 'package:sqlite3/sqlite3.dart';

void main() {
  final db = sqlite3.open(
      r'C:\Users\amirt\AppData\Local\Temp\opencode\oc_copy.db');
  for (final t in db.select(
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")) {
    print(t['name']);
  }
  db.dispose();
}
