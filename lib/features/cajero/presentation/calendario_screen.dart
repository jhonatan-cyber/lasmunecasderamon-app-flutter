import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../auth/data/auth_notifier.dart';

class CalendarDay {
  final DateTime date;
  final bool isCurrentMonth;
  final bool isToday;
  final Map<String, bool> data;

  CalendarDay({
    required this.date,
    required this.isCurrentMonth,
    required this.isToday,
    required this.data,
  });
}

class ModalDataType {
  final String title;
  final String key;
  final IconData icon;
  final Color color;

  ModalDataType({
    required this.title,
    required this.key,
    required this.icon,
    required this.color,
  });
}

class CajeroCalendarioScreen extends ConsumerStatefulWidget {
  const CajeroCalendarioScreen({super.key});

  @override
  ConsumerState<CajeroCalendarioScreen> createState() => _CajeroCalendarioScreenState();
}

class _CajeroCalendarioScreenState extends ConsumerState<CajeroCalendarioScreen> {
  DateTime _currentDate = DateTime.now();
  bool _loading = true;
  List<DateTime> _selectedDates = [];
  String _selectedDataType = 'asistencias';
  List<dynamic> _selectedDateData = [];
  bool _isLoadingSelected = false;
  double _totalCobrar = 0;

  // Cached API data for the month
  List<dynamic> _asistencias = [];
  List<dynamic> _anticipos = [];
  List<dynamic> _propinas = [];
  List<dynamic> _horasExtras = [];

  final List<ModalDataType> _dataTypes = [
    ModalDataType(title: 'Asistencias', key: 'asistencias', icon: Icons.calendar_today_rounded, color: const Color(0xFF10B981)),
    ModalDataType(title: 'Anticipos', key: 'anticipos', icon: Icons.swap_horiz_rounded, color: const Color(0xFFEF4444)),
    ModalDataType(title: 'Propinas', key: 'propinas', icon: Icons.payments_rounded, color: const Color(0xFFF59E0B)),
    ModalDataType(title: 'Horas Extras', key: 'horasExtras', icon: Icons.access_time_rounded, color: const Color(0xFF8B5CF6)),
  ];

  @override
  void initState() {
    super.initState();
    _fetchCalendarData();
  }

