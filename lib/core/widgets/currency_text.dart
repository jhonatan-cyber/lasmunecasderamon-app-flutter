import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Formats a double value as Chilean peso currency string.
String formatCurrency(double amount) {
  final formatter = NumberFormat.currency(
    locale: 'es_CL',
    symbol: r'$',
    decimalDigits: 0,
  );
  return formatter.format(amount);
}

/// A styled currency text widget with consistent typography.
class CurrencyText extends StatelessWidget {
  final double amount;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final bool showSign;
  final bool isPositive;

  const CurrencyText({
    super.key,
    required this.amount,
    this.fontSize,
    this.fontWeight,
    this.color,
    this.showSign = false,
    this.isPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor = color ??
        (showSign
            ? (isPositive ? Colors.green : Colors.redAccent)
            : null);
    final prefix = showSign ? (isPositive ? '+' : '-') : '';

    return Text(
      '$prefix${formatCurrency(amount)}',
      style: GoogleFonts.inter(
        fontSize: fontSize ?? 14,
        fontWeight: fontWeight ?? FontWeight.bold,
        color: displayColor,
      ),
    );
  }
}

/// A currency display with label and colored background pill.
class CurrencyPill extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool compact;

  const CurrencyPill({
    super.key,
    required this.label,
    required this.amount,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 6 : 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: compact ? 7 : 8,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatCurrency(amount),
            style: GoogleFonts.inter(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
