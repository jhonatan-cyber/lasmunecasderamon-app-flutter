import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/currency_text.dart';

class ClientSummaryBanner extends StatelessWidget {
  final double totalSaldo;
  final double totalDeuda;

  const ClientSummaryBanner({
    super.key,
    required this.totalSaldo,
    required this.totalDeuda,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOTAL SALDO', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.green)),
                    Text(formatCurrency(totalSaldo), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.green)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 16, color: Colors.redAccent),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOTAL DEUDA', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    Text(formatCurrency(totalDeuda), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.redAccent)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
