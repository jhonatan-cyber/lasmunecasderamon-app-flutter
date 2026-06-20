import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';


class ServicioFinalizarDialog extends StatelessWidget {
  final bool isDark;
  final String roomName;
  final VoidCallback onConfirm;

  const ServicioFinalizarDialog({
    super.key,
    required this.isDark,
    required this.roomName,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
      title: Text('Finalizar Servicio', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      content: Text(
        '¿Deseas finalizar el servicio de la habitación/mesa $roomName? Esto parará el reloj y liberará a la anfitriona.',
        style: GoogleFonts.inter(
          fontSize: 13,
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar', style: GoogleFonts.inter(
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          )),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            onConfirm();
            Navigator.pop(context);
          },
          child: Text('Finalizar Servicio', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