  String _toDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _fetchCalendarData({bool isManual = false}) async {
    if (!isManual) {
      setState(() => _loading = true);
    }
    try {
      final client = ref.read(apiClientProvider);
      final year = _currentDate.year;
      final month = _currentDate.month;
      final startDate = '$year-${month.toString().padLeft(2, '0')}-01';
      final endDate = '$year-${month.toString().padLeft(2, '0')}-${DateTime(year, month + 1, 0).day}';

      final responses = await Future.wait([
        client.dio.get('/attendance/by-dates?startDate=$startDate&endDate=$endDate').catchError((_) => Response(requestOptions: RequestOptions())),
        client.dio.get('/anticipos/by-dates?startDate=$startDate&endDate=$endDate').catchError((_) => Response(requestOptions: RequestOptions())),
        client.dio.get('/tips/user?startDate=$startDate&endDate=$endDate').catchError((_) => Response(requestOptions: RequestOptions())),
        client.dio.get('/overtime/by-dates?startDate=$startDate&endDate=$endDate').catchError((_) => Response(requestOptions: RequestOptions())),
      ]);

      final asistList = responses[0].data != null && responses[0].data['success'] == true ? responses[0].data['data'] as List? ?? [] : [];
      final anticList = responses[1].data != null && responses[1].data['success'] == true ? responses[1].data['data'] as List? ?? [] : [];
      final propList = responses[2].data != null && responses[2].data['success'] == true ? responses[2].data['data'] as List? ?? [] : [];
      final heList = responses[3].data != null && responses[3].data['success'] == true ? responses[3].data['data'] as List? ?? [] : [];

      // Save lists for detail filters
      _asistencias = asistList;
      _anticipos = anticList;
      _propinas = propList;
      _horasExtras = heList;

      final asistDates = asistList.map((a) => _toDateKey(DateTime.tryParse(a['fecha'] ?? '') ?? DateTime.now())).toSet();
      final anticDates = anticList.map((a) => _toDateKey(DateTime.tryParse(a['fecha_crea'] ?? '') ?? DateTime.now())).toSet();
      final propDates = propList.map((p) => _toDateKey(DateTime.tryParse(p['fecha_crea'] ?? '') ?? DateTime.now())).toSet();
      final heDates = heList.map((h) => _toDateKey(DateTime.tryParse(h['fecha_crea'] ?? '') ?? DateTime.now())).toSet();

      final firstDay = DateTime(year, month, 1);
      final offset = firstDay.weekday % 7;
      final todayKey = _toDateKey(DateTime.now());

      final List<CalendarDay> calendarDays = [];

      // Prev Month Fill
      final prevMonthLast = DateTime(year, month, 0);
      for (int i = offset - 1; i >= 0; i--) {
        final d = DateTime(year, month - 1, prevMonthLast.day - i);
        final dk = _toDateKey(d);
        calendarDays.add(CalendarDay(
          date: d,
          isCurrentMonth: false,
          isToday: dk == todayKey,
          data: {
            'asistencias': asistDates.contains(dk),
            'anticipos': anticDates.contains(dk),
            'propinas': propDates.contains(dk),
            'horasExtras': heDates.contains(dk),
          },
        ));
      }

      // Current Month
      final currentMonthDays = DateTime(year, month + 1, 0).day;
      for (int i = 1; i <= currentMonthDays; i++) {
        final d = DateTime(year, month, i);
        final dk = _toDateKey(d);
        calendarDays.add(CalendarDay(
          date: d,
          isCurrentMonth: true,
          isToday: dk == todayKey,
          data: {
            'asistencias': asistDates.contains(dk),
            'anticipos': anticDates.contains(dk),
            'propinas': propDates.contains(dk),
            'horasExtras': heDates.contains(dk),
          },
        ));
      }

      // Next Month Fill
      final remaining = 42 - calendarDays.length;
      for (int i = 1; i <= remaining; i++) {
        final d = DateTime(year, month + 1, i);
        final dk = _toDateKey(d);
        calendarDays.add(CalendarDay(
          date: d,
          isCurrentMonth: false,
          isToday: dk == todayKey,
          data: {
            'asistencias': asistDates.contains(dk),
            'anticipos': anticDates.contains(dk),
            'propinas': propDates.contains(dk),
            'horasExtras': heDates.contains(dk),
          },
        ));
      }

      setState(() {
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
      });
    }
  }

