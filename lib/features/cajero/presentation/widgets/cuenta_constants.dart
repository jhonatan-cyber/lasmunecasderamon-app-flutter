import 'package:intl/intl.dart';


String formatCurrency(double amount) {
  final formatter = NumberFormat.currency(
    locale: 'es_CL',
    symbol: r'$',
    decimalDigits: 0,
  );
  return formatter.format(amount);
}


String formatElapsedTime(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '00:00:00';
  try {
    final parsed = DateTime.parse(dateStr).toLocal();
    final diff = DateTime.now().difference(parsed);
    if (diff.isNegative) return '00:00:00';
    final hours = diff.inHours.toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  } catch (_) {
    return '00:00:00';
  }
}
