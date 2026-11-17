import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Database health report: integrity, foreign keys, indexes and row counts.
/// Run with: dart run tool/db_check.dart
void main() {
  final db = sqlite3.open('database/inventory.sqlite');
  db.execute('PRAGMA foreign_keys = ON');

  stdout.writeln('journal_mode: ${db.select('PRAGMA journal_mode').first.values.first}');
  stdout.writeln('foreign_keys: ${db.select('PRAGMA foreign_keys').first.values.first}');

  final integrity = db.select('PRAGMA integrity_check');
  stdout.writeln('\nintegrity_check:');
  for (final row in integrity) {
    stdout.writeln('  ${row.values.first}');
  }

  final fk = db.select('PRAGMA foreign_key_check');
  stdout.writeln('\nforeign_key_check: ${fk.isEmpty ? 'OK (no violations)' : '${fk.length} violation(s)'}');
  for (final row in fk) {
    stdout.writeln('  $row');
  }

  final tables = db.select(
    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
  );
  stdout.writeln('\ntables (${tables.length}):');
  for (final t in tables) {
    final name = t['name'] as String;
    final count = db.select('SELECT COUNT(*) AS c FROM "$name"').first['c'] as int;
    stdout.writeln('  ${name.padRight(28)} $count rows');
  }

  final indexes = db.select(
    "SELECT name, tbl_name FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%' ORDER BY tbl_name, name",
  );
  stdout.writeln('\nindexes (${indexes.length}):');
  for (final i in indexes) {
    stdout.writeln('  ${i['tbl_name']}.${i['name']}');
  }

  final orphans = db.select('''
    SELECT 'stock_movements' AS t, COUNT(*) AS c FROM stock_movements sm
      LEFT JOIN products p ON p.id = sm.product_id WHERE p.id IS NULL
    UNION ALL
    SELECT 'stock_adjustment_items', COUNT(*) FROM stock_adjustment_items i
      LEFT JOIN stock_adjustment_sessions s ON s.id = i.session_id WHERE s.id IS NULL
    UNION ALL
    SELECT 'stock_transfer_items', COUNT(*) FROM stock_transfer_items i
      LEFT JOIN stock_transfer_sessions s ON s.id = i.session_id WHERE s.id IS NULL
    UNION ALL
    SELECT 'stocktaking_items', COUNT(*) FROM stocktaking_items i
      LEFT JOIN stocktaking_sessions s ON s.id = i.session_id WHERE s.id IS NULL
  ''');
  stdout.writeln('\norphan rows:');
  for (final row in orphans) {
    stdout.writeln('  ${row['t']}: ${row['c']}');
  }

  db.dispose();
}
