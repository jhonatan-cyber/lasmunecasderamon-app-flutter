import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/hooks/set_state_provider.dart';
import '../../../core/refresh_bus.dart';
import '../../../core/theme.dart';
import '../../../core/timer_service.dart';
import '../../../core/widgets/premium_fab.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/currency_text.dart';
import '../../../core/widgets/premium_header.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../data/ventas_notifier.dart';
import 'widgets/venta_action_sheet.dart';
import 'widgets/venta_anulacion_modal.dart';
import 'widgets/venta_card.dart';
import 'widgets/venta_confirm_dialog.dart';
import 'widgets/venta_detail_modal.dart';

class VentasScreen extends ConsumerStatefulWidget {
  const VentasScreen({super.key});

  @override
  ConsumerState<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends ConsumerState<VentasScreen> {
  String _activeTab = 'historial';
  StreamSubscription<RefreshChannel>? _refreshSub;
  dynamic _activeVenta;

  String _montoAnulacion = '';

  final _motivoController = TextEditingController();
  final _montoAnulacionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(ventasListProvider.notifier).fetchData(),
    );
    _refreshSub = RefreshBus.stream.listen((channel) {
      if (channel == RefreshChannel.sales) {
        ref.read(ventasListProvider.notifier).fetchData();
      }
    });
  }

  @override
  void dispose() {
    _refreshSub?.cancel();
    _motivoController.dispose();
    _montoAnulacionController.dispose();
    super.dispose();
  }

  List<dynamic> get _filteredVentas {
    final state = ref.read(ventasListProvider);
    final timerState = ref.read(timerProvider);
    if (_activeTab == 'historial') {
      return state.ventas;
    }

    return state.ventas.where((v) {
      final estado = int.tryParse(v['estado']?.toString() ?? '1') ?? 1;
      if (estado == 2) return true;
      final ventaId = v['id_venta']?.toString() ?? '';
      return timerState.timers.any(
        (t) =>
            t.tipoTransaccion == 'venta' &&
            (t.servicioId == ventaId ||
                (t.roomId == (v['habitacion_id']?.toString() ?? '') &&
                    estado == 2)),
      );
    }).toList();
  }

  int get _activeTimerCount {
    final timerState = ref.read(timerProvider);
    return timerState.timers.where((t) => t.tipoTransaccion == 'venta').length;
  }

  void _showActionSheet(dynamic venta) {
    showVentaActionSheet(
      context,
      venta: venta,
      onVerDetalles: () => _showVentaDetailModal(venta),
      onFinalizar: () => _handleFinalizarVenta(venta),
      onAnular: () => _openAnulacionModal(venta),
    );
  }

  void _handleFinalizarVenta(dynamic venta) {
    showFinalizarVentaConfirm(
      context,
      onConfirm: () => _executeFinalizarVenta(venta),
    );
  }

  Future<void> _executeFinalizarVenta(dynamic venta) async {
    final ventaId = venta['id_venta']?.toString() ?? '';
    if (ventaId.isEmpty || ventaId == 'null') return;

    final ok = await ref.read(ventasListProvider.notifier).finalizarVenta(ventaId);
    if (!mounted) return;
    if (ok) {
      AppSnackBar.showSuccess(context, 'Venta finalizada con éxito');
      ref.read(timerProvider.notifier).fetchActiveTimers();
    } else {
      final error = ref.read(ventasListProvider).error;
      AppSnackBar.showError(
        context,
        error.isNotEmpty ? error : 'No se pudo finalizar la venta',
      );
    }
  }

  void _openAnulacionModal(dynamic venta) {
    final double total =
        double.tryParse(venta['total']?.toString() ?? '0') ?? 0.0;
    _motivoController.clear();
    setState(() {
      _activeVenta = venta;
      _montoAnulacion = NumberFormat.currency(
        locale: 'es_CL',
        symbol: '',
        decimalDigits: 0,
      ).format(total).trim();
      _montoAnulacionController.text = _montoAnulacion;
    });
    ref.read(setStateProvider('ventas').notifier).setFlag('anulacionModalVisible', true);
  }

  String _formatMontoInput(String value) {
    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return '';
    return NumberFormat.currency(
      locale: 'es_CL',
      symbol: '',
      decimalDigits: 0,
    ).format(int.parse(digits)).trim();
  }

  Future<void> _handleAnularVenta() async {
    if (_activeVenta == null) return;
    final ventaId = _activeVenta['id_venta']?.toString() ?? '';
    final monto =
        double.tryParse(_montoAnulacion.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    final motivo = _motivoController.text.trim();

    if (ventaId.isEmpty || ventaId == 'null') {
      AppSnackBar.showError(context, 'No se pudo identificar la venta');
      return;
    }
    if (monto <= 0) {
      AppSnackBar.showError(context, 'Debes ingresar un monto mayor a 0');
      return;
    }
    if (monto >
        (double.tryParse(_activeVenta['total']?.toString() ?? '0') ?? 0)) {
      AppSnackBar.showError(
        context,
        'El monto no puede ser mayor al total de la venta',
      );
      return;
    }
    if (motivo.isEmpty) {
      AppSnackBar.showError(
        context,
        'Debes ingresar el motivo de la anulación',
      );
      return;
    }

    final ok = await ref.read(ventasListProvider.notifier).anularVenta(ventaId, motivo, monto);
    if (!mounted) return;
    if (ok) {
      ref.read(setStateProvider('ventas').notifier).setFlag('anulacionModalVisible', false);
      AppSnackBar.showSuccess(
        context,
        'La anulación ha sido solicitada al administrador por WhatsApp',
      );
    } else {
      final error = ref.read(ventasListProvider).error;
      AppSnackBar.showError(
        context,
        error.isNotEmpty ? error : 'No se pudo solicitar la anulación',
      );
    }
  }

  Future<void> _showVentaDetailModal(dynamic ventaShort) async {
    final String ventaId = ventaShort['id_venta']?.toString() ?? '';
    if (ventaId.isEmpty || ventaId == 'null') return;

    ref.read(setStateProvider('ventas').notifier).setFlag('modalVisible', true);
    await ref.read(ventasListProvider.notifier).fetchDetail(ventaId);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timerState = ref.watch(timerProvider);
    final ventaState = ref.watch(ventasListProvider);

    final double totalVentas =
        double.tryParse(ventaState.resumen['total_ventas']?.toString() ?? '0') ?? 0.0;
    final int cantidadVentas =
        int.tryParse(ventaState.resumen['cantidad_ventas']?.toString() ?? '0') ?? 0;
    final int cantidadAnuladas =
        int.tryParse(ventaState.resumen['cantidad_anuladas']?.toString() ?? '0') ?? 0;

    final filteredList = _filteredVentas;

    final content = Scaffold(
      backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
      body: Column(
        children: [
          PremiumHeader(
            title: 'Ventas',
            showBackButton: true,
            onBack: () => context.pop(),
            showRefreshButton: true,
            isRefreshing: ventaState.isRefreshing,
            onRefresh: () => ref.read(ventasListProvider.notifier).fetchData(isManual: true),
          ),
          Expanded(
            child: FadeLoadingSwitcher(
              isLoading: ventaState.isLoading,
              skeleton: _buildSkeletonList(),
              content: RefreshIndicator(
                onRefresh: () => ref.read(ventasListProvider.notifier).fetchData(isManual: true),
                color: Theme.of(context).colorScheme.primary,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildTabButton(
                              isDark: isDark,
                              label: 'Historial',
                              isActive: _activeTab == 'historial',
                              onTap: () =>
                                  setState(() => _activeTab = 'historial'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTabButton(
                              isDark: isDark,
                              label: 'Ventas con Habitación',
                              isActive: _activeTab == 'proceso',
                              badge: _activeTimerCount > 0
                                  ? _activeTimerCount
                                  : null,
                              onTap: () =>
                                  setState(() => _activeTab = 'proceso'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_activeTab == 'historial')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildMiniStat(
                                isDark: isDark,
                                label: 'TOTAL HOY',
                                value: formatCurrency(totalVentas),
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMiniStat(
                                isDark: isDark,
                                label: 'CANTIDAD',
                                value: '$cantidadVentas',
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMiniStat(
                                isDark: isDark,
                                label: 'ANULADAS',
                                value: '$cantidadAnuladas',
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),

                    Expanded(
                      child: filteredList.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_rounded,
                                    size: 48,
                                    color: isDark
                                        ? AppTheme.darkBorderColor
                                        : AppTheme.lightBorderColor,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _activeTab == 'historial'
                                        ? 'No hay ventas directas hoy'
                                        : 'No hay ventas con habitación activas',
                                    style: GoogleFonts.inter(
                                      color: isDark
                                          ? AppTheme.darkTextSecondary
                                          : AppTheme.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              itemCount: filteredList.length,
                              itemBuilder: (context, index) {
                                final venta = filteredList[index];
                                return VentaCard(
                                  venta: venta,
                                  isDark: isDark,
                                  timerState: timerState,
                                  onTap: () => _showActionSheet(venta),
                                  onFinalizar: () =>
                                      _handleFinalizarVenta(venta),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: PremiumFAB(
        label: _activeTab == 'historial' ? 'NUEVA VENTA' : 'NUEVO SERVICIO',
        icon: Icon(
          _activeTab == 'historial'
              ? Icons.shopping_cart_outlined
              : Icons.add,
          color: Colors.white,
        ),
        onPressed: () => context.push(
          _activeTab == 'historial'
              ? '/cajero/ventas/nueva'
              : '/cajero/servicios/nuevo',
        ),
      ),
    );

    return Stack(
      children: [
        content,
        if (ref.watch(setStateProvider('ventas')).flags['modalVisible'] ?? false)
          VentaDetailModal(
            loadingDetail: ventaState.loadingDetail,
            selectedVenta: ventaState.selectedVenta,
            onDismiss: () {
              ref.read(ventasListProvider.notifier).clearSelectedVenta();
              ref.read(setStateProvider('ventas').notifier).setFlag('modalVisible', false);
            },
            onClose: () => ref
                .read(setStateProvider('ventas').notifier)
                .setFlag('modalVisible', false),
          ),
        if (ref.watch(setStateProvider('ventas')).flags['anulacionModalVisible'] ?? false)
          VentaAnulacionModal(
            activeVenta: _activeVenta,
            anulandoVenta: ventaState.anulandoVenta,
            motivoController: _motivoController,
            montoController: _montoAnulacionController,
            onMontoChanged: (v) => _montoAnulacion = _formatMontoInput(v),
            onSubmit: _handleAnularVenta,
            onCancel: () => ref
                .read(setStateProvider('ventas').notifier)
                .setFlag('anulacionModalVisible', false),
          ),
      ],
    );
  }

  Widget _buildTabButton({
    required bool isDark,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    int? badge,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: isActive
              ? null
              : Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.redAccent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$badge',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? Colors.white
                    : (isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat({
    required bool isDark,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ShimmerWrapper(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: SkeletonCard(lines: 4),
        ),
      ),
    );
  }
}
