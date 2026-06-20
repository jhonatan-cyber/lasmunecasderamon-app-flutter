import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../core/hooks/set_state_provider.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/currency_text.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../auth/data/auth_notifier.dart';
import '../data/solicitud_item.dart';
import '../data/solicitudes_notifier.dart';

class CajeroSolicitudesScreen extends ConsumerStatefulWidget {
  const CajeroSolicitudesScreen({super.key});

  @override
  ConsumerState<CajeroSolicitudesScreen> createState() =>
      _CajeroSolicitudesScreenState();
}

class _CajeroSolicitudesScreenState
    extends ConsumerState<CajeroSolicitudesScreen> {
  String _activeFilter = 'all'; 

  Timer? _pollingTimer;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(solicitudesListProvider.notifier).fetchData(),
    );
    
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => ref.read(solicitudesListProvider.notifier).fetchData(),
    );
    
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  
  
  

  Future<void> _handleAprobarAnticipo(SolicitudItem item) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final requiereAprobacionAdmin = item.estado == 2;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor:
              isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
          title: Text(
            requiereAprobacionAdmin
                ? 'Aprobar y Pagar Anticipo'
                : 'Entregar Efectivo',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Confirmas que has entregado el efectivo de ${formatCurrency(item.monto)} a ${item.solicitadoPor}?',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
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
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                'Confirmar Pago',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (approved != true) return;

    final ok =
        await ref.read(solicitudesListProvider.notifier).aprobarAnticipo(item);
    if (!mounted) return;
    if (ok) {
      AppSnackBar.showSuccess(context, 'Anticipo entregado y registrado.');
    } else {
      AppSnackBar.showError(context, 'Error al procesar el anticipo.');
    }
  }

  Future<void> _handleRechazar(SolicitudItem item) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameStr = item.tipoItem == 'solicitud' ? 'servicio' : 'pedido';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor:
              isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
          title: Text(
            'Rechazar Solicitud',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Seguro que deseas rechazar este $nameStr?',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
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
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                'Rechazar',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final ok = await ref
        .read(solicitudesListProvider.notifier)
        .rechazarSolicitud(item);
    if (!mounted) return;
    if (ok) {
      AppSnackBar.showSuccess(context, 'Solicitud rechazada correctamente.');
    } else {
      AppSnackBar.showError(context, 'Error al rechazar la solicitud.');
    }
  }

  void _openCheckoutModal(SolicitudItem item) {
    final state = ref.read(solicitudesListProvider);
    if (!state.cajaAbierta) {
      AppSnackBar.showError(
        context,
        'No se pueden cobrar pedidos con la caja cerrada.',
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return CheckoutModalWidget(
          item: item,
          onSuccess: () {
            ref.read(solicitudesListProvider.notifier).fetchData();
          },
        );
      },
    );
  }

  void _openServiceModal(SolicitudItem item) {
    final state = ref.read(solicitudesListProvider);
    if (!state.cajaAbierta) {
      AppSnackBar.showError(
        context,
        'No se pueden aprobar servicios con la caja cerrada.',
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ServiceModalWidget(
          item: item,
          allHostesses: state.allHostesses,
          onSuccess: () {
            ref.read(solicitudesListProvider.notifier).fetchData();
          },
        );
      },
    );
  }

  
  
  

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(solicitudesListProvider);

    
    final filteredList = state.solicitudes.where((s) {
      if (_activeFilter == 'all') return true;
      return s.tipoItem == _activeFilter;
    }).toList();

    
    final double totalAdvances = state.solicitudes
        .where((s) => s.tipoItem == 'anticipo' && s.estado == 1)
        .fold(0.0, (sum, item) => sum + item.monto);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
      body: Column(
        children: [
          
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  const Color(0xFF881337),
                  const Color(0xFF1A0B10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.25),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 25.0,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        Text(
                          'Solicitudes',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => ref
                              .read(solicitudesListProvider.notifier)
                              .fetchData(isManual: true),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                            child: state.isRefreshing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.refresh_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      state.cajaAbierta
                          ? 'Pendientes de AprobaciÃ³n'
                          : 'Caja Cerrada',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'En LÃ­nea',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          
          if (totalAdvances > 0)
            Padding(
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 16.0,
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkSurfaceColor
                      : AppTheme.lightSurfaceColor,
                  border: Border(
                    left: const BorderSide(color: Colors.green, width: 4),
                    top: BorderSide(
                      color: isDark
                          ? AppTheme.darkBorderColor
                          : AppTheme.lightBorderColor,
                    ),
                    right: BorderSide(
                      color: isDark
                          ? AppTheme.darkBorderColor
                          : AppTheme.lightBorderColor,
                    ),
                    bottom: BorderSide(
                      color: isDark
                          ? AppTheme.darkBorderColor
                          : AppTheme.lightBorderColor,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.payments_outlined,
                        color: Colors.green,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL A PAGAR EN ANTICIPOS',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatCurrency(totalAdvances),
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.green,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 14.0,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTab(
                    'all',
                    'Todas',
                    state.solicitudes.length,
                  ),
                  const SizedBox(width: 8),
                  _buildTab(
                    'anticipo',
                    'Anticipos',
                    state.solicitudes
                        .where((s) => s.tipoItem == 'anticipo')
                        .length,
                  ),
                  const SizedBox(width: 8),
                  _buildTab(
                    'pedido',
                    'Pedidos',
                    state.solicitudes
                        .where((s) => s.tipoItem == 'pedido')
                        .length,
                  ),
                  const SizedBox(width: 8),
                  _buildTab(
                    'solicitud',
                    'Servicios',
                    state.solicitudes
                        .where((s) => s.tipoItem == 'solicitud')
                        .length,
                  ),
                ],
              ),
            ),
          ),

          
          if (filteredList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_active_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${filteredList.length} SOLICITUD${filteredList.length != 1 ? 'ES' : ''} PENDIENTE${filteredList.length != 1 ? 'S' : ''}',
                      style: GoogleFonts.inter(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          
          Expanded(
            child: state.isLoading
                ? const Center(child: SkeletonCard(lines: 5))
                : RefreshIndicator(
                    color: Theme.of(context).colorScheme.primary,
                    onRefresh: () => ref
                        .read(solicitudesListProvider.notifier)
                        .fetchData(isManual: true),
                    child: filteredList.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.15,
                              ),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 56,
                                      color: Colors.green.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Todo al dÃ­a',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? AppTheme.darkTextPrimary
                                            : AppTheme.lightTextPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'No hay solicitudes pendientes en esta secciÃ³n',
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
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: filteredList.length,
                            itemBuilder: (context, idx) {
                              return _buildSolicitudCard(filteredList[idx]);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String filter, String label, int count) {
    final isSelected = _activeFilter == filter;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _activeFilter = filter;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : (isDark
                    ? AppTheme.darkSurfaceColor
                    : AppTheme.lightSurfaceColor),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : (isDark
                      ? AppTheme.darkBorderColor
                      : AppTheme.lightBorderColor),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$label ($count)',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildSolicitudCard(SolicitudItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSrv = item.tipoItem == 'solicitud';
    final isAnt = item.tipoItem == 'anticipo';

    final color = isSrv
        ? Theme.of(context).colorScheme.primary
        : isAnt
            ? Colors.green
            : Colors.amber;
    final icon = isSrv
        ? Icons.restaurant_menu_rounded
        : isAnt
            ? Icons.payments_rounded
            : Icons.local_bar_rounded;
    final typeLabel = isSrv ? 'Servicio' : isAnt ? 'Anticipo' : 'Trago / Pedido';

    final timeStr = DateFormat('hh:mm a').format(item.fechaOrden);
    final elapsedMinutes = DateTime.now().difference(item.fechaOrden).inMinutes;
    final isUrgent = elapsedMinutes >= 5 && !isAnt;

    final placeLabel = isSrv
        ? 'Hab: ${item.roomName}'
        : isAnt
            ? 'Caja / Desembolso'
            : 'Mesa: ${item.roomName}';
    final requestByLabel = isSrv
        ? 'Anfitriona: ${item.solicitadoPor}'
        : isAnt
            ? 'Para: ${item.solicitadoPor}'
            : 'GarzÃ³n: ${item.solicitadoPor}';

    final state = ref.read(solicitudesListProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isUrgent
              ? Colors.redAccent
              : (isDark
                    ? AppTheme.darkBorderColor
                    : AppTheme.lightBorderColor),
          width: isUrgent ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (isSrv) {
            _openServiceModal(item);
          } else if (isAnt) {
            if (item.estado == 1) {
              _handleAprobarAnticipo(item);
            }
          } else {
            _openCheckoutModal(item);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 16, color: color),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CÃ³digo: ${item.codigo}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          typeLabel,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    formatCurrency(item.monto),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.02)
                      : Colors.black.withValues(alpha: 0.01),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.bed_outlined,
                          size: 14,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            placeLabel,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.lightTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 14,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            requestByLabel,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.lightTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: isUrgent
                              ? Colors.redAccent
                              : (isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.lightTextSecondary),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$timeStr ($elapsedMinutes min transcurridos)',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight:
                                  isUrgent ? FontWeight.bold : FontWeight.w500,
                              color: isUrgent
                                  ? Colors.redAccent
                                  : (isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.lightTextSecondary),
                            ),
                          ),
                        ),
                      ],
                    ),

                    
                    if (isAnt) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: item.estado == 1
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: item.estado == 1
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.blue.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.estado == 1
                                  ? 'âœ“ Aprobado por AdministraciÃ³n'
                                  : 'âŒ³ Esperando Respuesta Admin',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: item.estado == 1
                                    ? Colors.green
                                    : Colors.blueAccent,
                              ),
                            ),
                            if (item.motivo.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.motivo,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              
              Row(
                children: [
                  if (isAnt) ...[
                    if (item.estado == 2)
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              'En AutorizaciÃ³n',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: !state.cajaAbierta
                                ? null
                                : () => _handleAprobarAnticipo(item),
                            icon: const Icon(
                              Icons.check_rounded,
                              size: 16,
                            ),
                            label: Text(
                              'Entregar Efectivo',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ] else ...[
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.redAccent.withValues(alpha: 0.5),
                            ),
                            foregroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: !state.cajaAbierta
                              ? null
                              : () => _handleRechazar(item),
                          child: Text(
                            'Rechazar',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: !state.cajaAbierta
                              ? null
                              : () {
                                  if (isSrv) {
                                    _openServiceModal(item);
                                  } else {
                                    _openCheckoutModal(item);
                                  }
                                },
                          child: Text(
                            'Aprobar',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}





class CheckoutModalWidget extends ConsumerStatefulWidget {
  final SolicitudItem item;
  final VoidCallback onSuccess;

  const CheckoutModalWidget({
    super.key,
    required this.item,
    required this.onSuccess,
  });

  @override
  ConsumerState<CheckoutModalWidget> createState() =>
      _CheckoutModalWidgetState();
}

class _CheckoutModalWidgetState extends ConsumerState<CheckoutModalWidget> {
  List<dynamic> _details = [];
  Map<String, dynamic>? _clientData;
  bool _loading = true;

  
  String _metodoPago = 'efectivo';
  String _metodoPagoAdicional = '';
  bool _agregarPropina = false;
  int _selectedMinutes = 30;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final client = ref.read(apiClientProvider);

      final detailRes =
          await client.dio.get('/orders/detail?id=${widget.item.id}');

      if (detailRes.data != null && detailRes.data['success'] == true) {
        final List<dynamic> loadedDetails = detailRes.data['data'] ?? [];
        _details = loadedDetails;

        final firstItem = loadedDetails.isNotEmpty ? loadedDetails[0] : null;
        final clientId =
            firstItem?['cliente_id'] ?? widget.item.metodoPago;

        if (clientId != null && clientId.toString().isNotEmpty) {
          final clientRes = await client.dio.get('/clients?id=$clientId');
          if (clientRes.data != null &&
              clientRes.data['success'] == true) {
            _clientData = clientRes.data['data'];

            final double saldoVal =
                double.tryParse(
                      _clientData?['saldo']?.toString() ?? '0',
                    ) ??
                    0.0;
            if (saldoVal > 0) {
              _metodoPago = 'prepago';
            }
          }
        }

        final double tipVal =
            double.tryParse(firstItem?['propina']?.toString() ?? '0') ??
                0.0;
        if (tipVal > 0) {
          _agregarPropina = true;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _handleSubmitCheckout() async {
    ref.read(setStateProvider('checkout_modal').notifier).startSubmit();

    final double existingTip = _details.isNotEmpty
        ? (double.tryParse(
                _details[0]['propina']?.toString() ?? '0') ??
            0.0)
        : 0.0;
    final double subtotalBase = widget.item.monto - existingTip > 0
        ? widget.item.monto - existingTip
        : widget.item.monto;
    final double tipAmount = existingTip > 0
        ? existingTip
        : (_agregarPropina ? subtotalBase * 0.10 : 0.0);
    final double totalFinal = subtotalBase + tipAmount;

    final double saldoPrepago =
        _clientData != null
            ? (double.tryParse(
                    _clientData?['saldo']?.toString() ?? '0') ??
                0.0)
            : 0.0;
    double montoPrepago = 0;
    if (_metodoPago == 'prepago' &&
        _clientData != null &&
        saldoPrepago > 0) {
      montoPrepago =
          saldoPrepago < totalFinal ? saldoPrepago : totalFinal;
    }

    String finalMetodoPago = _metodoPago;
    String? finalMetodoAdicional;

    if (_metodoPago == 'prepago' &&
        saldoPrepago < totalFinal &&
        saldoPrepago > 0) {
      finalMetodoPago = 'prepago';
      finalMetodoAdicional =
          _metodoPagoAdicional.isNotEmpty ? _metodoPagoAdicional : 'efectivo';
    }

    final Map<String, dynamic> payload = {
      'id_pedido': widget.item.id,
      'cliente_id': _clientData?['id'],
      'metodo_pago': finalMetodoPago,
      'monto_prepago': montoPrepago,
      'duracion_habitacion': _selectedMinutes,
      'sub_total': subtotalBase,
      'total': totalFinal,
      'ganancia_tipo': 'fijo',
      'ganancia_monto': 0,
      'comision_por_cliente': false,
      'recompensa_binario': false,
      'recompensa_activos': false,
      'recompensa_activos_monto': 0,
      'ganancia_anfitriona': 0,
      'ganancia_garzon': 0,
      'ganancia_local': 0,
      'ganancia_empresa': 0,
      'total_comision': 0,
      'tiempo': _selectedMinutes,
      'usuarios': [],
      'detalles': _details.map((d) => {
            'producto_id': d['producto_id'],
            'cantidad': d['cantidad'],
            'precio': d['precio'],
            'sub_total': d['subtotal_detalle'] ??
                ((double.tryParse(d['cantidad']?.toString() ?? '0') ??
                        0.0) *
                    (double.tryParse(d['precio']?.toString() ?? '0') ??
                        0.0)),
          }).toList(),
    };

    if (finalMetodoAdicional != null) {
      payload['metodo_pago_adicional'] = finalMetodoAdicional;
    }

    if (tipAmount > 0) {
      payload['propina'] = tipAmount;
    }

    try {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.post('/sales', data: payload);

      if (response.data != null && response.data['success'] == true) {
        if (!mounted) return;
        AppSnackBar.showSuccess(
          context,
          'Pedido cobrado y cerrado con Ã©xito',
        );
        Navigator.pop(context);
        widget.onSuccess();
      } else {
        final msg =
            response.data?['message'] ?? 'Error al liquidar el pedido';
        if (!mounted) return;
        AppSnackBar.showError(context, 'Error: $msg');
      }
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.showError(context, 'Error de red al liquidar pedido');
    } finally {
      if (mounted) {
        ref.read(setStateProvider('checkout_modal').notifier).endSubmit();
      }
    }
  }

  Future<void> _handleAddToCuenta() async {
    if (_clientData == null) return;
    ref.read(setStateProvider('checkout_modal').notifier).startSubmit();

    try {
      final detailsFormatted = _details.map((d) {
        final double qty =
            double.tryParse(d['cantidad']?.toString() ?? '0') ?? 0.0;
        final double prc =
            double.tryParse(d['precio']?.toString() ?? '0') ?? 0.0;
        return {
          'producto_id': d['producto_id'],
          'cantidad': qty,
          'precio': prc,
          'sub_total': qty * prc,
        };
      }).toList();

      final double subTotal = detailsFormatted.fold(
        0.0,
        (sum, d) => sum + (d['sub_total'] as double),
      );

      final payload = {
        'codigo':
            'CUENTA-${DateTime.now().millisecondsSinceEpoch}',
        'cliente_id': _clientData?['id'],
        'habitacion_id': _details.isNotEmpty
            ? _details[0]['habitacion_id']
            : null,
        'tiempo': _selectedMinutes,
        'metodo_pago': 'efectivo',
        'sub_total': subTotal,
        'total': subTotal,
        'total_comision': 0,
        'detalles': detailsFormatted,
      };

      final client = ref.read(apiClientProvider);
      final response = await client.dio.post('/cuentas', data: payload);

      if (response.data != null && response.data['success'] == true) {
        if (!mounted) return;
        AppSnackBar.showSuccess(
          context,
          'Pedido registrado en cuenta de ${_clientData?['name'] ?? ''}',
        );
        Navigator.pop(context);
        widget.onSuccess();
      } else {
        final msg =
            response.data?['message'] ?? 'Error al registrar en cuenta';
        if (!mounted) return;
        AppSnackBar.showError(context, 'Error: $msg');
      }
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.showError(context, 'Error de red al registrar cuenta');
    } finally {
      if (mounted) {
        ref.read(setStateProvider('checkout_modal').notifier).endSubmit();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double existingTip = _details.isNotEmpty
        ? (double.tryParse(
                _details[0]['propina']?.toString() ?? '0') ??
            0.0)
        : 0.0;
    final double subtotalBase = widget.item.monto - existingTip > 0
        ? widget.item.monto - existingTip
        : widget.item.monto;
    final double tipAmount = existingTip > 0
        ? existingTip
        : (_agregarPropina ? subtotalBase * 0.10 : 0.0);
    final double totalFinal = subtotalBase + tipAmount;

    final double saldoPrepago =
        _clientData != null
            ? (double.tryParse(
                    _clientData?['saldo']?.toString() ?? '0') ??
                0.0)
            : 0.0;
    final bool isMixed = _metodoPago == 'prepago' &&
        saldoPrepago > 0 &&
        saldoPrepago < totalFinal;
    final double restanteMixed = isMixed ? (totalFinal - saldoPrepago) : 0.0;

    final hasHabitacion =
        _details.isNotEmpty && _details[0]['habitacion_id'] != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkSurfaceColor
            : AppTheme.lightSurfaceColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border.all(
          color: isDark
              ? AppTheme.darkBorderColor
              : AppTheme.lightBorderColor,
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: _loading
          ? const SizedBox(
              height: 250,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: SkeletonCard(lines: 5),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cerrar Pedido',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'CÃ³digo: ${widget.item.codigo}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark
                            ? AppTheme.darkBorderColor
                            : AppTheme.lightBorderColor,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'GARZÃ“N',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _details.isNotEmpty
                                    ? (_details[0]['garzon']
                                            ?.toString() ??
                                        'N/A')
                                    : 'N/A',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: isDark
                              ? AppTheme.darkBorderColor
                              : AppTheme.lightBorderColor,
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'CLIENTE',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _details.isNotEmpty
                                    ? (_details[0]['cliente']
                                            ?.toString() ??
                                        'Sin registrar')
                                    : 'Sin registrar',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: isDark
                              ? AppTheme.darkBorderColor
                              : AppTheme.lightBorderColor,
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'LUGAR',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.item.roomName,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  
                  if (hasHabitacion) ...[
                    Text(
                      'TIEMPO HABITACIÃ“N',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [30, 45, 60, 90, 120].map((mins) {
                        final isSel = _selectedMinutes == mins;
                        return Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 2.0),
                            child: InkWell(
                              onTap: () =>
                                  setState(() => _selectedMinutes = mins),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSel
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                        : (isDark
                                              ? AppTheme.darkBorderColor
                                              : AppTheme.lightBorderColor),
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    '$mins min',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSel
                                          ? Colors.white
                                          : (isDark
                                                ? AppTheme.darkTextSecondary
                                                : AppTheme
                                                    .lightTextSecondary),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  
                  Text(
                    'PRODUCTOS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.03)
                          : Colors.black.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? AppTheme.darkBorderColor
                            : AppTheme.lightBorderColor,
                      ),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: _details.length,
                      itemBuilder: (context, idx) {
                        final det = _details[idx];
                        final qty =
                            int.tryParse(det['cantidad']?.toString() ?? '1') ??
                                1;
                        final price =
                            double.tryParse(
                                    det['precio']?.toString() ?? '0') ??
                                0.0;
                        final sub = qty * price;

                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            children: [
                              Text(
                                '${qty}x ',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  det['nombre']?.toString() ??
                                      det['producto_nombre']?.toString() ??
                                      'Producto',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Text(
                                formatCurrency(sub),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  
                  ..._buildPaymentSection(
                    isDark,
                    subtotalBase,
                    tipAmount,
                    totalFinal,
                    saldoPrepago,
                    isMixed,
                    restanteMixed,
                  ),

                  
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (_clientData != null)
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              onPressed: ref.watch(setStateProvider('checkout_modal')).isSubmitting
                                  ? null
                                  : _handleAddToCuenta,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: isDark
                                      ? AppTheme.darkBorderColor
                                      : AppTheme.lightBorderColor,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                'Ag. a Cuenta',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_clientData != null)
                        const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed:
                                ref.watch(setStateProvider('checkout_modal')).isSubmitting ? null : _handleSubmitCheckout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: ref.watch(setStateProvider('checkout_modal')).isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Cobrar \$${formatCurrency(totalFinal)}',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildPaymentSection(
    bool isDark,
    double subtotalBase,
    double tipAmount,
    double totalFinal,
    double saldoPrepago,
    bool isMixed,
    double restanteMixed,
  ) {
    return [
      
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Subtotal',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
          Text(
            formatCurrency(subtotalBase),
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
      if (tipAmount > 0) ...[
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Propina',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
            ),
            Text(
              '+ ${formatCurrency(tipAmount)}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ],
      const Divider(height: 24, thickness: 1),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'TOTAL',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            formatCurrency(totalFinal),
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: Colors.green,
            ),
          ),
        ],
      ),

      
      if (existingTip <= 0) ...[
        const SizedBox(height: 12),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Agregar propina del 10%',
            style: GoogleFonts.inter(fontSize: 12),
          ),
          value: _agregarPropina,
          onChanged: (v) {
            setState(() => _agregarPropina = v ?? false);
          },
          dense: true,
        ),
      ],

      
      const SizedBox(height: 8),
      Text(
        'MÃ©todo de Pago',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        initialValue: _metodoPago,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: [
          'efectivo',
          'tarjeta',
          'transferencia',
          'prepago',
        ].map((m) {
          return DropdownMenuItem(
            value: m,
            child: Text(
              m == 'efectivo'
                  ? 'Efectivo'
                  : m == 'tarjeta'
                      ? 'Tarjeta'
                      : m == 'transferencia'
                          ? 'Transferencia'
                          : 'Prepago (Saldo)',
              style: const TextStyle(fontSize: 13),
            ),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) {
            setState(() => _metodoPago = val);
          }
        },
      ),

      if (isMixed) ...[
        const SizedBox(height: 8),
        Text(
          'Saldo insuficiente. Restan: ${formatCurrency(restanteMixed)}',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: _metodoPagoAdicional.isNotEmpty
              ? _metodoPagoAdicional
              : 'efectivo',
          decoration: const InputDecoration(
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            labelText: 'Pago Adicional',
          ),
          items: ['efectivo', 'tarjeta', 'transferencia'].map((m) {
            return DropdownMenuItem(
              value: m,
              child: Text(
                m == 'efectivo'
                    ? 'Efectivo'
                    : m == 'tarjeta'
                        ? 'Tarjeta'
                        : 'Transferencia',
                style: const TextStyle(fontSize: 13),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _metodoPagoAdicional = val);
            }
          },
        ),
      ],

      
      if (_clientData != null) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.blue.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: Colors.blueAccent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Cliente: ${_clientData?['name'] ?? ''} - '
                  'Saldo: ${formatCurrency(saldoPrepago)}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  double get existingTip => _details.isNotEmpty
      ? (double.tryParse(_details[0]['propina']?.toString() ?? '0') ?? 0.0)
      : 0.0;
}





class ServiceModalWidget extends ConsumerStatefulWidget {
  final SolicitudItem item;
  final List<dynamic> allHostesses;
  final VoidCallback onSuccess;

  const ServiceModalWidget({
    super.key,
    required this.item,
    required this.allHostesses,
    required this.onSuccess,
  });

  @override
  ConsumerState<ServiceModalWidget> createState() =>
      _ServiceModalWidgetState();
}

class _ServiceModalWidgetState extends ConsumerState<ServiceModalWidget> {
  String _selectedAnfitriona = '';
  double _comisionAnfitriona = 0;

  @override
  void initState() {
    super.initState();
    
    if (widget.item.anfitrionasIds != null &&
        widget.item.anfitrionasIds!.isNotEmpty) {
      _selectedAnfitriona = widget.item.anfitrionasIds!.first.toString();
    }
    _comisionAnfitriona = widget.item.comisionAnfitriona ?? 0;
  }

  Future<void> _handleApproveService() async {
    await ref.read(setStateProvider('service_modal').notifier).guard(() async {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.patch(
        '/solicitudes-servicios/${widget.item.id}',
        data: {
          'estado': 1,
          'anfitriona_id': _selectedAnfitriona.isNotEmpty
              ? int.tryParse(_selectedAnfitriona)
              : null,
        },
      );

      if (response.data != null && response.data['success'] == true) {
        if (!mounted) return;
        AppSnackBar.showSuccess(context, 'Servicio aprobado correctamente.');
        Navigator.pop(context);
        widget.onSuccess();
      } else {
        if (!mounted) return;
        AppSnackBar.showError(
          context,
          response.data?['message'] ?? 'Error al aprobar servicio',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSubmitting = ref.watch(setStateProvider('service_modal')).isSubmitting;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkSurfaceColor
            : AppTheme.lightSurfaceColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border.all(
          color: isDark
              ? AppTheme.darkBorderColor
              : AppTheme.lightBorderColor,
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Aprobar Servicio',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),

            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkSurfaceColor
                    : AppTheme.lightSurfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? AppTheme.darkBorderColor
                      : AppTheme.lightBorderColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Hab: ${widget.item.roomName}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _infoRow(isDark, 'Solicitado por',
                      widget.item.solicitadoPor),
                  _infoRow(
                    isDark,
                    'Total',
                    formatCurrency(widget.item.monto),
                  ),
                  _infoRow(
                    isDark,
                    'Tiempo',
                    '${widget.item.tiempo ?? 0} min',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            
            Text(
              'ASIGNAR ANFITRIONA',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedAnfitriona.isNotEmpty
                  ? _selectedAnfitriona
                  : null,
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                hintText: 'Seleccionar anfitriona',
              ),
              items: widget.allHostesses.map((h) {
                final id = h['id']?.toString() ?? '';
                final name = h['nombre']?.toString() ?? h['name']?.toString() ?? '';
                return DropdownMenuItem(
                  value: id,
                  child: Text(name, style: const TextStyle(fontSize: 13)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedAnfitriona = val);
                }
              },
            ),
            const SizedBox(height: 8),

            
            if (_comisionAnfitriona > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ComisiÃ³n Anfitriona: ${formatCurrency(_comisionAnfitriona)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : _handleApproveService,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Aprobar Servicio',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(bool isDark, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
