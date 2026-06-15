import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../auth/data/auth_notifier.dart';
import '../../auth/domain/user.dart';

class Event {
  final String type;
  final String id;
  final String codigo;
  final DateTime date;
  final double amount;
  final int estado;
  final String? subType;

  Event({
    required this.type,
    required this.id,
    required this.codigo,
    required this.date,
    required this.amount,
    required this.estado,
    this.subType,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      type: json['type'] ?? json['tipo'] ?? 'otro',
      id: (json['id'] ?? '').toString(),
      codigo: json['codigo'] ?? '',
      date: DateTime.tryParse(json['date'] ?? json['fecha'] ?? '') ?? DateTime.now(),
      amount: double.tryParse(json['amount']?.toString() ?? json['monto']?.toString() ?? '0') ?? 0.0,
      estado: int.tryParse(json['estado']?.toString() ?? '0') ?? 0,
      subType: json['subType'] ?? json['sub_tipo'],
    );
  }
}

class CajeroAdministrativoScreen extends ConsumerStatefulWidget {
  const CajeroAdministrativoScreen({super.key});

  @override
  ConsumerState<CajeroAdministrativoScreen> createState() => _CajeroAdministrativoScreenState();
}

class _CajeroAdministrativoScreenState extends ConsumerState<CajeroAdministrativoScreen> {
  bool _loading = true;
  List<Event> _events = [];
  final List<String> _selectedDates = [];
  DateTime _currentMonth = DateTime.now();
  Event? _selectedEvent;
  Map<String, dynamic>? _eventDetail;
  bool _loadingDetail = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData({bool isManual = false}) async {
    if (!isManual) {
      setState(() => _loading = true);
    }
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.get('/events/user');
      
      if (response.data != null && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        setState(() {
          _events = data.map((json) => Event.fromJson(json)).toList();
          _loading = false;
        });
        if (isManual && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Resumen actualizado con éxito')),
          );
        }
      } else {
        throw Exception(response.data?['message'] ?? 'Error al cargar datos');
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
    }
  }

  Future<void> _handleSelectEvent(Event event) async {
    setState(() {
      _selectedEvent = event;
      _eventDetail = null;
      _loadingDetail = true;
    });

    try {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.get('/events/detail/${event.id}?type=${event.type}');
      
      if (mounted && response.data != null && response.data['success'] == true) {
        setState(() {
          _eventDetail = response.data['data'];
          _loadingDetail = false;
        });
      } else {
        setState(() => _loadingDetail = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingDetail = false);
      }
    }
  }

  double get _totalCalculated {
    return _events.fold(0.0, (sum, item) {
      if (item.estado != 1) return sum;
      if (item.type == 'anticipo') return sum - item.amount;
      return sum + item.amount;
    });
  }

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);
    return format.format(amount);
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Map<String, List<Event>> get _eventsByDate {
    final Map<String, List<Event>> map = {};
    for (var event in _events) {
      final key = _getDateKey(event.date);
      map.putIfAbsent(key, () => []).add(event);
    }
    return map;
  }

  List<DateTime> get _calendarDays {
    final days = <DateTime>[];
    final year = _currentMonth.year;
    final month = _currentMonth.month;
    final firstDay = DateTime(year, month, 1);
    
    // Sunday start offset
    final offset = firstDay.weekday % 7;
    final prevMonthLast = DateTime(year, month, 0);
    for (int i = offset - 1; i >= 0; i--) {
      days.add(DateTime(year, month - 1, prevMonthLast.day - i));
    }
    
    final daysCount = DateTime(year, month + 1, 0).day;
    for (int i = 1; i <= daysCount; i++) {
      days.add(DateTime(year, month, i));
    }
    
    final remaining = 42 - days.length;
    for (int i = 1; i <= remaining; i++) {
      days.add(DateTime(year, month + 1, i));
    }
    
    return days;
  }

  String _getEventLabel(Event item) {
    if (item.type == 'comision') {
      if (item.subType == 'venta') return "Comisión de Venta";
      if (item.subType == 'servicio') return "Comisión de Servicio";
      return "Comisión";
    }
    if (item.type == 'propina') {
      if (item.subType == 'venta') return "Propina de Venta";
      return "Propina";
    }
    final labels = {
      'asistencia': 'Asistencia',
      'anticipo': 'Anticipo',
      'venta': 'Venta',
      'servicio': 'Servicio',
      'gratificacion': 'Gratificación',
      'hora_extra': 'Hora Extra'
    };
    return labels[item.type] ?? item.type.toUpperCase();
  }

  Color _getEventTypeColor(String type) {
    switch (type) {
      case 'asistencia': return Colors.blue;
      case 'anticipo': return Colors.red;
      case 'propina': return Colors.amber;
      case 'hora_extra': return Colors.purple;
      case 'comision': return Colors.green;
      case 'servicio': return AppTheme.primaryColor;
      case 'gratificacion': return Colors.pink;
      default: return Colors.grey;
    }
  }

  String _getStatusLabel(int estado, String type) {
    if (type == 'anticipo') {
      if (estado == 0) return 'Pagado';
      if (estado == 1) return 'Confirmado';
      if (estado == 2) return 'Pendiente';
      if (estado == 3) return 'Rechazado';
    }
    if (estado == 0) return 'Pagado';
    if (estado == 1) return 'Por cobrar';
    if (estado == 2) return 'Confirmado';
    if (estado == 3) return 'Rechazado';
    if (estado == 4) return 'Completado';
    return estado.toString();
  }

  void _exportReportText(User? user) {
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final title = 'Las Muñecas de Ramón - Reporte de Liquidación';
    final userLabel = 'Cajero: ${user?.nombre ?? ''} (${user?.email ?? ''})';
    
    final buffer = StringBuffer();
    buffer.writeln('==============================================');
    buffer.writeln(title);
    buffer.writeln('Generado el: $formattedDate');
    buffer.writeln(userLabel);
    buffer.writeln('==============================================\n');
    buffer.writeln('DETALLE DE EVENTOS:');
    buffer.writeln('----------------------------------------------');
    
    for (var event in _events) {
      final dateStr = DateFormat('dd/MM/yy HH:mm').format(event.date);
      final typeLabel = _getEventLabel(event).toUpperCase();
      final statusLabel = _getStatusLabel(event.estado, event.type).toUpperCase();
      final amountSign = event.type == 'anticipo' ? '-' : '+';
      buffer.writeln('$dateStr | $typeLabel | Cod: ${event.codigo} | $statusLabel | $amountSign${_formatCurrency(event.amount)}');
    }
    
    buffer.writeln('----------------------------------------------');
    buffer.writeln('TOTAL A COBRAR: ${_formatCurrency(_totalCalculated)}');
    buffer.writeln('==============================================');

    final textReport = buffer.toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurfaceColor,
        title: Text('Previsualización del Reporte', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              textReport,
              style: GoogleFonts.robotoMono(fontSize: 12, color: AppTheme.darkTextPrimary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar', style: GoogleFonts.inter(color: Colors.white70)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: textReport));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reporte copiado al portapapeles')),
              );
            },
            icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
            label: Text('Copiar Texto', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _showEventsDetailsModal() {
    final selectedEvents = _events.where((e) {
      final dateStr = _getDateKey(e.date);
      return _selectedDates.contains(dateStr);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkBgColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              maxChildSize: 0.9,
              minChildSize: 0.5,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Eventos Seleccionados',
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${_selectedDates.length} ${_selectedDates.length == 1 ? 'día' : 'días'} · ${selectedEvents.length} eventos',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppTheme.darkTextSecondary,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.grey[850],
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 20),
                            ),
                          )
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white10),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                        itemCount: selectedEvents.isEmpty ? 1 : selectedEvents.length,
                        itemBuilder: (context, index) {
                          if (selectedEvents.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 60.0),
                                child: Column(
                                  children: [
                                    Icon(Icons.calendar_today_rounded, size: 48, color: AppTheme.darkTextSecondary),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Sin eventos en los días seleccionados',
                                      style: GoogleFonts.inter(color: AppTheme.darkTextSecondary, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final event = selectedEvents[index];
                          final isAnticipo = event.type == 'anticipo';
                          final color = _getEventTypeColor(event.type);
                          
                          IconData getIcon(String t) {
                            if (t == 'venta') return Icons.fastfood_rounded;
                            if (t == 'propina') return Icons.wallet_rounded;
                            if (t == 'comision') return Icons.star_rounded;
                            if (t == 'asistencia') return Icons.calendar_today_rounded;
                            return Icons.monetization_on_rounded;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.darkSurfaceColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            child: ListTile(
                              onTap: () async {
                                Navigator.pop(context);
                                await _handleSelectEvent(event);
                                if (mounted) {
                                  _showEventDetailsDialog();
                                }
                              },
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(getIcon(event.type), color: color, size: 20),
                              ),
                              title: Text(
                                '${_getEventLabel(event)} ${event.codigo.isNotEmpty && event.codigo != 'TIPS' ? '- ${event.codigo}' : ''}',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                              ),
                              subtitle: Text(
                                DateFormat('dd/MM/yyyy HH:mm').format(event.date),
                                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.darkTextSecondary),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isAnticipo ? '-' : '+'}${_formatCurrency(event.amount)}',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isAnticipo ? Colors.red : Colors.green,
                                    ),
                                  ),
                                  Text(
                                    _getStatusLabel(event.estado, event.type),
                                    style: GoogleFonts.inter(fontSize: 10, color: AppTheme.darkTextSecondary, fontWeight: FontWeight.bold),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showEventDetailsDialog() {
    if (_selectedEvent == null) return;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isAnticipo = _selectedEvent!.type == 'anticipo';
            final color = _getEventTypeColor(_selectedEvent!.type);
            
            return AlertDialog(
              backgroundColor: AppTheme.darkSurfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.all(16),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              actionsPadding: const EdgeInsets.all(12),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Detalle del Evento',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: _loadingDetail
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.0),
                        child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _selectedEvent!.type == 'venta'
                                        ? Icons.fastfood_rounded
                                        : _selectedEvent!.type == 'propina'
                                            ? Icons.wallet_rounded
                                            : _selectedEvent!.type == 'comision'
                                                ? Icons.star_rounded
                                                : Icons.monetization_on_rounded,
                                    color: color,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _getEventLabel(_selectedEvent!),
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${isAnticipo ? '-' : '+'}${_formatCurrency(_selectedEvent!.amount)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: isAnticipo ? Colors.red : Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                          _buildDetailRow('Código', _selectedEvent!.codigo.isNotEmpty ? _selectedEvent!.codigo : 'N/A'),
                          _buildDetailRow('Fecha', DateFormat('dd/MM/yyyy HH:mm').format(_selectedEvent!.date)),
                          _buildDetailRow('Estado', _getStatusLabel(_selectedEvent!.estado, _selectedEvent!.type)),
                          
                          if (_eventDetail != null) ...[
                            const Divider(color: Colors.white10, height: 24),
                            Text(
                              'Información Adicional',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            if (_selectedEvent!.type == 'asistencia') ...[
                              _buildDetailRow('Hora Entrada', _eventDetail!['hora_entrada'] ?? 'N/A'),
                              _buildDetailRow('Hora Salida', _eventDetail!['hora_salida'] ?? 'N/A'),
                              _buildDetailRow('Observación', _eventDetail!['observaciones'] ?? 'Ninguna'),
                            ],
                            if (_selectedEvent!.type == 'anticipo') ...[
                              _buildDetailRow('Aprobado por', _eventDetail!['aprobado_por'] ?? 'N/A'),
                              _buildDetailRow('Glosa', _eventDetail!['descripcion'] ?? 'N/A'),
                            ],
                            if (_selectedEvent!.type == 'comision' || _selectedEvent!.type == 'propina') ...[
                              _buildDetailRow('Detalle', _eventDetail!['descripcion'] ?? _eventDetail!['detalle'] ?? 'N/A'),
                              _buildDetailRow('Referencia', _eventDetail!['referencia'] ?? 'N/A'),
                            ],
                          ],
                          const SizedBox(height: 12),
                        ],
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cerrar', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold)),
                )
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSkeletonGrid() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const SizedBox(height: 100),
          const SkeletonCard(lines: 2),
          const SizedBox(height: 16),
          const SkeletonCard(lines: 5),
          const SizedBox(height: 16),
          ...List.generate(5, (i) => const SkeletonCard(showAvatar: true, lines: 2)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.darkTextSecondary)),
          Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    final monthLabel = DateFormat('MMMM yyyy', 'es_ES').format(_currentMonth);

    return Scaffold(
      backgroundColor: AppTheme.darkBgColor,
      body: _loading
          ? _buildSkeletonGrid()
          : RefreshIndicator(
              onRefresh: () => _fetchData(isManual: true),
              color: AppTheme.primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: AppTheme.darkSurfaceColor,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(32),
                          bottomRight: Radius.circular(32),
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                              Column(
                                children: [
                                  Text(
                                    'Resumen Administrativo',
                                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  Text(
                                    'Actividad y eventos',
                                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.darkTextSecondary),
                                  )
                                ],
                              ),
                              const SizedBox(width: 40),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Liquidation Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurfaceColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TOTAL A COBRAR',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.darkTextSecondary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatCurrency(_totalCalculated),
                                    style: GoogleFonts.inter(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                              ),
                              onPressed: () => _exportReportText(user),
                              icon: const Icon(Icons.description_rounded, size: 18),
                              label: Text('Reportes', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Calendar Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurfaceColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          children: [
                            // Calendar Top Navigation
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  monthLabel[0].toUpperCase() + monthLabel.substring(1),
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                                      onPressed: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1)),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.chevron_right, color: Colors.white),
                                      onPressed: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1)),
                                    )
                                  ],
                                )
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Weekdays
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: ['D', 'L', 'M', 'M', 'J', 'V', 'S'].map((day) {
                                return SizedBox(
                                  width: 40,
                                  child: Text(
                                    day,
                                    style: GoogleFonts.inter(color: AppTheme.darkTextSecondary, fontWeight: FontWeight.bold, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 10),
                            // Calendar Days Grid
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: 42,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                              ),
                              itemBuilder: (context, index) {
                                final day = _calendarDays[index];
                                final isCurrentMonth = day.month == _currentMonth.month;
                                final isToday = DateFormat('yyyymmdd').format(day) == DateFormat('yyyymmdd').format(DateTime.now());
                                final dateStr = _getDateKey(day);
                                final isSelected = _selectedDates.contains(dateStr);
                                
                                final dayEvents = _eventsByDate[dateStr] ?? [];
                                final uniqueTypes = dayEvents.map((e) => e.type).toSet().toList();
                                final visibleTypes = uniqueTypes.take(3).toList();

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedDates.remove(dateStr);
                                      } else {
                                        _selectedDates.add(dateStr);
                                      }
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isToday && !isSelected
                                            ? AppTheme.primaryColor
                                            : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          day.day.toString(),
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? Colors.white
                                                : isCurrentMonth
                                                    ? Colors.white
                                                    : AppTheme.darkTextSecondary.withValues(alpha: 0.4),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        if (uniqueTypes.isNotEmpty)
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: visibleTypes.map((type) {
                                              return Container(
                                                width: 4,
                                                height: 4,
                                                margin: const EdgeInsets.symmetric(horizontal: 0.5),
                                                decoration: BoxDecoration(
                                                  color: isSelected ? Colors.white : _getEventTypeColor(type),
                                                  shape: BoxShape.circle,
                                                ),
                                              );
                                            }).toList(),
                                          )
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 16),
                            // Legend
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                _buildLegendItem('Asistencia', Colors.blue),
                                _buildLegendItem('Anticipo', Colors.red),
                                _buildLegendItem('Propina', Colors.amber),
                                _buildLegendItem('Hora extra', Colors.purple),
                                _buildLegendItem('Comisión', Colors.green),
                                _buildLegendItem('Servicio', AppTheme.primaryColor),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _selectedDates.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: AppTheme.darkSurfaceColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selectedDates.length} ${_selectedDates.length == 1 ? 'día' : 'días'} seleccionados',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _selectedDates.clear()),
                        child: Text('Borrar', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _showEventsDetailsModal,
                        child: Text(
                          'Ver Detalles',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      )
                    ],
                  )
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.darkTextSecondary, fontWeight: FontWeight.w500),
        )
      ],
    );
  }
}
