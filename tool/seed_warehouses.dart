import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Adds the two warehouses used by the transfer smoke test when the test
/// database has none. Run with: dart run tool/seed_warehouses.dart
void main() {
  final db = sqlite3.open('database/inventory.sqlite');
  final count = db.select('SELECT COUNT(*) AS c FROM warehouses').first['c'] as int;
  if (count == 0) {
    final now = DateTime.now().toIso8601String();
    db.execute(
      'INSERT INTO warehouses (name, location, description, is_active, created_at) '
      'VALUES (?, ?, ?, 1, ?)',
      ['المخزن الرئيسي', 'الفرع الرئيسي', 'مخزن رئيسي', now],
    );
    db.execute(
      'INSERT INTO warehouses (name, location, description, is_active, created_at) '
      'VALUES (?, ?, ?, 1, ?)',
      ['المخزن الفرعي', 'الفرع الثاني', 'مخزن فرعي', now],
    );
  }
  final rows = db.select('SELECT id, name FROM warehouses ORDER BY id');
  for (final row in rows) {
    stdout.writeln('${row['id']}: ${row['name']}');
  }
  db.dispose();
}
