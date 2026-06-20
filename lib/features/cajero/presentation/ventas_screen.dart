import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/hooks/set_state_provider.dart';
import '../../../core/theme.dart';
import '../../../core/timer_service.dart';
import '../../../core/widgets/premium_fab.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/currency_text.dart';
import '../../../core/widgets/premium_header.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../data/ventas_notifier.dart';

class VentasScreen extends ConsumerStatefulWidget {
  const VentasScreen({super.key});

  @override
  ConsumerState<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends ConsumerState<VentasScreen> {
  String _activeTab = 'historial'; 
  Timer? _tickTimer;
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
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _motivoController.dispose();
    _montoAnulacionController.dispose();
    _tickTimer?.cancel();
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

  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Sin fecha';
    try {
      final parsed = DateTime.parse(dateStr).toLocal();
      final formatter = DateFormat('dd MMM, HH:mm', 'es_CL');
      return formatter.format(parsed);
    } catch (_) {
      return dateStr;
    }
  }

  
  void _showActionSheet(dynamic venta) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int estado = int.tryParse(venta['estado']?.toString() ?? '1') ?? 1;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.darkSurfaceColor
                : AppTheme.lightSurfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark
                  ? AppTheme.darkBorderColor
                  : AppTheme.lightBorderColor,
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Opciones de Venta',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Código: ${venta['codigo'] ?? venta['id_venta'] ?? ''}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.visibility_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Ver Detalles',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showVentaDetailModal(venta);
                },
              ),
              if (estado == 2 || estado == 3)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.stop_circle_outlined,
                      color: Colors.green,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Finalizar Venta',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleFinalizarVenta(venta);
                  },
                ),
              if (estado != 0 && estado != 3)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.cancel_outlined,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Solicitar Anulación',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openAnulacionModal(venta);
                  },
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  
  void _handleFinalizarVenta(dynamic venta) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark
            ? AppTheme.darkSurfaceColor
            : AppTheme.lightSurfaceColor,
        title: Text(
          'Finalizar Venta',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Estás seguro de que deseas finalizar esta venta? Esto liberará la habitación y detendrá el temporizador.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: isDark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: GoogleFonts.inter(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _executeFinalizarVenta(venta);
            },
            child: Text(
              'Finalizar',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeFinalizarVenta(dynamic venta) async {
    final ventaId = int.tryParse(venta['id_venta']?.toString() ?? '') ?? 0;
    if (ventaId == 0) return;

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
    final ventaId =
        int.tryParse(_activeVenta['id_venta']?.toString() ?? '') ?? 0;
    final monto =
        double.tryParse(_montoAnulacion.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    final motivo = _motivoController.text.trim();

    if (ventaId == 0) {
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
    final int ventaId =
        int.tryParse(ventaShort['id_venta']?.toString() ?? '') ?? 0;
    if (ventaId == 0) return;

    ref.read(setStateProvider('ventas').notifier).setFlag('modalVisible', true);
    await ref.read(ventasListProvider.notifier).fetchDetail(ventaId);
    if (mounted) setState(() {});
  }

  Widget _buildDetailModal(bool isDark) {
    final v = ref.read(ventasListProvider);
    return GestureDetector(
      onTap: () {          ref.read(ventasListProvider.notifier).clearSelectedVenta();
        ref.read(setStateProvider('ventas').notifier).setFlag('modalVisible', false);
      },
      child: Container(
        color: Colors.black54,
        child: GestureDetector(
          onTap: () {},
          child: DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkSurfaceColor
                      : AppTheme.lightSurfaceColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.darkBorderColor
                        : AppTheme.lightBorderColor,
                  ),
                ),
                child: v.loadingDetail
                    ? Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : v.selectedVenta != null
                    ? _buildDetailContent(scrollController, isDark)
                    : const Center(child: Text('Error al cargar detalle')),
              );
            },
          ),
        ),
      ),
    );
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
                                return _buildVentaCard(
                                  filteredList[index],
                                  isDark,
                                  timerState,
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
        if (ref.watch(setStateProvider('ventas')).flags['modalVisible'] ?? false) _buildDetailModal(isDark),
        if (ref.watch(setStateProvider('ventas')).flags['anulacionModalVisible'] ?? false) _buildAnulacionModal(isDark),
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

  Widget _buildVentaCard(dynamic venta, bool isDark, TimerState timerState) {
    final int estado = int.tryParse(venta['estado']?.toString() ?? '1') ?? 1;
    final double total =
        double.tryParse(venta['total']?.toString() ?? '0') ?? 0.0;
    final method = venta['metodo_pago']?.toString().toUpperCase() ?? 'EFECTIVO';
    final ventaId = venta['id_venta']?.toString() ?? '';
    final isProceso = estado == 2;

    
    ActiveTimer? activeTimer;
    try {
      activeTimer = timerState.timers.firstWhere(
        (t) => t.tipoTransaccion == 'venta' && t.servicioId == ventaId,
      );
    } catch (_) {}

    
    Color statusColor;
    String statusLabel;
    switch (estado) {
      case 2:
        statusColor = Colors.orange;
        statusLabel = 'En proceso';
        break;
      case 3:
        statusColor = Colors.redAccent;
        statusLabel = 'Pdte. Anulación';
        break;
      case 0:
        statusColor = Colors.redAccent;
        statusLabel = 'Anulada';
        break;
      default:
        statusColor = Colors.green;
        statusLabel = 'Completado';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
        ),
        
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showActionSheet(venta),
        child: IntrinsicHeight(
          child: Row(
            children: [
              
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(20),
                  ),
                ),
              ),
              
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Venta #${venta['id_venta']}',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isProceso)
                            SizedBox(
                              height: 32,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.stop_circle_outlined,
                                  size: 14,
                                ),
                                label: Text(
                                  'Finalizar',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () => _handleFinalizarVenta(venta),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.person_outline_rounded,
                        venta['cliente_nombre'] ?? 'Cliente General',
                        isDark,
                      ),
                      const SizedBox(height: 4),
                      _buildInfoRow(
                        Icons.business_outlined,
                        venta['habitacion_nombre'] ?? 'Barra / General',
                        isDark,
                      ),
                      const SizedBox(height: 4),
                      _buildInfoRow(
                        Icons.access_time_rounded,
                        '${_formatDateTime(venta['fecha_crea'])} • $method',
                        isDark,
                        small: true,
                      ),
                      if (activeTimer != null) ...[
                        const SizedBox(height: 8),
                        _buildTimerPill(activeTimer, timerState, isDark),
                      ],
                      
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (venta['usuarios_nicks'] != null)
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${venta['usuarios_nicks']}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          const Spacer(),
                          Text(
                            formatCurrency(total),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: estado == 0
                                  ? Colors.redAccent
                                  : (isDark ? Colors.white : Colors.black),
                              decoration: estado == 0
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String text,
    bool isDark, {
    bool small = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: isDark
              ? AppTheme.darkTextSecondary
              : AppTheme.lightTextSecondary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: small ? 11 : 13,
              fontWeight: FontWeight.w500,
              color: small
                  ? (isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary)
                  : (isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTimerPill(
    ActiveTimer timer,
    TimerState timerState,
    bool isDark,
  ) {
    final remaining = timer.calculateRemaining(timerState.serverOffset);
    final isOverdue = timer.isOverdue(timerState.serverOffset);
    final isPaused = timer.isPaused;

    Color bgColor;
    Color textColor;
    String text;

    if (isOverdue) {
      bgColor = Colors.redAccent.withValues(alpha: 0.15);
      textColor = Colors.redAccent;
      text = 'AGOTADO';
    } else if (isPaused) {
      bgColor = Colors.orange.withValues(alpha: 0.15);
      textColor = Colors.orange;
      text = 'PAUSADO ${timer.formatRemaining(timerState.serverOffset)}';
    } else if (remaining <= 300) {
      bgColor = Colors.redAccent.withValues(alpha: 0.12);
      textColor = Colors.redAccent;
      text = timer.formatRemaining(timerState.serverOffset);
    } else {
      bgColor = Colors.green.withValues(alpha: 0.12);
      textColor = Colors.green;
      text = timer.formatRemaining(timerState.serverOffset);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOverdue
                ? Icons.timer_off_rounded
                : isPaused
                ? Icons.pause_circle_outline
                : Icons.timer_outlined,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RESTANTE',
                style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
              Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  
  Widget _buildAnulacionModal(bool isDark) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            if (!ref.read(ventasListProvider).anulandoVenta) {
              ref.read(setStateProvider('ventas').notifier).setFlag('anulacionModalVisible', false);
            }
          },
          child: Container(color: Colors.black54),
        ),
        Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkSurfaceColor
                    : AppTheme.lightSurfaceColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Solicitar Anulación',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Completa el monto y el motivo para enviar la solicitud al administrador.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : Colors.black.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _buildInfoText(
                            'Código',
                            _activeVenta?['codigo'] ?? '-',
                            isDark,
                          ),
                          const SizedBox(height: 4),
                          _buildInfoText(
                            'Cliente',
                            _activeVenta?['cliente_nombre'] ?? 'Sin cliente',
                            isDark,
                          ),
                          const SizedBox(height: 4),
                          _buildInfoText(
                            'Total referencia',
                            formatCurrency(
                              double.tryParse(
                                    _activeVenta?['total']?.toString() ?? '0',
                                  ) ??
                                  0,
                            ),
                            isDark,
                            valueColor: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    
                    Text(
                      'Monto solicitado *',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _montoAnulacionController,
                      onChanged: (v) {
                        _montoAnulacion = _formatMontoInput(v);
                      },
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Ingresa el monto',
                        filled: true,
                        fillColor: isDark ? AppTheme.darkBgColor : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    
                    Text(
                      'Motivo de la anulación *',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _motivoController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Describe el motivo...',
                        filled: true,
                        fillColor: isDark ? AppTheme.darkBgColor : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: ref.read(ventasListProvider).anulandoVenta
                                ? null
                                : () => ref.read(setStateProvider('ventas').notifier).setFlag('anulacionModalVisible', false),
                            child: Text(
                              'Cancelar',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: ref.read(ventasListProvider).anulandoVenta
                                ? null
                                : _handleAnularVenta,
                            child: ref.read(ventasListProvider).anulandoVenta
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Enviar Solicitud',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoText(
    String label,
    String value,
    bool isDark, {
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color:
                valueColor ??
                (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailContent(ScrollController scrollController, bool isDark) {
    final venta = ref.read(ventasListProvider).selectedVenta;
    final listItems = (venta['items'] as List<dynamic>?) ?? [];
    final double subtotal =
        double.tryParse(venta['subtotal']?.toString() ?? '0') ?? 0.0;
    final double descuento =
        double.tryParse(venta['descuento']?.toString() ?? '0') ?? 0.0;
    final double total =
        double.tryParse(venta['total']?.toString() ?? '0') ?? 0.0;
    final double propina =
        double.tryParse(venta['propina']?.toString() ?? '0') ?? 0.0;

    return Column(
      children: [
        
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detalle de Venta',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Código: ${venta['codigo'] ?? ''}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => ref.read(setStateProvider('ventas').notifier).setFlag('modalVisible', false),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),

        
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              
              Row(
                children: [
                  Expanded(
                    child: _buildDetailInfoBox(
                      'Fecha/Hora',
                      _formatDateTime(venta['fecha_crea']),
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDetailInfoBox(
                      'Método Pago',
                      (venta['metodo_pago']?.toString().toUpperCase() ??
                          'EFECTIVO'),
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildDetailInfoBox(
                'Cliente',
                venta['cliente_nombre'] ?? 'Sin Cliente',
                isDark,
              ),
              if (venta['habitacion_nombre'] != null) ...[
                const SizedBox(height: 12),
                _buildDetailInfoBox(
                  'Habitación',
                  venta['habitacion_nombre'],
                  isDark,
                ),
              ],
              if (venta['tiempo'] != null) ...[
                const SizedBox(height: 12),
                _buildDetailInfoBox('Tiempo', '${venta['tiempo']} min', isDark),
              ],
              const SizedBox(height: 20),

              
              if (venta['pedido_id'] != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VENTA DESDE PEDIDO',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            if (venta['garzon_nombre'] != null)
                              Text(
                                'Garzón: ${venta['garzon_nombre']}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.lightTextSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              
              const SizedBox(height: 20),
              Text(
                'PRODUCTOS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              ...listItems.map((item) {
                final double precio =
                    double.tryParse(item['precio']?.toString() ?? '0') ?? 0.0;
                final int qty =
                    int.tryParse(item['cantidad']?.toString() ?? '1') ?? 1;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.black.withValues(alpha: 0.02),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'CANT: $qty',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item['producto_nombre'] ?? 'Producto',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        formatCurrency(precio * qty),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.03)
                      : Colors.black.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.darkBorderColor
                        : AppTheme.lightBorderColor,
                  ),
                ),
                child: Column(
                  children: [
                    _buildPriceRow('Subtotal', formatCurrency(subtotal)),
                    if (propina > 0) ...[
                      const SizedBox(height: 4),
                      _buildPriceRow(
                        'Propina',
                        '+${formatCurrency(propina)}',
                        color: Colors.green,
                      ),
                    ],
                    if (descuento > 0) ...[
                      const SizedBox(height: 4),
                      _buildPriceRow(
                        'Descuento',
                        '- ${formatCurrency(descuento)}',
                        color: Colors.redAccent,
                      ),
                    ],
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TOTAL',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          formatCurrency(total),
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),

        
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              onPressed: () => ref.read(setStateProvider('ventas').notifier).setFlag('modalVisible', false),
              child: Text(
                'Cerrar Detalles',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailInfoBox(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBgColor : const Color(0xFFF5F5F5),
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
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    String value, {
    bool isTotal = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isTotal ? 16 : 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isTotal ? 18 : 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
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
            label,
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
