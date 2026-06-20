import 'package:intl/intl.dart';


String formatCurrency(double amount) {
  final format = NumberFormat.currency(
    locale: 'es_CL',
    symbol: r'$',
    decimalDigits: 0,
  );
  return format.format(amount);
}


String formatDateTime(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return 'Sin fecha';
  try {
    final parsed = DateTime.parse(dateStr).toLocal();
    final formatter = DateFormat('dd MMM, HH:mm', 'es_CL');
    return formatter.format(parsed);
  } catch (_) {
    return dateStr;
  }
}
