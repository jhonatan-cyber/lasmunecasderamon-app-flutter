import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/currency_text.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../auth/data/auth_notifier.dart';

// Model definition for unified solicitudes
class SolicitudItem {
  final String idUnificado;
  final String tipoItem; // 'solicitud', 'pedido', 'anticipo'
  final String id;
  final String codigo;
  final double monto;
  final String roomName;
  final String solicitadoPor;
  final DateTime fechaOrden;
  final int estado;
  final String motivo;
  final String? fechaMod;
  
  // Custom properties for specific types
  final List<dynamic>? anfitrionasIds;
  final List<dynamic>? anfitrionasConNicks;
  final double? comisionAnfitriona;
  final double? precioServicio;
  final double? precioHabitacion;
  final double? iva;
  final int? tiempo;
  final String? metodoPago;

  SolicitudItem({
    required this.idUnificado,
    required this.tipoItem,
    required this.id,
    required this.codigo,
    required this.monto,
    required this.roomName,
    required this.solicitadoPor,
    required this.fechaOrden,
    required this.estado,
    required this.motivo,
    this.fechaMod,
    this.anfitrionasIds,
    this.anfitrionasConNicks,
    this.comisionAnfitriona,
    this.precioServicio,
    this.precioHabitacion,
    this.iva,
    this.tiempo,
    this.metodoPago,
  });

