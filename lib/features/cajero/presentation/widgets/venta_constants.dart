import 'package:flutter/material.dart';
import 'package:intl/intl.dart';





Color statusColor(int estado) {
  switch (estado) {
    case 2:
      return Colors.orange;
    case 3:
    case 0:
      return Colors.redAccent;
    default:
      return Colors.green;
  }
}

String statusLabel(int estado) {
  switch (estado) {
    case 2:
      return 'En proceso';
    case 3:
      return 'Pdte. Anulación';
    case 0:
      return 'Anulada';
    default:
      return 'Completado';
  }
}





IconData payMethodIcon(String method) {
  switch (method.toUpperCase()) {
    case 'TARJETA':
      return Icons.credit_card_rounded;
    case 'TRANSFERENCIA':
    case 'TRANSFER':
      return Icons.account_balance_rounded;
    case 'CHEQUE':
      return Icons.receipt_long_rounded;
    default:
      return Icons.money_rounded;
  }
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


String formatMontoInput(String value) {
  final digits = value.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return '';
  return NumberFormat.currency(
    locale: 'es_CL',
    symbol: '',
    decimalDigits: 0,
  ).format(int.parse(digits)).trim();
}


double parseMontoInput(String value) {
  return double.tryParse(value.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
}
