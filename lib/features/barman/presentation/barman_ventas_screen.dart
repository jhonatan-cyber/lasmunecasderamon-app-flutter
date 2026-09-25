import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/currency_text.dart';
import '../../../core/widgets/premium_header.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../cajero/data/ventas_notifier.dart';

/// Ventas del bar (rol Barman): misma lista que el cajero (`ventasListProvider`,
/// `GET /sales?limit=50`), filtrada visualmente al día; espejo de
/// `app/(app)/barman/ventas.tsx` de la app Expo.
class BarmanVentasScreen extends ConsumerStatefulWidget {
  const BarmanVentasScreen({super.key});

  @override
  ConsumerState<BarmanVentasScreen> createState() =>
      _BarmanVentasScreenState();
}

class _BarmanVentasScreenState extends ConsumerState<BarmanVentasScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(ventasListProvider.notifier).fetchData(),
    );
  }

  List<dynamic> get _ventasHoy {
    final ventas = ref.read(ventasListProvider).ventas;
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return ventas.where((v) {
      if (v is! Map) return false;
      final fecha = '${v['fecha_crea'] ?? v['fecha'] ?? ''}'
          .split('T')
          .first
          .split(' ')
          .first;
      // Sin fecha confiable se muestra igual (comportamiento tolerante).
      return fecha.isEmpty || fecha == hoy;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final ventasState = ref.watch(ventasListProvider);
    final ventas = _ventasHoy;

    final total = ventas.fold<double>(0.0, (acc, v) {
      if (v is! Map) return acc;
      return acc + (double.tryParse('${v['total'] ?? 0}') ?? 0);
    });

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(ventasListProvider.notifier).fetchData(),
        color: accent,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PremiumHeader(
                title: 'Ventas del Bar',
                subtitle: '${ventas.length} ventas · ${formatCurrency(total)}',
              ),
            ),
            ventasState.isLoading && ventas.isEmpty
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: SkeletonLoader(width: 400, height: 120),
                    ),
                  )
                : ventas.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shopping_cart_outlined,
                                  size: 48, color: textSecondary(isDark)),
                              const SizedBox(height: 10),
                              Text('Sin ventas registradas hoy',
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: textSecondary(isDark))),
                            ],
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverList.separated(
                          itemCount: ventas.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final v = ventas[index] as Map;
                            final codigo =
                                '${v['codigo'] ?? v['id_venta'] ?? ''}';
                            final totalVenta =
                                double.tryParse('${v['total'] ?? 0}') ?? 0;
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTheme.darkSurfaceColor
                                    : AppTheme.lightSurfaceColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? AppTheme.darkBorderColor
                                      : AppTheme.lightBorderColor,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color:
                                          accent.withValues(alpha: 0.12),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                        Icons.shopping_cart_rounded,
                                        color: accent,
                                        size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(codigo,
                                            style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight:
                                                    FontWeight.bold)),
                                        Text(
                                            '${v['metodo_pago'] ?? 'Venta'} · ${v['usuario_nick'] ?? ''}',
                                            style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: textSecondary(
                                                    isDark))),
                                      ],
                                    ),
                                  ),
                                  Text(formatCurrency(totalVenta),
                                      style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ],
        ),
      ),
    );
  }

  static Color textSecondary(bool isDark) => isDark
      ? AppTheme.darkTextSecondary
      : AppTheme.lightTextSecondary;
}