  factory SolicitudItem.fromService(Map<String, dynamic> json) {
    final id = json['id_solicitud']?.toString() ?? json['id']?.toString() ?? '';
    final totalVal = double.tryParse(json['total']?.toString() ?? json['monto']?.toString() ?? '0') ?? 0.0;
    
    return SolicitudItem(
      idUnificado: 'solicitud_$id',
      tipoItem: 'solicitud',
      id: id,
      codigo: json['codigo']?.toString() ?? '#$id',
      monto: totalVal,
      roomName: json['habitacion_nombre']?.toString() ?? 'N/A',
      solicitadoPor: json['solicitado_por_nombre']?.toString() ?? 'Desconocido',
      fechaOrden: DateTime.tryParse(json['fecha_solicitud']?.toString() ?? json['fecha_crea']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      estado: json['estado'] is int ? json['estado'] : 0,
      motivo: json['motivo_rechazo']?.toString() ?? json['motivo']?.toString() ?? '',
      anfitrionasIds: json['anfitrionas_ids'] is List ? json['anfitrionas_ids'] : null,
      anfitrionasConNicks: json['anfitrionas_con_nicks'] is List ? json['anfitrionas_con_nicks'] : null,
      comisionAnfitriona: double.tryParse(json['comision_anfitriona']?.toString() ?? '0'),
      precioServicio: double.tryParse(json['precio_servicio']?.toString() ?? '0'),
      precioHabitacion: double.tryParse(json['precio_habitacion']?.toString() ?? '0'),
      iva: double.tryParse(json['iva']?.toString() ?? '0'),
      tiempo: int.tryParse(json['tiempo']?.toString() ?? json['time']?.toString() ?? '0'),
      metodoPago: json['metodo_pago']?.toString() ?? 'efectivo',
    );
  }

  factory SolicitudItem.fromOrder(Map<String, dynamic> json) {
    final id = json['id_pedido']?.toString() ?? json['id']?.toString() ?? '';
    
    return SolicitudItem(
      idUnificado: 'pedido_$id',
      tipoItem: 'pedido',
      id: id,
      codigo: json['codigo']?.toString() ?? '#$id',
      monto: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
      roomName: json['habitacion_nombre']?.toString() ?? json['mesa']?.toString() ?? 'Mesa/Sala',
      solicitadoPor: json['mesero_nick']?.toString() ?? json['mesero_nombre']?.toString() ?? json['garzon']?.toString() ?? 'Desconocido',
      fechaOrden: DateTime.tryParse(json['fecha_crea']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      estado: json['estado'] is int ? json['estado'] : 0,
      motivo: '',
      metodoPago: json['metodo_pago']?.toString(),
    );
  }

  factory SolicitudItem.fromAnticipo(Map<String, dynamic> json) {
    final id = json['id_anticipo']?.toString() ?? json['id']?.toString() ?? '';
    final codeVal = json['codigo']?.toString() ?? 'ANT-${id.length > 6 ? id.substring(0, 6).toUpperCase() : id.toUpperCase()}';
    final userVal = json['usuario']?.toString() ?? json['nick']?.toString() ?? 
        '${json['nombre'] ?? json['name'] ?? ''} ${json['apellido'] ?? json['lastName'] ?? ''}'.trim();
    
    return SolicitudItem(
      idUnificado: 'anticipo_$id',
      tipoItem: 'anticipo',
      id: id,
      codigo: codeVal,
      monto: double.tryParse(json['monto']?.toString() ?? '0') ?? 0.0,
      roomName: 'Anticipo',
      solicitadoPor: userVal.isNotEmpty ? userVal : 'Desconocido',
      fechaOrden: DateTime.tryParse(json['fecha_crea']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      estado: json['estado'] is int ? json['estado'] : 1,
      motivo: json['motivo']?.toString() ?? '',
      fechaMod: json['fecha_mod']?.toString(),
    );
  }
}

class CajeroSolicitudesScreen extends ConsumerStatefulWidget {
  const CajeroSolicitudesScreen({super.key});

  @override
  ConsumerState<CajeroSolicitudesScreen> createState() => _CajeroSolicitudesScreenState();
}

class _CajeroSolicitudesScreenState extends ConsumerState<CajeroSolicitudesScreen> {
  List<SolicitudItem> _solicitudes = [];
  List<dynamic> _allHostesses = [];
  bool _loading = true;
  bool _refreshing = false;
  bool _cajaAbierta = true;
  String _activeFilter = 'all'; // 'all', 'anticipo', 'pedido', 'solicitud'
  
  Timer? _pollingTimer;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Poll data every 10 seconds to keep cash register up to date
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadData(isManual: false));
    // Trigger tick every second to keep elapsed time relative counter active
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

  Future<void> _loadData({bool isManual = false}) async {
    if (!isManual && _solicitudes.isEmpty) {
      setState(() => _loading = true);
    }
    if (isManual) {
      setState(() => _refreshing = true);
    }

    try {
      final client = ref.read(apiClientProvider);
      
      // Perform all requests concurrently to minimize blocking
      final responses = await Future.wait([
        client.dio.get('/solicitudes-servicios?estado=0').catchError((_) => Response(requestOptions: RequestOptions(), data: {'success': false, 'data': []})),
        client.dio.get('/orders').catchError((_) => Response(requestOptions: RequestOptions(), data: {'success': false, 'data': []})),
        client.dio.get('/anticipos').catchError((_) => Response(requestOptions: RequestOptions(), data: {'success': false, 'data': []})),
        client.dio.get('/caja/stats').catchError((_) => Response(requestOptions: RequestOptions(), data: {'success': false, 'cajas_abiertas': 0})),
        client.dio.get('/anfitrionas').catchError((_) => Response(requestOptions: RequestOptions(), data: {'success': false, 'data': []})),
      ]);

      final resServices = responses[0];
      final resOrders = responses[1];
      final resAdvances = responses[2];
      final resCajaStats = responses[3];
      final resHostesses = responses[4];

      // Cache Hostesses
      if (resHostesses.data != null) {
        final hostList = resHostesses.data['success'] == true ? resHostesses.data['data'] : resHostesses.data;
        if (hostList is List) {
          _allHostesses = hostList;
        }
      }

      // Check caja status
      if (resCajaStats.data != null) {
        final stats = resCajaStats.data;
        if (stats['cajas_abiertas'] != null) {
          _cajaAbierta = (int.tryParse(stats['cajas_abiertas'].toString()) ?? 0) > 0;
        }
      }

      // Parse and combine
      List<SolicitudItem> combined = [];

      if (resServices.data != null && resServices.data['success'] == true) {
        final list = resServices.data['data'];
        if (list is List) {
          combined.addAll(list.map((s) => SolicitudItem.fromService(s)));
        }
      }

      if (resOrders.data != null && resOrders.data['success'] == true) {
        final list = resOrders.data['data'];
        if (list is List) {
          combined.addAll(list.map((o) => SolicitudItem.fromOrder(o)));
        }
      }

      if (resAdvances.data != null && resAdvances.data['success'] == true) {
        final list = resAdvances.data['data'];
        if (list is List) {
          // Filter: only estado 1 (approved, pending payment) or 2 (pending admin authorization)
          final filtered = list.where((a) {
            final st = int.tryParse(a['estado']?.toString() ?? '0') ?? 0;
            return st == 1 || st == 2;
          });
          combined.addAll(filtered.map((a) => SolicitudItem.fromAnticipo(a)));
        }
      }

      // Sort combined list newest first
      combined.sort((a, b) => b.fechaOrden.compareTo(a.fechaOrden));

      if (mounted) {
        setState(() {
          _solicitudes = combined;
          _loading = false;
          _refreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
        AppSnackBar.showError(context, 'Error de conexión al descargar solicitudes');
      }
    }
  }



  Future<void> _handleAprobarAnticipo(SolicitudItem item) async {
    final stateAdminVal = item.estado;
    final requiereAprobacionAdmin = stateAdminVal == 2;

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
          title: Text(
            requiereAprobacionAdmin ? 'Aprobar y Pagar Anticipo' : 'Entregar Efectivo',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: Text(
            '¿Confirmas que has entregado el efectivo de ${formatCurrency(item.monto)} a ${item.solicitadoPor}?',
            style: GoogleFonts.inter(fontSize: 14, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: GoogleFonts.inter(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  final client = ref.read(apiClientProvider);

                  // If requires admin approval first
                  if (requiereAprobacionAdmin) {
                    final approveRes = await client.dio.put('/anticipos/${item.id}', data: {'estado': 1});
                    if (approveRes.data == null || approveRes.data['success'] != true) {
                      AppSnackBar.showError(context, approveRes.data?['message'] ?? 'No se pudo autorizar el anticipo.');
                      _loadData(isManual: true);
                      return;
                    }
                  }

                  // Disburse advance (mark paid, estado = 0)
                  final payRes = await client.dio.put('/anticipos/${item.id}', data: {'estado': 0});
                  if (payRes.data != null && payRes.data['success'] == true) {
                    AppSnackBar.showSuccess(context, 'Anticipo entregado y registrado.');
                    _loadData(isManual: true);
                  } else {
                    AppSnackBar.showError(context, payRes.data?['message'] ?? 'Error al liquidar el anticipo.');
                    _loadData(isManual: true);
                  }
                } catch (e) {
                  AppSnackBar.showError(context, 'Error de conexión al procesar anticipo.');
                }
              },
              child: Text('Confirmar Pago', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleRechazar(SolicitudItem item) async {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final nameStr = item.tipoItem == 'solicitud' ? 'servicio' : 'pedido';
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
          title: Text('Rechazar Solicitud', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: Text(
            '¿Seguro que deseas rechazar este $nameStr?',
            style: GoogleFonts.inter(fontSize: 14, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: GoogleFonts.inter(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  final client = ref.read(apiClientProvider);
                  final isSrv = item.tipoItem == 'solicitud';
                  final endpoint = isSrv ? '/solicitudes-servicios/${item.id}/rechazar' : '/orders/${item.id}';
                  
                  final response = isSrv
                      ? await client.dio.patch(endpoint, data: {'motivo_rechazo': 'Rechazado por Caja'})
                      : await client.dio.put(endpoint, data: {'estado': 2});

                  if (response.data != null && response.data['success'] == true) {
                    AppSnackBar.showSuccess(context, 'Solicitud rechazada correctamente.');
                    _loadData(isManual: true);
                  } else {
                    AppSnackBar.showError(context, response.data?['message'] ?? 'Error al rechazar la solicitud.');
                    _loadData(isManual: true);
                  }
                } catch (e) {
                  AppSnackBar.showError(context, 'Error de conexión al rechazar solicitud.');
                }
              },
              child: Text('Rechazar', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _openCheckoutModal(SolicitudItem item) {
    if (!_cajaAbierta) {
      AppSnackBar.showError(context, 'No se pueden cobrar pedidos con la caja cerrada.');
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
            _loadData(isManual: true);
          },
        );
      },
    );
  }

  void _openServiceModal(SolicitudItem item) {
    if (!_cajaAbierta) {
      AppSnackBar.showError(context, 'No se pueden aprobar servicios con la caja cerrada.');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ServiceModalWidget(
          item: item,
          allHostesses: _allHostesses,
          onSuccess: () {
            _loadData(isManual: true);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter items
    final filteredList = _solicitudes.where((s) {
      if (_activeFilter == 'all') return true;
      return s.tipoItem == _activeFilter;
    }).toList();

    // Calculate sum of approved advances (estado == 1)
    final double totalAdvances = _solicitudes
        .where((s) => s.tipoItem == 'anticipo' && s.estado == 1)
        .fold(0.0, (sum, item) => sum + item.monto);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
      body: Column(
        children: [
          // Header Gradiente Premium
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
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
                  color: AppTheme.primaryColor.withValues(alpha: 0.25),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 25.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
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
                          onTap: () => _loadData(isManual: true),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                            ),
                            child: _refreshing
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
                      _cajaAbierta ? 'Pendientes de Aprobación' : 'Caja Cerrada',
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
                          decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'En Línea',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Total Advances Banner
          if (totalAdvances > 0)
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
                  border: Border(
                    left: const BorderSide(color: Colors.green, width: 4),
                    top: BorderSide(color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
                    right: BorderSide(color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
                    bottom: BorderSide(color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
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
                      child: const Icon(Icons.payments_outlined, color: Colors.green, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL A PAGAR EN ANTICIPOS',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatCurrency(totalAdvances),
                            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.green, letterSpacing: -0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Tabs Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTab('all', 'Todas', _solicitudes.length),
                  const SizedBox(width: 8),
                  _buildTab('anticipo', 'Anticipos', _solicitudes.where((s) => s.tipoItem == 'anticipo').length),
                  const SizedBox(width: 8),
                  _buildTab('pedido', 'Pedidos', _solicitudes.where((s) => s.tipoItem == 'pedido').length),
                  const SizedBox(width: 8),
                  _buildTab('solicitud', 'Servicios', _solicitudes.where((s) => s.tipoItem == 'solicitud').length),
                ],
              ),
            ),
          ),

          // List Header / Urgency Indicator
          if (filteredList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.notifications_active_outlined, color: AppTheme.primaryColor, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${filteredList.length} SOLICITUD${filteredList.length != 1 ? 'ES' : ''} PENDIENTE${filteredList.length != 1 ? 'S' : ''}',
                      style: GoogleFonts.inter(color: AppTheme.primaryColor, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
            ),

          // Items Grid/List
          Expanded(
            child: _loading
                ? const Center(child: SkeletonCard(lines: 5))
                : RefreshIndicator(
                    color: AppTheme.primaryColor,
                    onRefresh: () => _loadData(isManual: true),
                    child: filteredList.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 56,
                                      color: Colors.green.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Todo al día',
                                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'No hay solicitudes pendientes en esta sección',
                                      style: GoogleFonts.inter(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
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
                              final item = filteredList[idx];
                              return _buildSolicitudCard(item);
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
              ? AppTheme.primaryColor
              : (isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : (isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$label ($count)',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildSolicitudCard(SolicitudItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSrv = item.tipoItem == 'solicitud';
    final isAnt = item.tipoItem == 'anticipo';
    
    final color = isSrv ? AppTheme.primaryColor : isAnt ? Colors.green : Colors.amber;
    final icon = isSrv ? Icons.restaurant_menu_rounded : isAnt ? Icons.payments_rounded : Icons.local_bar_rounded;
    final typeLabel = isSrv ? 'Servicio' : isAnt ? 'Anticipo' : 'Trago / Pedido';
    
    final timeStr = DateFormat('hh:mm a').format(item.fechaOrden);
    final elapsedMinutes = DateTime.now().difference(item.fechaOrden).inMinutes;
    final isUrgent = elapsedMinutes >= 5 && !isAnt;

    // Custom labels
    final placeLabel = isSrv ? 'Hab: ${item.roomName}' : isAnt ? 'Caja / Desembolso' : 'Mesa: ${item.roomName}';
    final requestByLabel = isSrv ? 'Anfitriona: ${item.solicitadoPor}' : isAnt ? 'Para: ${item.solicitadoPor}' : 'Garzón: ${item.solicitadoPor}';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isUrgent ? Colors.redAccent : (isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
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
              // Card Header
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
                        'Código: ${item.codigo}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          typeLabel,
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    formatCurrency(item.monto),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.green),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Card Body Details
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bed_outlined, size: 14, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            placeLabel,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded, size: 14, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            requestByLabel,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 14, color: isUrgent ? Colors.redAccent : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$timeStr ($elapsedMinutes min transcurridos)',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isUrgent ? FontWeight.bold : FontWeight.w500,
                              color: isUrgent ? Colors.redAccent : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Anticipo details/state
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
                              item.estado == 1 ? '✓ Aprobado por Administración' : '⏳ Esperando Respuesta Admin',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: item.estado == 1 ? Colors.green : Colors.blueAccent,
                              ),
                            ),
                            if (item.motivo.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.motivo,
                                style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
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

              // Action Buttons Row
              Row(
                children: [
                  if (isAnt) ...[
                    if (item.estado == 2)
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              'En Autorización',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: !_cajaAbierta ? null : () => _handleAprobarAnticipo(item),
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: Text('Entregar Efectivo', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                  ] else ...[
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                            foregroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: !_cajaAbierta ? null : () => _handleRechazar(item),
                          child: Text('Rechazar', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: !_cajaAbierta
                              ? null
                              : () {
                                  if (isSrv) {
                                    _openServiceModal(item);
                                  } else {
                                    _openCheckoutModal(item);
                                  }
                                },
                          child: Text('Aprobar', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
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

// Sub-component: CheckoutModalWidget
class CheckoutModalWidget extends ConsumerStatefulWidget {
  final SolicitudItem item;
  final VoidCallback onSuccess;

  const CheckoutModalWidget({
    super.key,
    required this.item,
    required this.onSuccess,
  });

  @override
  ConsumerState<CheckoutModalWidget> createState() => _CheckoutModalWidgetState();
}

class _CheckoutModalWidgetState extends ConsumerState<CheckoutModalWidget> {
  List<dynamic> _details = [];
  Map<String, dynamic>? _clientData;
  bool _loading = true;
  bool _submitting = false;

  // Checkout inputs
  String _metodoPago = 'efectivo'; // 'efectivo', 'tarjeta', 'transferencia', 'prepago'
  String _metodoPagoAdicional = ''; // If mixed payment
  bool _agregarPropina = false;
  int _selectedMinutes = 30; // default habitacion duration

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final client = ref.read(apiClientProvider);
      
      // Load details of the order
      final detailRes = await client.dio.get('/orders/detail?id=${widget.item.id}');
      
      if (detailRes.data != null && detailRes.data['success'] == true) {
        final List<dynamic> loadedDetails = detailRes.data['data'] ?? [];
        _details = loadedDetails;
        
        // Retrieve client info if associated
        final firstItem = loadedDetails.isNotEmpty ? loadedDetails[0] : null;
        final clientId = firstItem?['cliente_id'] ?? widget.item.metodoPago; // Fallback or properties
        
        if (clientId != null && clientId.toString().isNotEmpty) {
          final clientRes = await client.dio.get('/clients?id=$clientId');
          if (clientRes.data != null && clientRes.data['success'] == true) {
            _clientData = clientRes.data['data'];
            
            // Auto-select prepago payment method if customer has positive balance
            final double saldoVal = double.tryParse(_clientData?['saldo']?.toString() ?? '0') ?? 0.0;
            if (saldoVal > 0) {
              _metodoPago = 'prepago';
            }
          }
        }
        
        // Auto check if tip is already present
        final double tipVal = double.tryParse(firstItem?['propina']?.toString() ?? '0') ?? 0.0;
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
    setState(() => _submitting = true);
    
    // Totals calculations matching React Native hooks
    final double existingTip = _details.isNotEmpty ? (double.tryParse(_details[0]['propina']?.toString() ?? '0') ?? 0.0) : 0.0;
    final double subtotalBase = widget.item.monto - existingTip > 0 ? widget.item.monto - existingTip : widget.item.monto;
    final double tipAmount = existingTip > 0 ? existingTip : (_agregarPropina ? subtotalBase * 0.10 : 0.0);
    final double totalFinal = subtotalBase + tipAmount;
    
    final double saldoPrepago = _clientData != null ? (double.tryParse(_clientData?['saldo']?.toString() ?? '0') ?? 0.0) : 0.0;
    double montoPrepago = 0;
    if (_metodoPago == 'prepago' && _clientData != null && saldoPrepago > 0) {
      montoPrepago = saldoPrepago < totalFinal ? saldoPrepago : totalFinal;
    }

    // Determine primary/secondary payment method if mixed
    String finalMetodoPago = _metodoPago;
    String? finalMetodoAdicional;
    
    if (_metodoPago == 'prepago' && saldoPrepago < totalFinal && saldoPrepago > 0) {
      finalMetodoPago = 'prepago';
      finalMetodoAdicional = _metodoPagoAdicional.isNotEmpty ? _metodoPagoAdicional : 'efectivo';
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
        'sub_total': d['subtotal_detalle'] ?? ((double.tryParse(d['cantidad']?.toString() ?? '0') ?? 0.0) * (double.tryParse(d['precio']?.toString() ?? '0') ?? 0.0)),
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
        AppSnackBar.showSuccess(context, 'Pedido cobrado y cerrado con éxito');
        Navigator.pop(context);
        widget.onSuccess();
      } else {
        final msg = response.data?['message'] ?? 'Error al liquidar el pedido';
        if (!mounted) return;        AppSnackBar.showError(context, 'Error: $msg');
      }
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.showError(context, 'Error de red al liquidar pedido');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _handleAddToCuenta() async {
    if (_clientData == null) return;
    setState(() => _submitting = true);

    try {
      final detailsFormatted = _details.map((d) {
        final double qty = double.tryParse(d['cantidad']?.toString() ?? '0') ?? 0.0;
        final double prc = double.tryParse(d['precio']?.toString() ?? '0') ?? 0.0;
        return {
          'producto_id': d['producto_id'],
          'cantidad': qty,
          'precio': prc,
          'sub_total': qty * prc,
        };
      }).toList();

      final double subTotal = detailsFormatted.fold(0.0, (sum, d) => sum + (d['sub_total'] as double));

      final payload = {
        'codigo': 'CUENTA-${DateTime.now().millisecondsSinceEpoch}',
        'cliente_id': _clientData?['id'],
        'habitacion_id': _details.isNotEmpty ? _details[0]['habitacion_id'] : null,
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
        AppSnackBar.showSuccess(context, 'Pedido registrado en cuenta de ${_clientData?['name'] ?? ''}');
        Navigator.pop(context);
        widget.onSuccess();
      } else {
        final msg = response.data?['message'] ?? 'Error al registrar en cuenta';
        if (!mounted) return;        AppSnackBar.showError(context, 'Error: $msg');
      }
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.showError(context, 'Error de red al registrar cuenta');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Totals calculations
    final double existingTip = _details.isNotEmpty ? (double.tryParse(_details[0]['propina']?.toString() ?? '0') ?? 0.0) : 0.0;
    final double subtotalBase = widget.item.monto - existingTip > 0 ? widget.item.monto - existingTip : widget.item.monto;
    final double tipAmount = existingTip > 0 ? existingTip : (_agregarPropina ? subtotalBase * 0.10 : 0.0);
    final double totalFinal = subtotalBase + tipAmount;

    final double saldoPrepago = _clientData != null ? (double.tryParse(_clientData?['saldo']?.toString() ?? '0') ?? 0.0) : 0.0;
    final bool isMixed = _metodoPago == 'prepago' && saldoPrepago > 0 && saldoPrepago < totalFinal;
    final double restanteMixed = isMixed ? (totalFinal - saldoPrepago) : 0.0;

    final hasHabitacion = _details.isNotEmpty && _details[0]['habitacion_id'] != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border.all(color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
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
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cerrar Pedido',
                            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Código: ${widget.item.codigo}',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
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

                  // Resumen metadata row
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text('GARZÓN', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                _details.isNotEmpty ? (_details[0]['garzon']?.toString() ?? 'N/A') : 'N/A',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 30, color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
                        Expanded(
                          child: Column(
                            children: [
                              Text('CLIENTE', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                _details.isNotEmpty ? (_details[0]['cliente']?.toString() ?? 'Sin registrar') : 'Sin registrar',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 30, color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
                        Expanded(
                          child: Column(
                            children: [
                              Text('LUGAR', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                widget.item.roomName,
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Habitacion room time selector
                  if (hasHabitacion) ...[
                    Text(
                      'TIEMPO HABITACIÓN',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [30, 45, 60, 90, 120].map((mins) {
                        final isSel = _selectedMinutes == mins;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                            child: InkWell(
                              onTap: () => setState(() => _selectedMinutes = mins),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSel ? AppTheme.primaryColor : Colors.transparent,
                                  border: Border.all(color: isSel ? AppTheme.primaryColor : (isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    '$mins min',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSel ? Colors.white : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
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

                  // Details items list
                  Text(
                    'PRODUCTOS',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: _details.length,
                      itemBuilder: (context, idx) {
                        final det = _details[idx];
                        final qty = int.tryParse(det['cantidad']?.toString() ?? '1') ?? 1;
                        final price = double.tryParse(det['precio']?.toString() ?? '0') ?? 0.0;
                        final sub = qty * price;
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            children: [
                              Text(
                                '${qty}x ',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                              ),
                              Expanded(
                                child: Text(
                                  det['nombre_producto']?.toString() ?? det['producto']?.toString() ?? 'Producto',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                formatCurrency(sub),
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Client balance status
                  if (_clientData != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primaryColor, size: 20),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_clientData?['name']} ${_clientData?['lastName']}',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Cliente frecuente',
                                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'SALDO PREPAGO',
                                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                              Text(
                                formatCurrency(saldoPrepago),
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: saldoPrepago > 0 ? Colors.green : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Payment method grid
                  Text(
                    'MÉTODO DE PAGO',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.6,
                    children: [
                      _buildPaymentBtn('efectivo', Icons.payments_outlined),
                      _buildPaymentBtn('tarjeta', Icons.credit_card_rounded),
                      _buildPaymentBtn('transferencia', Icons.swap_horizontal_circle_outlined),
                      if (_clientData != null)
                        _buildPaymentBtn('prepago', Icons.wallet_giftcard_rounded),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Mixed payment details if necessary
                  if (isMixed) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PAGO MIXTO REQUERIDO',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Deducción Prepago:', style: GoogleFonts.inter(fontSize: 12)),
                              Text('- ${formatCurrency(saldoPrepago)}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Restante por cobrar:', style: GoogleFonts.inter(fontSize: 12)),
                              Text(formatCurrency(restanteMixed), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'MÉTODO PARA RESTANTE:',
                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: ['efectivo', 'tarjeta', 'transferencia'].map((m) {
                              final isSel = _metodoPagoAdicional == m;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                  child: InkWell(
                                    onTap: () => setState(() => _metodoPagoAdicional = m),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isSel ? Colors.green : Colors.transparent,
                                        border: Border.all(color: isSel ? Colors.green : (isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor)),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Text(
                                          m.toUpperCase(),
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isSel ? Colors.white : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Totals breakdown
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Subtotal', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey)),
                            Text(formatCurrency(subtotalBase), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        
                        // Tip Switcher
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _agregarPropina,
                                    activeColor: AppTheme.primaryColor,
                                    onChanged: existingTip > 0
                                        ? null // disabled if already present
                                        : (val) {
                                            setState(() => _agregarPropina = val ?? false);
                                          },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  existingTip > 0 ? 'Propina de camarero' : 'Agregar 10% Propina',
                                  style: GoogleFonts.inter(fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
                                ),
                              ],
                            ),
                            Text(
                              '+ ${formatCurrency(tipAmount)}',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Final', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                            Text(formatCurrency(totalFinal), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.primaryColor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions button row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancelar', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      
                      // Account option if client present
                      if (_clientData != null) ...[
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _submitting ? null : _handleAddToCuenta,
                            child: _submitting
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text('CUENTA', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],

                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _submitting ? null : _handleSubmitCheckout,
                          child: _submitting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text('COBRAR VENTA', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPaymentBtn(String m, IconData ic) {
    final isSel = _metodoPago == m;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: () {
        setState(() {
          _metodoPago = m;
          if (m != 'prepago') {
            _metodoPagoAdicional = '';
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isSel ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: isSel ? AppTheme.primaryColor : (isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
            width: isSel ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(ic, color: isSel ? AppTheme.primaryColor : Colors.grey, size: 20),
            const SizedBox(height: 4),
            Text(
              m.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSel ? AppTheme.primaryColor : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Sub-component: ServiceModalWidget
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
  ConsumerState<ServiceModalWidget> createState() => _ServiceModalWidgetState();
}

class _ServiceModalWidgetState extends ConsumerState<ServiceModalWidget> {
  Map<String, dynamic>? _clientData;
  bool _loadingClient = false;
  bool _submitting = false;

  // Selected values
  String _metodoPago = 'efectivo';
  String _metodoPagoAdicional = '';

  @override
  void initState() {
    super.initState();
    _fetchClientInfo();
  }

  Future<void> _fetchClientInfo() async {
    // In React Native: cId = selectedService.cliente_id || selectedService.id_cliente
    final dynamic clientId = widget.item.metodoPago; // O el property correspondiente
    // Let's check how the JSON contains customer ID
    // We can fetch client if present
    // Since it's stored in widget.item, let's look for a key
    if (clientId != null && clientId.toString().isNotEmpty) {
      setState(() => _loadingClient = true);
      try {
        final client = ref.read(apiClientProvider);
        final response = await client.dio.get('/clients?id=$clientId');
        if (response.data != null && response.data['success'] == true) {
          _clientData = response.data['data'];
          
          final double saldoVal = double.tryParse(_clientData?['saldo']?.toString() ?? '0') ?? 0.0;
          if (saldoVal > 0) {
            _metodoPago = 'prepago';
          }
        }
      } catch (_) {}
      if (mounted) {
        setState(() => _loadingClient = false);
      }
    }
  }

  Future<void> _handleAprobarServicio() async {
    setState(() => _submitting = true);

    final double totalFinal = widget.item.monto;
    final double saldoPrepago = _clientData != null ? (double.tryParse(_clientData?['saldo']?.toString() ?? '0') ?? 0.0) : 0.0;

    String finalMetodoPago = _metodoPago;
    String? finalMetodoAdicional;

    if (_metodoPago == 'prepago' && saldoPrepago < totalFinal && saldoPrepago > 0) {
      finalMetodoPago = 'prepago';
      finalMetodoAdicional = _metodoPagoAdicional.isNotEmpty ? _metodoPagoAdicional : 'efectivo';
    }

    try {
      final client = ref.read(apiClientProvider);
      final Map<String, dynamic> body = {
        'metodo_pago': finalMetodoPago,
      };
      if (finalMetodoAdicional != null) {
        body['metodo_pago_adicional'] = finalMetodoAdicional;
      }
      final response = await client.dio.patch(
        '/solicitudes-servicios/${widget.item.id}/aprobar',
        data: body,
      );

      if (response.data != null && response.data['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Servicio aprobado y en curso.'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
        );
        Navigator.pop(context);
        widget.onSuccess();
      } else {
        final msg = response.data?['message'] ?? 'Error al aprobar servicio';
        if (!mounted) return;
        AppSnackBar.showError(context, 'Error: $msg');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de red al aprobar servicio'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Services breakdown values
    final double subtotalServicio = widget.item.precioServicio ?? widget.item.monto;
    final double subtotalHabitacion = widget.item.precioHabitacion ?? 0.0;
    final double ivaVal = widget.item.iva ?? 0.0;
    final double totalFinal = widget.item.monto;
    
    final double saldoPrepago = _clientData != null ? (double.tryParse(_clientData?['saldo']?.toString() ?? '0') ?? 0.0) : 0.0;
    final bool isMixed = _metodoPago == 'prepago' && saldoPrepago > 0 && saldoPrepago < totalFinal;
    final double restanteMixed = isMixed ? (totalFinal - saldoPrepago) : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border.all(color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
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
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detalle de Servicio',
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Código: ${widget.item.codigo}',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
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

            // Info rows
            _buildInfoRow(Icons.bed_outlined, 'Habitación: ${widget.item.roomName}'),
            const SizedBox(height: 10),
            _buildInfoRow(Icons.timer_outlined, 'Tiempo: ${widget.item.tiempo ?? 0} min'),
            const SizedBox(height: 10),
            _buildInfoRow(Icons.person_outline_rounded, 'Solicitado por: ${widget.item.solicitadoPor}'),
            const SizedBox(height: 10),
            _buildInfoRow(Icons.calendar_month_outlined, 'Fecha: ${DateFormat('dd/MM/yyyy hh:mm a').format(widget.item.fechaOrden)}'),
            const SizedBox(height: 16),

            // Hostesses comisiones
            Text(
              'ANFITRIONAS',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            _buildHostessesList(),
            const SizedBox(height: 16),

            // Client balance details
            if (_loadingClient)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
              )
            else if (_clientData != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_clientData?['name']} ${_clientData?['lastName']}',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Cliente frecuente',
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'SALDO PREPAGO',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        Text(
                          formatCurrency(saldoPrepago),
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: saldoPrepago > 0 ? Colors.green : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Modify payment method
              Text(
                'MODIFICAR MÉTODO DE PAGO',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Row(
                children: ['efectivo', 'tarjeta', 'transferencia', 'prepago'].map((m) {
                  final isSel = _metodoPago == m;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: InkWell(
                        onTap: () => setState(() => _metodoPago = m),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSel ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.transparent,
                            border: Border.all(
                              color: isSel ? AppTheme.primaryColor : (isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
                              width: isSel ? 1.5 : 1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                m == 'efectivo'
                                    ? Icons.payments_outlined
                                    : m == 'tarjeta'
                                        ? Icons.credit_card_rounded
                                        : m == 'prepago'
                                            ? Icons.wallet_giftcard_rounded
                                            : Icons.swap_horizontal_circle_outlined,
                                size: 16,
                                color: isSel ? AppTheme.primaryColor : Colors.grey,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m.toUpperCase(),
                                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: isSel ? AppTheme.primaryColor : Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Mixed payment for services
            if (isMixed) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PAGO MIXTO REQUERIDO',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Deducción Prepago:', style: GoogleFonts.inter(fontSize: 12)),
                        Text('- ${formatCurrency(saldoPrepago)}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Restante por cobrar:', style: GoogleFonts.inter(fontSize: 12)),
                        Text(formatCurrency(restanteMixed), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'MÉTODO PARA RESTANTE:',
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: ['efectivo', 'tarjeta', 'transferencia'].map((m) {
                        final isSel = _metodoPagoAdicional == m;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                            child: InkWell(
                              onTap: () => setState(() => _metodoPagoAdicional = m),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSel ? Colors.green : Colors.transparent,
                                  border: Border.all(color: isSel ? Colors.green : (isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    m.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isSel ? Colors.white : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Pricing summary receipt card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Precio Servicio', style: GoogleFonts.inter(fontSize: 13)),
                      Text(formatCurrency(subtotalServicio), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Precio Habitación', style: GoogleFonts.inter(fontSize: 13)),
                      Text(formatCurrency(subtotalHabitacion), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (ivaVal > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Ajuste IVA', style: GoogleFonts.inter(fontSize: 13)),
                        Text(formatCurrency(ivaVal), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('TOTAL', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)),
                      Text(
                        formatCurrency(totalFinal),
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Actions row buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cerrar', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _submitting ? null : _handleAprobarServicio,
                    child: _submitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('APROBAR AHORA', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData ic, String text) {
    return Row(
      children: [
        Icon(ic, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildHostessesList() {
    final anfsIds = widget.item.anfitrionasIds ?? [];
    final numAnfs = anfsIds.isEmpty ? 1 : anfsIds.length;
    
    // comision calculations matching React Native ServiceModal
    final double commissionAmount = widget.item.comisionAnfitriona ?? 0.0;
    final double finalCom = commissionAmount > 0
        ? (commissionAmount / numAnfs)
        : (widget.item.precioServicio ?? 0.0);

    // Compute display hostesses matching React Native ServiceModal
    final List<dynamic> displayAnfs = (widget.item.anfitrionasConNicks != null && widget.item.anfitrionasConNicks!.isNotEmpty)
        ? widget.item.anfitrionasConNicks!
        : anfsIds.map((id) {
            final found = widget.allHostesses.firstWhere(
              (h) => h['id_usuario']?.toString() == id.toString() || h['id']?.toString() == id.toString(),
              orElse: () => null,
            );
            return found ?? {'id': id, 'nick': 'ID: $id', 'nombre': 'Anfitriona'};
          }).toList();

    if (displayAnfs.isEmpty) {
      return Text(
        'No hay información de anfitrionas',
        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: displayAnfs.map((anf) {
        final nick = anf['nick']?.toString() ?? anf['nombre']?.toString() ?? 'Anfitriona';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.05),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                nick,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                '+ ${formatCurrency(finalCom)}',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.green),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
