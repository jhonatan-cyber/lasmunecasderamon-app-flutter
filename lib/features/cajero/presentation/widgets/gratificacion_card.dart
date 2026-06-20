import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/currency_text.dart';
import '../../domain/gratificacion_model.dart';

class GratificacionCard extends StatelessWidget {
  final GratificacionItem item;
  final int index;

  const GratificacionCard({super.key, required this.item, required this.index});

  Color get _estadoColor {
    switch (item.estado) {
      case 0: return Colors.green;
      case 1: return Colors.blue;
      case 2: return Colors.orange;
      case 3: return Colors.red;
      default: return Colors.grey;
    }
  }

  String get _estadoLabel => item.estado.gratLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle),
                child: Center(child: Text('${index + 1}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _estadoColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(9999)),
                child: Text(_estadoLabel, style: GoogleFonts.inter(fontSize: 10, color: _estadoColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(item.usuario, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(formatCurrency(item.monto), style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 6),
          Text(item.descripcion.isNotEmpty ? item.descripcion : 'Sin descripción', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.darkTextSecondary)),
          const Divider(color: Colors.white10, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('dd/MM/yyyy').format(item.fechaCrea), style: GoogleFonts.inter(fontSize: 10, color: AppTheme.darkTextSecondary, fontWeight: FontWeight.bold)),
              Text(
                (item.estadoTexto ?? _estadoLabel).replaceAll('_', ' ').toUpperCase(),
                style: GoogleFonts.inter(fontSize: 10, color: AppTheme.darkTextSecondary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
