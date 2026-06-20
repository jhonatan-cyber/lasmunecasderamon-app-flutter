import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ClientPaymentMethodSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final bool showMixto;

  const ClientPaymentMethodSelector({
    super.key,
    required this.selected,
    required this.onSelect,
    this.showMixto = false,
  });

  @override
  Widget build(BuildContext context) {
    final methods = [
      {'id': 'efectivo', 'label': 'Efectivo', 'icon': Icons.money_rounded},
      {'id': 'tarjeta', 'label': 'Tarjeta', 'icon': Icons.credit_card_rounded},
      {'id': 'transferencia', 'label': 'Transferencia', 'icon': Icons.swap_horiz_rounded},
      if (showMixto) {'id': 'mixto', 'label': 'Mixto', 'icon': Icons.shuffle_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MÉTODO DE PAGO',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        Row(
          children: methods.map((m) {
            final isSelected = selected == m['id'];
            return Expanded(
              child: GestureDetector(
                onTap: () => onSelect(m['id'] as String),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(m['icon'] as IconData, size: 18, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey),
                      const SizedBox(height: 4),
                      Text(
                        m['label'] as String,
                        style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
