import 'package:intl/intl.dart';

/// Money formatting utilities.
///
/// Mirrors Expo's `utils/money.ts` — consistent currency display throughout
/// the app using Peruvian Soles (S/).
class MoneyUtils {
  /// Default locale for currency formatting.
  static const String _locale = 'es_PE';

  /// Formats [amount] as a currency string with the PEN symbol.
  ///
  /// Examples:
  /// - `1500` → `S/ 1,500.00`
  /// - `0` → `S/ 0.00`
  /// - `99.5` → `S/ 99.50`
  static String format(num amount, {int decimalDigits = 2}) {
    final formatter = NumberFormat.currency(
      locale: _locale,
      symbol: 'S/ ',
      decimalDigits: decimalDigits,
    );
    return formatter.format(amount);
  }

  /// Formats [amount] without decimal digits (for whole-number prices).
  ///
  /// Example: `1500` → `S/ 1,500`
  static String formatWhole(num amount) {
    return format(amount, decimalDigits: 0);
  }

  /// Formats [amount] as a compact string (for dashboard cards).
  ///
  /// Examples:
  /// - `1500` → `S/ 1.5K`
  /// - `2500000` → `S/ 2.5M`
  static String formatCompact(num amount) {
    if (amount >= 1000000) {
      return 'S/ ${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return 'S/ ${(amount / 1000).toStringAsFixed(1)}K';
    }
    return format(amount);
  }

  /// Returns the percentage string for a ratio.
  ///
  /// Example: `0.15` → `15%`
  static String percent(num ratio) {
    return '${(ratio * 100).toStringAsFixed(0)}%';
  }

  /// Formats [amount] with an optional prefix for positive/negative values.
  ///
  /// Examples:
  /// - `+1500` → `+ S/ 1,500.00`
  /// - `-500` → `- S/ 500.00`
  static String formatSigned(num amount) {
    final prefix = amount >= 0 ? '+ ' : '- ';
    return '$prefix${format(amount.abs())}';
  }

  /// Safely parses a dynamic value to a double, returning 0 on failure.
  static double parseSafe(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.,-]'), '').replaceAll(',', '');
      return double.tryParse(cleaned) ?? 0;
    }
    return 0;
  }
}
