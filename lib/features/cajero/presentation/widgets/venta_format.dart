import 'package:intl/intl.dart';

/// Formatea `fecha_crea` (ISO) como 'dd MMM, HH:mm' en locale es_CL;
/// si no parsea, devuelve el string tal cual.
String formatVentaDateTime(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return 'Sin fecha';
  try {
    final parsed = DateTime.parse(dateStr).toLocal();
    final formatter = DateFormat('dd MMM, HH:mm', 'es_CL');
    return formatter.format(parsed);
  } catch (_) {
    return dateStr;
  }
}
