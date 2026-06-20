import 'package:flutter/material.dart';
import '../../data/solicitud_item.dart';


Color solicitudTypeColor(SolicitudItem item, BuildContext context) {
  if (item.tipoItem == 'solicitud') {
    return Theme.of(context).colorScheme.primary;
  } else if (item.tipoItem == 'anticipo') {
    return Colors.green;
  }
  return Colors.amber; 
}


IconData solicitudTypeIcon(SolicitudItem item) {
  switch (item.tipoItem) {
    case 'solicitud':
      return Icons.restaurant_menu_rounded;
    case 'anticipo':
      return Icons.payments_rounded;
    default:
      return Icons.local_bar_rounded;
  }
}


String solicitudTypeLabel(SolicitudItem item) {
  switch (item.tipoItem) {
    case 'solicitud':
      return 'Servicio';
    case 'anticipo':
      return 'Anticipo';
    default:
      return 'Trago / Pedido';
  }
}


String solicitudPlaceLabel(SolicitudItem item) {
  if (item.tipoItem == 'solicitud') {
    return 'Hab: ${item.roomName}';
  } else if (item.tipoItem == 'anticipo') {
    return 'Caja / Desembolso';
  }
  return 'Mesa: ${item.roomName}';
}


String solicitudRequestByLabel(SolicitudItem item) {
  if (item.tipoItem == 'solicitud') {
    return 'Anfitriona: ${item.solicitadoPor}';
  } else if (item.tipoItem == 'anticipo') {
    return 'Para: ${item.solicitadoPor}';
  }
  return 'Garzón: ${item.solicitadoPor}';
}


String formatElapsedTime(DateTime dateTime) {
  final elapsedMinutes = DateTime.now().difference(dateTime).inMinutes;
  if (elapsedMinutes < 1) return 'Ahora';
  if (elapsedMinutes < 60) return '$elapsedMinutes min';
  final hours = elapsedMinutes ~/ 60;
  final mins = elapsedMinutes % 60;
  return '${hours}h ${mins}m';
}