  void _navigateMonth(int direction) {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month + direction, 1);
    });
    _fetchCalendarData();
  }

  void _goToToday() {
    setState(() {
      _currentDate = DateTime.now();
    });
    _fetchCalendarData();
  }

  void _handleDayPress(CalendarDay day) {
    setState(() {
      _selectedDates = [day.date];
      _selectedDataType = 'asistencias';
    });
    _updateSelectedDetails();
    _showDetailsModal();
  }

  void _updateSelectedDetails() {
    if (_selectedDates.isEmpty) return;
    setState(() => _isLoadingSelected = true);

    final sorted = [..._selectedDates]..sort((a, b) => a.compareTo(b));
    final startKey = _toDateKey(sorted.first);
    final endKey = _toDateKey(sorted.last);

    List<dynamic> filterByDate(List<dynamic> list, String dateField) {
      return list.where((item) {
        final parsed = DateTime.tryParse(item[dateField] ?? '');
        if (parsed == null) return false;
        final key = _toDateKey(parsed);
        return key.compareTo(startKey) >= 0 && key.compareTo(endKey) <= 0;
      }).toList();
    }

    final filteredAsist = filterByDate(_asistencias, 'fecha');
    final filteredAntic = filterByDate(_anticipos, 'fecha_crea');
    final filteredProp = filterByDate(_propinas, 'fecha_crea');
    final filteredHe = filterByDate(_horasExtras, 'fecha_crea');

    // Calculate total a cobrar
    double total = 0;
    // Asistencias (estado == 1)
    total += filteredAsist.where((a) => a['estado'] == 1).fold(0.0, (sum, a) => sum + (double.tryParse(a['sueldo_final']?.toString() ?? '0') ?? 0.0));
    // Propinas (estado == 1)
    total += filteredProp.where((p) => p['estado'] == 1).fold(0.0, (sum, p) => sum + (double.tryParse(p['monto']?.toString() ?? '0') ?? 0.0));
    // Horas Extras (estado == 1)
    total += filteredHe.where((h) => h['estado'] == 1).fold(0.0, (sum, h) => sum + (double.tryParse(h['total']?.toString() ?? '0') ?? 0.0));
    // Anticipos (estado == 1) subtracted
    total -= filteredAntic.where((a) => a['estado'] == 1).fold(0.0, (sum, a) => sum + (double.tryParse(a['monto']?.toString() ?? '0') ?? 0.0));

    setState(() {
      _totalCobrar = total;
      if (_selectedDataType == 'asistencias') _selectedDateData = filteredAsist;
      if (_selectedDataType == 'anticipos') _selectedDateData = filteredAntic;
      if (_selectedDataType == 'propinas') _selectedDateData = filteredProp;
      if (_selectedDataType == 'horasExtras') _selectedDateData = filteredHe;
      _isLoadingSelected = false;
    });
  }

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);
    return format.format(amount);
  }

  String _formatSimpleDate(String? dateStr) {
    if (dateStr == null) return '';
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return '';
    return DateFormat('dd/MM').format(parsed);
  }

  Map<String, dynamic> _getStatusBadge(int estado) {
    if (estado == 0) return {'label': 'PAGADO', 'color': Colors.green, 'bg': Colors.green.withValues(alpha: 0.15)};
    if (estado == 1) return {'label': 'POR PAGAR', 'color': Colors.red, 'bg': Colors.red.withValues(alpha: 0.15)};
    return {'label': 'Desconocido', 'color': Colors.grey, 'bg': Colors.grey.withValues(alpha: 0.15)};
  }

  void _showDetailsModal() {
    final formattedDate = _selectedDates.isNotEmpty
        ? DateFormat('dd MMMM yyyy', 'es_ES').format(_selectedDates.first)
        : '';

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
            final dataType = _dataTypes.firstWhere((dt) => dt.key == _selectedDataType);

            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              maxChildSize: 0.95,
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
                          Expanded(
                            child: Text(
                              formattedDate,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
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
                    
                    // Type Tabs scroll
                    SizedBox(
                      height: 55,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _dataTypes.length,
                        itemBuilder: (context, idx) {
                          final dt = _dataTypes[idx];
                          final isSelected = _selectedDataType == dt.key;

                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                _selectedDataType = dt.key;
                              });
                              _updateSelectedDetails();
                              setModalState(() {});
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: isSelected ? dt.color : Colors.transparent,
                                borderRadius: BorderRadius.circular(9999),
                                border: Border.all(color: isSelected ? dt.color : Colors.white10, width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  Icon(dt.icon, size: 14, color: isSelected ? Colors.white : dt.color),
                                  const SizedBox(width: 6),
                                  Text(
                                    dt.title,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : AppTheme.darkTextSecondary,
                                    ),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Total Banner
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total a Cobrar:',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.darkTextSecondary, fontSize: 13),
                            ),
                            Text(
                              _formatCurrency(_totalCobrar),
                              style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppTheme.primaryColor, fontSize: 18),
                            )
                          ],
                        ),
                      ),
                    ),

                    // List view
                    Expanded(
                      child: _isLoadingSelected
                          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                          : _selectedDateData.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(dataType.icon, size: 48, color: AppTheme.darkTextSecondary),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No hay ${dataType.title.toLowerCase()} para esta fecha',
                                        style: GoogleFonts.inter(color: AppTheme.darkTextSecondary, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  controller: scrollController,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  itemCount: _selectedDateData.length,
                                  itemBuilder: (context, index) {
                                    final item = _selectedDateData[index];
                                    final badge = _getStatusBadge(int.tryParse(item['estado']?.toString() ?? '1') ?? 1);

                                    String titleText = '';
                                    double amountVal = 0;

                                    if (_selectedDataType == 'asistencias') {
                                      titleText = '${_formatSimpleDate(item['fecha'])} ${item['hora'] ?? ''}';
                                      amountVal = double.tryParse(item['sueldo_final']?.toString() ?? '0') ?? 0;
                                    } else if (_selectedDataType == 'anticipos') {
                                      titleText = _formatSimpleDate(item['fecha_crea']);
                                      amountVal = double.tryParse(item['monto']?.toString() ?? '0') ?? 0;
                                    } else if (_selectedDataType == 'propinas') {
                                      titleText = _formatSimpleDate(item['fecha_crea']);
                                      amountVal = double.tryParse(item['monto']?.toString() ?? '0') ?? 0;
                                    } else if (_selectedDataType == 'horasExtras') {
                                      titleText = '${_formatSimpleDate(item['fecha_crea'])} (${item['hora'] ?? 0}h)';
                                      amountVal = double.tryParse(item['total']?.toString() ?? '0') ?? 0;
                                    }

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: AppTheme.darkSurfaceColor,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.white10),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: dataType.color.withValues(alpha: 0.15),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                (index + 1).toString(),
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: dataType.color,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  titleText,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _formatCurrency(amountVal),
                                                  style: GoogleFonts.inter(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w900,
                                                    color: _selectedDataType == 'anticipos' ? Colors.red : Colors.green,
                                                  ),
                                                )
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: badge['bg'] as Color,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              badge['label'] as String,
                                              style: GoogleFonts.inter(
                                                fontSize: 9,
                                                color: badge['color'] as Color,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          )
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    )
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy', 'es_ES').format(_currentDate);

    // Grid days calculation
    final year = _currentDate.year;
    final month = _currentDate.month;
    final firstDay = DateTime(year, month, 1);
    final offset = firstDay.weekday % 7;
    final prevMonthLast = DateTime(year, month, 0);
    
    final List<CalendarDay> calendarDays = [];
    final todayKey = _toDateKey(DateTime.now());

    // Build the grid days locally to prevent race conditions during rendering
    final asistDates = _asistencias.map((a) => _toDateKey(DateTime.tryParse(a['fecha'] ?? '') ?? DateTime.now())).toSet();
    final anticDates = _anticipos.map((a) => _toDateKey(DateTime.tryParse(a['fecha_crea'] ?? '') ?? DateTime.now())).toSet();
    final propDates = _propinas.map((p) => _toDateKey(DateTime.tryParse(p['fecha_crea'] ?? '') ?? DateTime.now())).toSet();
    final heDates = _horasExtras.map((h) => _toDateKey(DateTime.tryParse(h['fecha_crea'] ?? '') ?? DateTime.now())).toSet();

    for (int i = offset - 1; i >= 0; i--) {
      final d = DateTime(year, month - 1, prevMonthLast.day - i);
      final dk = _toDateKey(d);
      calendarDays.add(CalendarDay(
        date: d,
        isCurrentMonth: false,
        isToday: dk == todayKey,
        data: {
          'asistencias': asistDates.contains(dk),
          'anticipos': anticDates.contains(dk),
          'propinas': propDates.contains(dk),
          'horasExtras': heDates.contains(dk),
        },
      ));
    }

    final currentMonthDays = DateTime(year, month + 1, 0).day;
    for (int i = 1; i <= currentMonthDays; i++) {
      final d = DateTime(year, month, i);
      final dk = _toDateKey(d);
      calendarDays.add(CalendarDay(
        date: d,
        isCurrentMonth: true,
        isToday: dk == todayKey,
        data: {
          'asistencias': asistDates.contains(dk),
          'anticipos': anticDates.contains(dk),
          'propinas': propDates.contains(dk),
          'horasExtras': heDates.contains(dk),
        },
      ));
    }

    final remaining = 42 - calendarDays.length;
    for (int i = 1; i <= remaining; i++) {
      final d = DateTime(year, month + 1, i);
      final dk = _toDateKey(d);
      calendarDays.add(CalendarDay(
        date: d,
        isCurrentMonth: false,
        isToday: dk == todayKey,
        data: {
          'asistencias': asistDates.contains(dk),
          'anticipos': anticDates.contains(dk),
          'propinas': propDates.contains(dk),
          'horasExtras': heDates.contains(dk),
        },
      ));
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBgColor,
      body: _loading
          ? _buildSkeletonGrid()
          : RefreshIndicator(
              onRefresh: () => _fetchCalendarData(isManual: true),
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
                                    'Calendario',
                                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  Text(
                                    'Vista mensual de eventos',
                                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.darkTextSecondary),
                                  )
                                ],
                              ),
                              GestureDetector(
                                onTap: () => _fetchCalendarData(isManual: true),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.refresh, color: Colors.white, size: 18),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Month Navigation Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left, color: Colors.white),
                              onPressed: () => _navigateMonth(-1),
                            ),
                            GestureDetector(
                              onTap: _goToToday,
                              child: Text(
                                monthLabel[0].toUpperCase() + monthLabel.substring(1),
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, color: Colors.white),
                              onPressed: () => _navigateMonth(1),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Calendar Grid Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurfaceColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            // Weekday names
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'].map((day) {
                                return SizedBox(
                                  width: 40,
                                  child: Text(
                                    day,
                                    style: GoogleFonts.inter(color: AppTheme.darkTextSecondary, fontWeight: FontWeight.bold, fontSize: 11),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }).toList(),
                            ),
                            const Divider(color: Colors.white10, height: 20),
                            // Days Grid
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: 42,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                mainAxisSpacing: 6,
                                crossAxisSpacing: 6,
                              ),
                              itemBuilder: (context, index) {
                                final day = calendarDays[index];

                                return GestureDetector(
                                  onTap: () => _handleDayPress(day),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: day.isToday ? AppTheme.primaryColor : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          day.date.day.toString(),
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: day.isCurrentMonth
                                                ? Colors.white
                                                : AppTheme.darkTextSecondary.withValues(alpha: 0.35),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        // Indicator dots
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            if (day.data['asistencias'] == true) _buildIndicatorDot(const Color(0xFF10B981)),
                                            if (day.data['anticipos'] == true) _buildIndicatorDot(const Color(0xFFEF4444)),
                                            if (day.data['propinas'] == true) _buildIndicatorDot(const Color(0xFFF59E0B)),
                                            if (day.data['horasExtras'] == true) _buildIndicatorDot(const Color(0xFF8B5CF6)),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            const Divider(color: Colors.white10, height: 24),
                            // Legend
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildLegendItem('Asistencia', const Color(0xFF10B981)),
                                _buildLegendItem('Anticipo', const Color(0xFFEF4444)),
                                _buildLegendItem('Propina', const Color(0xFFF59E0B)),
                                _buildLegendItem('HE', const Color(0xFF8B5CF6)),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
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
          const SkeletonCard(lines: 7),
          const SizedBox(height: 16),
          const SkeletonCard(lines: 3),
        ],
      ),
    );
  }

  Widget _buildIndicatorDot(Color color) {
    return Container(
      width: 4,
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 0.5),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.darkTextSecondary, fontWeight: FontWeight.bold),
        )
      ],
    );
  }
}
