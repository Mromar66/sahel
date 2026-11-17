import 'package:inventory_app/core/services/database_service.dart';

/// Persistent defaults shared by the invoice and inventory operation screens.
class ShopPreferences {
  ShopPreferences._();

  static final _db = DatabaseService().database.db;

  static String _read(String key, String fallback) {
    final rows = _db.select('SELECT value FROM settings WHERE key=?', [key]);
    return rows.isEmpty ? fallback : rows.first['value'] as String;
  }

  static bool get confirmDelete => _read('settings.confirm_delete', '1') != '0';

  static int get defaultTaxPercent => defaultSaleTaxPercent;

  static int _taxPercent(String side) {
    var total = 0;
    var configured = false;
    for (var index = 1; index <= 2; index++) {
      if (_read('settings.tax_${index}_$side', '0') != '1') continue;
      configured = true;
      final value =
          int.tryParse(_read('settings.tax_${index}_percent', '0')) ?? 0;
      total += value.clamp(0, 100);
    }
    if (configured) return total.clamp(0, 100);
    final fallback =
        int.tryParse(_read('settings.tax_default_percent', '0')) ?? 0;
    return fallback.clamp(0, 100);
  }

  static int get defaultSaleTaxPercent => _taxPercent('sale');
  static int get defaultPurchaseTaxPercent => _taxPercent('purchase');

  static int get roundStep {
    final value = int.tryParse(_read('settings.round_step', '5')) ?? 5;
    return const [1, 5, 10, 25].contains(value) ? value : 5;
  }

  static void save({bool? confirmDelete, int? roundStep}) {
    final now = DateTime.now().toIso8601String();
    _db.execute('BEGIN IMMEDIATE');
    try {
      for (final entry in <String, String>{
        if (confirmDelete != null)
          'settings.confirm_delete': confirmDelete ? '1' : '0',
        if (roundStep != null) 'settings.round_step': '$roundStep',
      }.entries) {
        _db.execute(
          'INSERT INTO settings(key,value,description,updated_at) VALUES(?,?,?,?) '
          'ON CONFLICT(key) DO UPDATE SET value=excluded.value,updated_at=excluded.updated_at',
          [entry.key, entry.value, 'Shop operation preference', now],
        );
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }
}
