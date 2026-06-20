import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';

class GratificacionFilterChips extends StatelessWidget {
  final String activeFilter;
  final ValueChanged<String> onFilterChanged;

  const GratificacionFilterChips({
    super.key,
    required this.activeFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(context, 'Todos', 'todos'),
          const SizedBox(width: 8),
          _chip(context, 'Pendiente', 'pendiente'),
          const SizedBox(width: 8),
          _chip(context, 'Por pagar', 'por_pagar'),
          const SizedBox(width: 8),
          _chip(context, 'Pagado', 'pagado'),
          const SizedBox(width: 8),
          _chip(context, 'Rechazada', 'rechazada'),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String text, String value) {
    final isSelected = activeFilter == value;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Theme.of(context).colorScheme.primary : AppTheme.darkSurfaceColor,
        foregroundColor: isSelected ? Colors.white : AppTheme.darkTextSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9999),
          side: BorderSide(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white10),
        ),
      ),
      onPressed: () => onFilterChanged(value),
      child: Text(text, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
