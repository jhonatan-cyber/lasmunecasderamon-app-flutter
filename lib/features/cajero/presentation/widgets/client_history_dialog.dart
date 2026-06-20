import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/currency_text.dart';
import '../../domain/client_model.dart';

class ClientHistoryDialog extends ConsumerWidget {
  final Client client;
  final List<ClientHistory> items;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  const ClientHistoryDialog({
    super.key,
    required this.client,
    required this.items,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double totalServicios = items.where((i) => i.category == 'SERVICIO').fold(0.0, (sum, i) => sum + i.monto);
    final double totalConsumo = items.where((i) => i.category == 'CONSUMO').fold(0.0, (sum, i) => sum + i.monto);
    final double totalCargas = items.where((i) => i.category == 'CARGA').fold(0.0, (sum, i) => sum + i.monto);

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Historial de Cuenta', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text(client.fullName, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: 16),
              if (isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else ...[
                Row(
                  children: [
                    _summaryPill('Servicios', totalServicios, Colors.blue),
                    const SizedBox(width: 6),
                    _summaryPill('Consumo', totalConsumo, Colors.amber),
                    const SizedBox(width: 6),
                    _summaryPill('Cargado', totalCargas, Colors.green),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: RefreshIndicator(
                    color: Theme.of(context).colorScheme.primary,
                    onRefresh: onRefresh,
                    child: items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                                const SizedBox(height: 12),
                                Text('Sin movimientos', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.grey)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (context, idx) => _historyItem(context, isDark, items[idx]),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryPill(String label, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Text(formatCurrency(amount), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _historyItem(BuildContext context, bool isDark, ClientHistory item) {
    final isCarga = item.category == 'CARGA';
    final isServicio = item.category == 'SERVICIO';
    final color = isCarga ? Colors.green : isServicio ? Colors.blue : Colors.amber;
    final icon = isCarga ? Icons.arrow_upward_rounded : isServicio ? Icons.bed_rounded : Icons.shopping_cart_rounded;
    final label = isCarga ? 'Carga de Saldo' : isServicio ? 'Servicio' : 'Consumo';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.015),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(DateFormat('dd MMM yyyy, HH:mm').format(item.fechaCrea), style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('${isCarga ? '+' : '-'}${formatCurrency(item.monto)}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
              ),
            ],
          ),
          if (item.detalle != null) ...[
            const SizedBox(height: 10),
            _detailSection(context, isDark, item.category, item.detalle!),
          ],
          const SizedBox(height: 8),
          _metodoPagoBadge(isDark, item.metodoPago),
        ],
      ),
    );
  }

  Widget _detailSection(BuildContext context, bool isDark, String category, Map<String, dynamic> detalle) {
    if (category == 'SERVICIO') {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (detalle['habitacion'] != null) _smallDetail(Icons.bed_outlined, 'Habitación', detalle['habitacion'].toString()),
                if (detalle['tiempo'] != null) _smallDetail(Icons.timer_outlined, 'Duración', '${detalle['tiempo']} min'),
              ],
            ),
            if (detalle['anfitrionas'] is List && (detalle['anfitrionas'] as List).isNotEmpty) ...[
              const SizedBox(height: 8),
              _anfitrionasBadge(detalle['anfitrionas'] as List, Colors.blue),
            ],
          ],
        ),
      );
    }
    if (category == 'CONSUMO') {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (detalle['productos'] is List) ...[
              Row(
                children: [
                  const Icon(Icons.fastfood_outlined, size: 14, color: Colors.amber),
                  const SizedBox(width: 6),
                  Text('PRODUCTOS', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber)),
                ],
              ),
              const SizedBox(height: 6),
              ...(detalle['productos'] as List).map((p) {
                final qty = p['cantidad'] ?? 1;
                final name = p['nombre'] ?? 'Producto';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    children: [
                      Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('${qty}x $name', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }),
            ],
            if (detalle['anfitrionas'] is List && (detalle['anfitrionas'] as List).isNotEmpty) ...[
              const SizedBox(height: 8),
              _anfitrionasBadge(detalle['anfitrionas'] as List, Colors.amber),
            ],
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _smallDetail(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.blue),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.blue)),
            Text(value, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _anfitrionasBadge(List list, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.people_outline_rounded, size: 14, color: Colors.blue),
        const SizedBox(width: 6),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: list.map((n) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(n.toString(), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _metodoPagoBadge(bool isDark, String metodoPago) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            metodoPago == 'efectivo'
                ? Icons.payments_outlined
                : metodoPago == 'tarjeta'
                    ? Icons.credit_card_outlined
                    : metodoPago == 'transferencia'
                        ? Icons.swap_horiz_outlined
                        : metodoPago == 'prepago' ? Icons.account_balance_wallet_outlined : Icons.shuffle_outlined,
            size: 10,
            color: Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(metodoPago.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }
}
