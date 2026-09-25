import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/currency_text.dart';
import '../../../core/widgets/premium_header.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../cajero/data/servicios_notifier.dart';

/// Servicios de privados del rol Barman: mismo notifier que el cajero
/// (`GET /servicios/user` vía `serviciosListProvider`), espejo de
/// `app/(app)/barman/servicios.tsx` de la app Expo.
class BarmanServiciosScreen extends ConsumerStatefulWidget {
  const BarmanServiciosScreen({super.key});

  @override
  ConsumerState<BarmanServiciosScreen> createState() =>
      _BarmanServiciosScreenState();
}

class _BarmanServiciosScreenState extends ConsumerState<BarmanServiciosScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(serviciosListProvider.notifier).fetchServicios(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final state = ref.watch(serviciosListProvider);
    final servicios = state.servicios;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(serviciosListProvider.notifier).fetchServicios(),
        color: accent,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PremiumHeader(
                title: 'Servicios',
                subtitle: '${servicios.length} servicios del usuario',
              ),
            ),
            state.isLoading && servicios.isEmpty
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: SkeletonLoader(width: 400, height: 120),
                    ),
                  )
                : servicios.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.hotel_outlined,
                                  size: 48,
                                  color: _textSecondary(isDark)),
                              const SizedBox(height: 10),
                              Text('Sin servicios asignados',
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _textSecondary(isDark))),
                            ],
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverList.separated(
                          itemCount: servicios.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final s = servicios[index] as Map;
                            final estado =
                                int.tryParse('${s['estado'] ?? 0}') ?? 0;
                            final activo = estado == 2;
                            final codigo =
                                '${s['codigo'] ?? s['id_servicio'] ?? ''}';
                            final total =
                                double.tryParse('${s['total'] ?? 0}') ?? 0;
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTheme.darkSurfaceColor
                                    : AppTheme.lightSurfaceColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: activo
                                      ? accent.withValues(alpha: 0.5)
                                      : isDark
                                          ? AppTheme.darkBorderColor
                                          : AppTheme.lightBorderColor,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (activo
                                              ? accent
                                              : _textSecondary(isDark))
                                          .withValues(alpha: 0.12),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.hotel_rounded,
                                        color: activo
                                            ? accent
                                            : _textSecondary(isDark),
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
                                            '${s['habitacion_nombre'] ?? s['habitacion'] ?? ''} · ${activo ? 'en curso' : 'finalizado'}',
                                            style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: _textSecondary(
                                                    isDark))),
                                      ],
                                    ),
                                  ),
                                  Text(formatCurrency(total),
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

  static Color _textSecondary(bool isDark) => isDark
      ? AppTheme.darkTextSecondary
      : AppTheme.lightTextSecondary;
}
