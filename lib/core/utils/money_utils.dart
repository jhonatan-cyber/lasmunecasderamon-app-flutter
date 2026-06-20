import 'package:intl/intl.dart';





class MoneyUtils {
  
  static const String _locale = 'es_PE';

  
  
  
  
  
  
  static String format(num amount, {int decimalDigits = 2}) {
    final formatter = NumberFormat.currency(
      locale: _locale,
      symbol: 'S/ ',
      decimalDigits: decimalDigits,
    );
    return formatter.format(amount);
  }

  
  
  
  static String formatWhole(num amount) {
    return format(amount, decimalDigits: 0);
  }

  
  
  
  
  
  static String formatCompact(num amount) {
    if (amount >= 1000000) {
      return 'S/ ${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return 'S/ ${(amount / 1000).toStringAsFixed(1)}K';
    }
    return format(amount);
  }

  
  
  
  static String percent(num ratio) {
    return '${(ratio * 100).toStringAsFixed(0)}%';
  }

  
  
  
  
  
  static String formatSigned(num amount) {
    final prefix = amount >= 0 ? '+ ' : '- ';
    return '$prefix${format(amount.abs())}';
  }

  
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
