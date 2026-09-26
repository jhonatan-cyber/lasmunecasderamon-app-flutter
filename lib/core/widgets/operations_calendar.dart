import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../report_service.dart';
import '../theme.dart';
import 'currency_text.dart';
import 'event_detail_modal.dart';

/// Clave de fecha (`yyyy-MM-dd`) del calendario operativo. Se usan los
/// componentes del `DateTime` tal cual llegan de `/events/user` (el backend
/// serializa los timestamps con `Z`, y el ISO se parsea como UTC), igual que el
/// `getDateKey` de `PremiumCalendar` en Expo: la fecha del evento es la misma
/// que quedó guardada en la BD.
String calendarDateKey(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// Colores por tipo de evento (mismos hex que `PremiumCalendar` de Expo). El
/// tipo `servicio` usa el color de acento del tema y se resuelve al dibujar.
const Map<String, Color> operationsEventTypeColors = {
  'asistencia': Color(0xFF3B82F6),
  'anticipo': Color(0xFFEF4444),
  'propina': Color(0xFFF59E0B),
  'hora_extra': Color(0xFF8B5CF6),
  'comision': Color(0xFF10B981),
  'gratificacion': Color(0xFFEC4899),
};

/// Etiquetas de la leyenda (mismas que Expo, con la tilde que le falta al
/// `charAt(0).toUpperCase()` de JS).
const Map<String, String> operationsEventTypeLabels = {
  'asistencia': 'Asistencia',
  'anticipo': 'Anticipo',
  'propina': 'Propina',
  'hora_extra': 'Hora extra',
  'comision': 'Comisión',
  'servicio': 'Servicio',
  'gratificacion': 'Gratificación',
};

const List<String> _weekDayLabels = ['DO', 'LU', 'MA', 'MI', 'JU', 'VI', 'SÁ'];

/// Calendario operativo del home — espejo de `PremiumCalendar` de Expo: mes
/// navegable, puntos por tipo de evento (hasta 3 + «más») y leyenda. La
/// selección es múltiple: cada toque agrega/quita el día.
class OperationsCalendar extends StatefulWidget {
  const OperationsCalendar({
    super.key,
    required this.events,
    required this.selectedDates,
    required this.onDateToggle,
    this.currentMonth,
    this.onMonthChange,
  });

  final List<LiquidationEvent> events;
  final Set<String> selectedDates;
  final ValueChanged<String> onDateToggle;

  /// Mes visible. Si el padre la controla (misma pareja `currentMonth` /
  /// `onMonthChange` que `PremiumCalendar` en Expo) debe escuchar
  /// [onMonthChange], que notifica cada cambio de mes para que recargue los
  /// eventos del rango (`/events/user?startDate&endDate`). Sin [currentMonth]
  /// el widget mantiene el mes en su estado interno.
  final DateTime? currentMonth;
  final ValueChanged<DateTime>? onMonthChange;

  @override
  State<OperationsCalendar> createState() => _OperationsCalendarState();
}

class _OperationsCalendarState extends State<OperationsCalendar> {
  DateTime _internalMonth = DateTime.now();

  DateTime get _currentMonth => widget.currentMonth ?? _internalMonth;

  void _changeMonth(int delta) {
    final base = _currentMonth;
    final next = DateTime(base.year, base.month + delta, 1);
    // Con mes controlado el padre (que recarga los eventos) hace el setState;
    // sin control el widget guarda el mes en su estado interno.
    if (widget.currentMonth == null) {
      setState(() => _internalMonth = next);
    }
    widget.onMonthChange?.call(next);
  }

  /// Tipos de evento por día (sin repetir), para los puntos de colores.
  Map<String, List<String>> get _typesByDate {
    final map = <String, List<String>>{};
    for (final event in widget.events) {
      final key = calendarDateKey(event.date);
      final types = map.putIfAbsent(key, () => <String>[]);
      if (!types.contains(event.type)) types.add(event.type);
    }
    return map;
  }

  /// 42 celdas empezando en domingo, con los días de los meses vecinos.
  List<DateTime> get _calendarDays {
    final days = <DateTime>[];
    final year = _currentMonth.year;
    final month = _currentMonth.month;
    // Offset = columna del día 1 (domingo = 0).
    final offset = DateTime(year, month, 1).weekday % 7;
    for (int i = offset; i > 0; i--) {
      days.add(DateTime(year, month, 1 - i));
    }
    final daysInMonth = DateTime(year, month + 1, 0).day;
    for (int i = 1; i <= daysInMonth; i++) {
      days.add(DateTime(year, month, i));
    }
    while (days.length < 42) {
      final next = days.length - offset - daysInMonth + 1;
      days.add(DateTime(year, month + 1, next));
    }
    return days;
  }

  Color _colorFor(String type, Color accent) {
    return operationsEventTypeColors[type] ?? accent;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textPrimary = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final textSecondary = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;
    final typesByDate = _typesByDate;
    final today = DateTime.now();
    final monthLabel = DateFormat('MMMM yyyy', 'es_CL').format(_currentMonth);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthLabel.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
              Row(
                children: [
                  _navButton(
                    key: const Key('calendar-nav-prev'),
                    icon: Icons.chevron_left_rounded,
                    label: 'Mes anterior',
                    color: textPrimary,
                    onPressed: () => _changeMonth(-1),
                  ),
                  _navButton(
                    key: const Key('calendar-nav-next'),
                    icon: Icons.chevron_right_rounded,
                    label: 'Mes siguiente',
                    color: textPrimary,
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: _weekDayLabels
                .map(
                  (day) => Expanded(
                    child: Text(
                      day,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: textSecondary,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _calendarDays.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final day = _calendarDays[index];
              final dateKey = calendarDateKey(day);
              final isSelected = widget.selectedDates.contains(dateKey);
              final isToday =
                  day.year == today.year &&
                  day.month == today.month &&
                  day.day == today.day;
              final isCurrentMonth =
                  day.month == _currentMonth.month &&
                  day.year == _currentMonth.year;
              final types = typesByDate[dateKey] ?? const <String>[];
              final visibleTypes = types.take(3).toList();

              return InkWell(
                key: Key('calendar-day-$dateKey'),
                onTap: () => widget.onDateToggle(dateKey),
                customBorder: const CircleBorder(),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isSelected)
                      Container(
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Text(
                      '${day.day}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isSelected || isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : isToday
                            ? accent
                            : isCurrentMonth
                            ? textPrimary
                            : textSecondary.withValues(alpha: 0.6),
                      ),
                    ),
                    if (types.isNotEmpty)
                      Positioned(
                        bottom: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...visibleTypes.map(
                              (type) => Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white
                                      : _colorFor(type, accent),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            // Cuarto color en adelante: punto apagado «+».
                            if (types.length > visibleTypes.length)
                              Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white
                                      : textSecondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: operationsEventTypeLabels.entries
                .map(
                  (entry) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _colorFor(entry.key, accent),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        entry.value,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _navButton({
    required Key key,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      key: key,
      onPressed: onPressed,
      tooltip: label,
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: color),
    );
  }
}

/// Barra de resumen de la selección del calendario (paridad con el bloque
/// `selectionFloat` de `HomeScreen` en Expo: «N seleccionados» + DETALLES).
class SelectedDaysBar extends StatelessWidget {
  const SelectedDaysBar({
    super.key,
    required this.count,
    required this.onDetails,
  });

  final int count;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$count ${count == 1 ? 'día seleccionado' : 'días seleccionados'}',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              TextButton(
                onPressed: onDetails,
                child: Text(
                  'Detalles',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Eventos de los días seleccionados en el calendario, ordenados del más
/// reciente al más antiguo (paridad con el modal «Eventos» de Expo).
List<LiquidationEvent> eventsForDates(
  List<LiquidationEvent> events,
  Set<String> selectedDates,
) {
  final selected = events
      .where((event) => selectedDates.contains(calendarDateKey(event.date)))
      .toList();
  selected.sort((a, b) => b.date.compareTo(a.date));
  return selected;
}

/// Hoja con el detalle de los días seleccionados (evento, código y monto).
/// Tocar una fila abre el detalle del evento (`GET /events/detail`), igual que
/// el modal «Eventos» de Expo sobre el `EventDetailModal`.
Future<void> showSelectedEventsSheet(
  BuildContext context, {
  required List<LiquidationEvent> events,
  required Set<String> selectedDates,
  String? userRole,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final accent = Theme.of(context).colorScheme.primary;
  final textSecondary = isDark
      ? AppTheme.darkTextSecondary
      : AppTheme.lightTextSecondary;
  final selected = eventsForDates(events, selectedDates);
  final dateFormat = DateFormat('dd/MM/yy HH:mm');

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Eventos',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: selected.isEmpty
                    ? Center(
                        child: Text(
                          'Sin eventos en los días seleccionados',
                          style: GoogleFonts.inter(color: textSecondary),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: selected.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final event = selected[index];
                          return Material(
                            color: isDark
                                ? AppTheme.darkSurfaceColor
                                : AppTheme.lightSurfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => showEventDetailModal(
                                context,
                                event,
                                userRole: userRole,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark
                                        ? AppTheme.darkBorderColor
                                        : AppTheme.lightBorderColor,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            event.label,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${dateFormat.format(event.date)}'
                                            '${event.codigo.isEmpty ? '' : ' · ${event.codigo}'}',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${event.isAnticipo ? '-' : '+'}'
                                      '${formatCurrency(event.amount)}',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: event.isAnticipo
                                            ? Colors.redAccent
                                            : accent,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                      color: textSecondary,
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
}
