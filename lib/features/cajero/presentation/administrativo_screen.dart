import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/report_service.dart';
import '../../../core/theme.dart';
import '../../../core/hooks/refresh_provider.dart';
import '../../../core/widgets/event_detail_modal.dart';
import '../../../core/widgets/liquidation_export.dart';
import '../../../core/widgets/operations_calendar.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../auth/data/auth_notifier.dart';

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
      date:
          DateTime.tryParse(json['date'] ?? json['fecha'] ?? '') ??
          DateTime.now(),
      amount:
          double.tryParse(
            json['amount']?.toString() ?? json['monto']?.toString() ?? '0',
          ) ??
          0.0,
      estado: int.tryParse(json['estado']?.toString() ?? '0') ?? 0,
      subType: json['subType'] ?? json['sub_tipo'],
    );
  }

  /// Normaliza el evento para el export de liquidación (misma regla de total
  /// que la tarjeta de Expo: estado != 1 se ignora y los anticipos restan).
  LiquidationEvent toLiquidationEvent() {
    return LiquidationEvent(
      id: id,
      type: type,
      subType: subType,
      codigo: codigo,
      date: date,
      amount: amount,
      estado: estado,
    );
  }
}

class CajeroAdministrativoScreen extends ConsumerStatefulWidget {
  const CajeroAdministrativoScreen({super.key});

  @override
  ConsumerState<CajeroAdministrativoScreen> createState() =>
      _CajeroAdministrativoScreenState();
}

