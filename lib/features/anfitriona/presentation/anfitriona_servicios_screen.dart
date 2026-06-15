import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../auth/data/auth_notifier.dart';
import 'widgets/service_card.dart';
import 'widgets/service_detail_modal.dart';

class AnfitrionaServiciosScreen extends ConsumerStatefulWidget {
  const AnfitrionaServiciosScreen({super.key});

  @override
  ConsumerState<AnfitrionaServiciosScreen> createState() => _AnfitrionaServiciosScreenState();
}

class _AnfitrionaServiciosScreenState extends ConsumerState<AnfitrionaServiciosScreen> {
  List<dynamic> _servicios = [];
  bool _isLoading = false;
  String? _error;
  String _filter = 'all'; // all, pendiente, pagado, cobrado

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchServicios());
  }

  Future<void> _fetchServicios({bool isManual = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.get('/servicios/user');
      final data = response.data;

      if (data != null && data['success'] == true) {
        setState(() {
          _servicios = List<dynamic>.from(data['data'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data?['message'] ?? 'Error al cargar servicios';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de conexion con el servidor';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAssistance(String servicioId, String roomName, String type) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.post(
        '/notifications/assistance',
        data: {
          'servicioId': int.tryParse(servicioId) ?? servicioId,
          'roomName': roomName,
          'type': type,
        },
      );
      final data = response.data;
      if (data != null && data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Llamado de asistencia ($type) enviado'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo enviar el llamado de asistencia'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _onConfirmAssistance(String servicioId, String roomName, String type) {
    if (type == 'Seguridad') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Confirmar Alerta',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.redAccent),
          ),
          content: Text('¿Estás seguro de enviar una ALERTA de seguridad para la habitación $roomName?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleAssistance(servicioId, roomName, type);
              },
              child: const Text(
                'ENVIAR ALERTA',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    } else {
      _handleAssistance(servicioId, roomName, type);
    }
  }

  List<dynamic> get _filteredServicios {
    return _servicios.where((s) {
      if (s == null || s['id_servicio'] == null) return false;
      final estadoNum = int.tryParse(s['estado']?.toString() ?? '0') ?? 0;

      if (_filter == 'pendiente') {
        return [2, 3, 4].contains(estadoNum);
      }
      if (_filter == 'pagado') {
        return estadoNum == 1;
      }
      if (_filter == 'cobrado') {
        return estadoNum == 0;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const accentColor = Color(0xFFD84315);
    final bg = isDark ? Colors.black : const Color(0xFFF9FAFB);
    final cardBg = isDark ? const Color(0xFF111111) : Colors.white;
    final textSecondary = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final borderColor = isDark ? accentColor.withValues(alpha: 0.25) : Colors.grey.shade200;

    // Métricas
    final finalizados = _servicios.where((s) => s != null && int.tryParse(s['estado']?.toString() ?? '0') == 1);
    final cobrados = _servicios.where((s) => s != null && int.tryParse(s['estado']?.toString() ?? '0') == 0);
    final pendientes = _servicios.where((s) => s != null && [2, 3, 4].contains(int.tryParse(s['estado']?.toString() ?? '0')));

    final double totalACobrar = finalizados.fold(0.0, (sum, s) {
      final val = double.tryParse(s['comision_usuario']?.toString() ?? '0') ?? 0.0;
      return sum + val;
    });
    final double totalEstimado = _servicios.fold(0.0, (sum, s) {
      if (s == null) return sum;
      final val = double.tryParse(s['comision_usuario']?.toString() ?? '0') ?? 0.0;
      return sum + val;
    });

    final formatter = NumberFormat.simpleCurrency(decimalDigits: 0, name: 'CLP');

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Servicios',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            Text(
              'Mi historial de atención',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Summary Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COMISIONES POR COBRAR',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatter.format(totalACobrar),
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Historial Acumulado: ${formatter.format(totalEstimado)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Filters
            Container(
              height: 48,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                children: [
                  _buildFilterChip(
                    filterKey: 'all',
                    label: 'Todos (${_servicios.length})',
                    accentColor: accentColor,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    filterKey: 'pendiente',
                    label: 'En Proceso (${pendientes.length})',
                    accentColor: accentColor,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    filterKey: 'pagado',
                    label: 'Por Cobrar (${finalizados.length})',
                    accentColor: accentColor,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    filterKey: 'cobrado',
                    label: 'Cobrados (${cobrados.length})',
                    accentColor: accentColor,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textSecondary: textSecondary,
                  ),
                ],
              ),
            ),

            // Services list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: accentColor))
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _error!,
                                  style: GoogleFonts.inter(color: Colors.redAccent),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: accentColor),
                                  onPressed: () => _fetchServicios(),
                                  child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _fetchServicios(isManual: true),
                          color: accentColor,
                          backgroundColor: cardBg,
                          child: _filteredServicios.isEmpty
                              ? ListView(
                                  children: [
                                    SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                                    Center(
                                      child: Container(
                                        padding: const EdgeInsets.all(24),
                                        margin: const EdgeInsets.symmetric(horizontal: 40),
                                        decoration: BoxDecoration(
                                          color: cardBg,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: borderColor),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(Icons.diamond_outlined, size: 48, color: textSecondary.withValues(alpha: 0.5)),
                                            const SizedBox(height: 16),
                                            Text(
                                              'No hay servicios aquí',
                                              style: GoogleFonts.inter(
                                                color: textSecondary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  itemCount: _filteredServicios.length,
                                  itemBuilder: (context, index) {
                                    final item = _filteredServicios[index];
                                    return ServiceCard(
                                      item: item,
                                      index: index,
                                      onPress: (srv) {
                                        ServiceDetailModal.show(
                                          context: context,
                                          servicio: srv,
                                        );
                                      },
                                      onAssistance: _onConfirmAssistance,
                                    );
                                  },
                                ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String filterKey,
    required String label,
    required Color accentColor,
    required Color cardBg,
    required Color borderColor,
    required Color textSecondary,
  }) {
    final isSelected = _filter == filterKey;
    return InkWell(
      onTap: () {
        setState(() {
          _filter = filterKey;
        });
      },
      borderRadius: BorderRadius.circular(9999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : cardBg,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: isSelected ? accentColor : borderColor),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : textSecondary,
          ),
        ),
      ),
    );
  }
}
