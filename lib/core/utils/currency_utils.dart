import 'package:intl/intl.dart';
import 'package:inventory_app/core/services/database_service.dart';

/// Utility class for currency formatting and integer-based monetary storage.
class CurrencyUtils {
  CurrencyUtils._();

  static String? _cachedSymbol;

  static String get currentSymbol {
    final cached = _cachedSymbol;
    if (cached != null) return cached;
    try {
      final rows = DatabaseService().database.db.select(
        'SELECT value FROM settings WHERE key=?',
        ['settings.currency_symbol'],
      );
      _cachedSymbol =
          rows.isNotEmpty && (rows.first['value'] as String).isNotEmpty
          ? rows.first['value'] as String
          : 'ج.م';
    } catch (_) {
      _cachedSymbol = 'ج.م';
    }
    return _cachedSymbol!;
  }

  static void updateSymbol(String value) {
    _cachedSymbol = value.trim().isEmpty ? 'ج.م' : value.trim();
  }

  /// Format an integer amount (stored as smallest currency unit) to display string.
  static String format(int amount, {String? symbol, int decimalPlaces = 2}) {
    // amount is in smallest unit (e.g., piastres for EGP)
    final double displayAmount = amount / 100;
    return NumberFormat.currency(
      locale: 'ar_EG',
      symbol: symbol ?? currentSymbol,
      decimalDigits: decimalPlaces,
    ).format(displayAmount);
  }

  /// Convert a display amount to integer storage (multiply by 100).
  static int toStorage(double amount) {
    return (amount * 100).round();
  }

  /// Convert stored integer amount to display double.
  static double fromStorage(int amount) {
    return amount / 100;
  }
}