class _CajeroAdministrativoScreenState
    extends ConsumerState<CajeroAdministrativoScreen> {
  List<Event> _events = [];
  // Multi-selección de días del calendario: misma forma que en los otros
  // roles (`OperationsCalendar` trabaja con un Set de claves yyyy-MM-dd).
  final Set<String> _selectedDates = {};
  DateTime _currentMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchData());
  }

  Future<void> _fetchData({bool isManual = false}) async {
    final notifier = ref.read(refreshProvider('administrativo').notifier);
    if (!isManual) {
      notifier.startRefresh(isManual: false);
    }
    try {
      final client = ref.read(apiClientProvider);
      final startDate = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(_currentMonth.year, _currentMonth.month, 1));
      final endDate = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(_currentMonth.year, _currentMonth.month + 1, 0));

      final response = await client.dio.get(
        '/events/user',
        queryParameters: {'startDate': startDate, 'endDate': endDate},
      );

      if (response.data != null && response.data['success'] == true) {
        if (!mounted) return;
        final List<dynamic> data = response.data['data'] ?? [];
        setState(() {
          _events = data.map((json) => Event.fromJson(json)).toList();
        });
        notifier.endRefresh();
        if (isManual) {
          notifier.showSuccessSnack(context, 'Resumen actualizado con éxito');
        }
      } else {
        throw Exception(response.data?['message'] ?? 'Error al cargar datos');
      }
    } catch (e) {
      if (!mounted) return;
      notifier.endRefresh(error: 'Error al cargar datos');
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
    final format = NumberFormat.currency(
      locale: 'es_CL',
      symbol: '\$',
      decimalDigits: 0,
    );
    return format.format(amount);
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
      'hora_extra': 'Hora Extra',
    };
    return labels[item.type] ?? item.type.toUpperCase();
  }

  Color _getEventTypeColor(String type) {
    switch (type) {
      case 'asistencia':
        return Colors.blue;
      case 'anticipo':
        return Colors.red;
      case 'propina':
        return Colors.amber;
      case 'hora_extra':
        return Colors.purple;
      case 'comision':
        return Colors.green;
      case 'servicio':
        return Theme.of(context).colorScheme.primary;
      case 'gratificacion':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  /// Misma nomenclatura que el detalle de eventos y el reporte
  /// (`liquidationStatusLabel`).
  String _getStatusLabel(int estado, String type) =>
      liquidationStatusLabel(estado, type);

  void _showEventsDetailsModal() {
    final selectedEvents = _events.where((e) {
      final dateStr = calendarDateKey(e.date);
      return _selectedDates.contains(dateStr);
    }).toList()..sort((a, b) => b.date.compareTo(a.date));

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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 8.0,
                      ),
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
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white10),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 10.0,
                        ),
                        itemCount: selectedEvents.isEmpty
                            ? 1
                            : selectedEvents.length,
                        itemBuilder: (context, index) {
                          if (selectedEvents.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 60.0,
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 48,
                                      color: AppTheme.darkTextSecondary,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Sin eventos en los días seleccionados',
                                      style: GoogleFonts.inter(
                                        color: AppTheme.darkTextSecondary,
                                        fontSize: 14,
                                      ),
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
                            if (t == 'asistencia') {
                              return Icons.calendar_today_rounded;
                            }
                            return Icons.monetization_on_rounded;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            // El ListTile pinta fondo y splashes en el Material
                            // más cercano: sin él Flutter avisa y el toque no
                            // da feedback.
                            child: Material(
                              color: AppTheme.darkSurfaceColor,
                              borderRadius: BorderRadius.circular(16),
                              child: ListTile(
                                onTap: () {
                                  // Detalle compartido con los homes (mismo fetch
                                  // de /events/detail y mismas claves reales);
                                  // la hoja queda abierta debajo, como en Expo y
                                  // en el calendario de garzón/anfitriona/barman.
                                  showEventDetailModal(
                                    context,
                                    event.toLiquidationEvent(),
                                    userRole: ref.read(authProvider).user?.role,
                                    forceDark: true,
                                  );
                                },
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    getIcon(event.type),
                                    color: color,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  '${_getEventLabel(event)} ${event.codigo.isNotEmpty && event.codigo != 'TIPS' ? '- ${event.codigo}' : ''}',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                                subtitle: Text(
                                  DateFormat(
                                    'dd/MM/yyyy HH:mm',
                                  ).format(event.date),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppTheme.darkTextSecondary,
                                  ),
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
                                        color: isAnticipo
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    ),
                                    Text(
                                      _getStatusLabel(event.estado, event.type),
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: AppTheme.darkTextSecondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
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

  Widget _buildSkeletonGrid() {
    return ShimmerWrapper(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 100),
            const SkeletonCard(lines: 2),
            const SizedBox(height: 16),
            const SkeletonCard(lines: 5),
            const SizedBox(height: 16),
            ...List.generate(
              5,
              (i) => const SkeletonCard(showAvatar: true, lines: 2),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    final refresh = ref.watch(refreshProvider('administrativo'));

    return Scaffold(
      backgroundColor: AppTheme.darkBgColor,
      body: FadeLoadingSwitcher(
        isLoading: refresh.isLoading,
        skeleton: _buildSkeletonGrid(),
        content: RefreshIndicator(
          onRefresh: () => _fetchData(isManual: true),
          color: Theme.of(context).colorScheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 20.0,
                      ),
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
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                          Column(
                            children: [
                              Text(
                                'Resumen Personal',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Actividad y eventos',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.darkTextSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 40),
                        ],
                      ),
                    ),
                  ),
                ),

                // Enlace a Horas Extras (paridad con Expo: mismo acceso en
                // Resumen Personal → /cajero/horas-extras).
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Material(
                    color: AppTheme.darkSurfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => context.push('/cajero/horas-extras'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Horas Extras',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Control de jornada',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.darkTextSecondary,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.darkTextSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurfaceColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
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
                                  color: AppTheme.successColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Export real a PDF (paridad con el botón «Reportes»
                        // de PremiumLiquidationCard en Expo: mismo detalle de
                        // eventos, mismo total y hoja de compartir).
                        LiquidationExportButton(
                          dense: true,
                          events: _events
                              .map((event) => event.toLiquidationEvent())
                              .toList(),
                          userLabel: liquidationUserLabel(
                            user?.nombre ?? '',
                            nick: user?.nick ?? '',
                          ),
                          totalAmount: _totalCalculated,
                        ),
                      ],
                    ),
                  ),
                ),

                if (_selectedDates.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.darkSurfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_selectedDates.length} ${_selectedDates.length == 1 ? 'día' : 'días'} seleccionados',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () =>
                                    setState(() => _selectedDates.clear()),
                                child: Text(
                                  'Borrar',
                                  style: GoogleFonts.inter(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _showEventsDetailsModal,
                                child: Text(
                                  'Ver Detalles',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  const SizedBox(height: 16),
                ],

                // Calendario operativo compartido: el mismo OperationsCalendar
                // que usan garzón, anfitriona y barman (espejo de
                // PremiumCalendar de Expo). Esta pantalla es dark-only, así que
                // se fuerza la paleta oscura aunque el tema global esté en
                // claro; el mes lo controla esta pantalla para refiltrar
                // /events/user como en Expo.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Theme(
                    data: AppTheme.getTheme(
                      Brightness.dark,
                      Theme.of(context).colorScheme.primary,
                    ),
                    child: OperationsCalendar(
                      events: _events
                          .map((event) => event.toLiquidationEvent())
                          .toList(),
                      selectedDates: _selectedDates,
                      onDateToggle: (dateKey) {
                        setState(() {
                          if (!_selectedDates.remove(dateKey)) {
                            _selectedDates.add(dateKey);
                          }
                        });
                      },
                      currentMonth: _currentMonth,
                      onMonthChange: (date) {
                        setState(() {
                          _currentMonth = date;
                          _selectedDates.clear();
                        });
                        _fetchData();
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
