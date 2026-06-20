import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/currency_text.dart';
import '../../domain/client_model.dart';

class ClientCard extends StatelessWidget {
  final Client client;
  final VoidCallback? onViewHistory;
  final VoidCallback? onChargeBalance;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ClientCard({
    super.key,
    required this.client,
    this.onViewHistory,
    this.onChargeBalance,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 4,
      color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onViewHistory,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.fullName,
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    _infoRow(context, Icons.card_membership_outlined, client.run.isNotEmpty ? client.run : 'Sin RUN'),
                    const SizedBox(height: 2),
                    _infoRow(context, Icons.phone_android_outlined, client.phone.isNotEmpty ? client.phone : 'Sin Teléfono'),
                    const Spacer(),
                    _saldoPill(isDark, client.saldo),
                    const SizedBox(height: 4),
                    _deudaPill(isDark, client.deuda),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 1,
                height: double.infinity,
                color: Colors.grey.withValues(alpha: 0.1),
              ),
              const SizedBox(width: 8),
              _actionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.grey),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _saldoPill(bool isDark, double saldo) {
    final hasSaldo = saldo > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hasSaldo ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wallet_rounded, size: 12, color: hasSaldo ? Colors.green : Colors.grey),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SALDO', style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.bold, color: hasSaldo ? Colors.green : Colors.grey)),
              Text(formatCurrency(saldo), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: hasSaldo ? Colors.green : (isDark ? Colors.white : Colors.black))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _deudaPill(bool isDark, double deuda) {
    final hasDeuda = deuda > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hasDeuda ? Colors.redAccent.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 12, color: hasDeuda ? Colors.redAccent : Colors.grey),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DEUDA', style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.bold, color: hasDeuda ? Colors.redAccent : Colors.grey)),
              Text(formatCurrency(deuda), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: hasDeuda ? Colors.redAccent : (isDark ? Colors.white : Colors.black))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _actionIcon(Icons.visibility_outlined, Colors.purple, onViewHistory),
        const SizedBox(height: 6),
        _actionIcon(Icons.account_balance_wallet_rounded, Colors.green, onChargeBalance, filled: true),
        const SizedBox(height: 6),
        _actionIcon(Icons.edit_outlined, Colors.blue, onEdit),
        const SizedBox(height: 6),
        _actionIcon(Icons.delete_outline_rounded, Colors.redAccent, onDelete),
      ],
    );
  }

  Widget _actionIcon(IconData icon, Color color, VoidCallback? onTap, {bool filled = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: filled ? Colors.white : color),
      ),
    );
  }
}
