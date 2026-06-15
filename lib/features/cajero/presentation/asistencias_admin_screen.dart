import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../auth/data/auth_notifier.dart';

class AttendanceSummary {
  final int idUsuario;
  final String nick;
  final String nombreCompleto;
  final String? usuarioFoto;
  final int totalAsistencias;
  final double sueldoTotal;
  final double aporteTotal;
  final double descuentoTotal;
  final double totalFinal;
  final String? rol;

  AttendanceSummary({
    required this.idUsuario,
    required this.nick,
    required this.nombreCompleto,
    this.usuarioFoto,
    required this.totalAsistencias,
    required this.sueldoTotal,
    required this.aporteTotal,
    required this.descuentoTotal,
    required this.totalFinal,
    this.rol,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceSummary(
      idUsuario: int.tryParse(json['id_usuario']?.toString() ?? '') ?? 0,
      nick: json['nick'] ?? '',
      nombreCompleto: json['nombre_completo'] ?? json['nombre'] ?? '',
      usuarioFoto: json['usuario_foto'],
      totalAsistencias: int.tryParse(json['total_asistencias']?.toString() ?? '0') ?? 0,
      sueldoTotal: double.tryParse(json['sueldo_total']?.toString() ?? '0') ?? 0.0,
      aporteTotal: double.tryParse(json['aporte_total']?.toString() ?? '0') ?? 0.0,
      descuentoTotal: double.tryParse(json['descuento_total']?.toString() ?? '0') ?? 0.0,
      totalFinal: double.tryParse(json['total_final']?.toString() ?? '0') ?? 0.0,
      rol: json['rol'],
    );
  }
}

class AttendanceDetail {
  final int idAsistencia;
  final String fecha;
  final String hora;
  final int estado;
  final String? observaciones;
  final double sueldo;
  final double aporte;
  final double descuento;
  final double descuentoTotal;

  AttendanceDetail({
    required this.idAsistencia,
    required this.fecha,
    required this.hora,
    required this.estado,
    this.observaciones,
    required this.sueldo,
    required this.aporte,
    required this.descuento,
    required this.descuentoTotal,
  });

  factory AttendanceDetail.fromJson(Map<String, dynamic> json) {
    return AttendanceDetail(
      idAsistencia: int.tryParse(json['id_asistencia']?.toString() ?? '') ?? 0,
      fecha: json['fecha'] ?? '',
      hora: json['hora'] ?? '',
      estado: int.tryParse(json['estado']?.toString() ?? '0') ?? 0,
      observaciones: json['observaciones'],
      sueldo: double.tryParse(json['sueldo']?.toString() ?? '0') ?? 0.0,
      aporte: double.tryParse(json['aporte']?.toString() ?? '0') ?? 0.0,
      descuento: double.tryParse(json['descuento']?.toString() ?? '0') ?? 0.0,
      descuentoTotal: double.tryParse(json['descuento_total']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class CajeroAsistenciasAdminScreen extends ConsumerStatefulWidget {
  const CajeroAsistenciasAdminScreen({super.key});

  @override
  ConsumerState<CajeroAsistenciasAdminScreen> createState() => _CajeroAsistenciasAdminScreenState();
}

class _CajeroAsistenciasAdminScreenState extends ConsumerState<CajeroAsistenciasAdminScreen> {
  bool _loading = true;
  List<AttendanceSummary> _data = [];
  String _error = '';
  String _filter = 'all'; // all, con_asistencias, sin_asistencias
  String _searchText = '';
  DateTime _currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData({bool isManual = false}) async {
    if (!isManual) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }
    try {
      final client = ref.read(apiClientProvider);
      final month = _currentDate.month;
      final year = _currentDate.year;
      final response = await client.dio.get('/attendance?month=$month&year=$year');
      
      if (response.data != null && response.data['success'] == true) {
        final List<dynamic> list = response.data['data'] ?? [];
        setState(() {
          _data = list.map((json) => AttendanceSummary.fromJson(json)).toList();
          _loading = false;
        });
      } else {
        throw Exception(response.data?['message'] ?? 'Error al cargar asistencias');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _navigateMonth(int direction) {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month + direction, 1);
    });
    _fetchData();
  }

  void _goToCurrentMonth() {
    setState(() {
      _currentDate = DateTime.now();
    });
    _fetchData();
  }

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);
    return format.format(amount);
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return '??';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  List<AttendanceSummary> get _filteredData {
    var result = _data;
    if (_searchText.trim().isNotEmpty) {
      final query = _searchText.trim().toLowerCase();
      result = result.where((e) =>
          e.nombreCompleto.toLowerCase().contains(query) ||
          e.nick.toLowerCase().contains(query)).toList();
    }
    if (_filter == 'con_asistencias') {
      result = result.where((e) => e.totalAsistencias > 0).toList();
    } else if (_filter == 'sin_asistencias') {
      result = result.where((e) => e.totalAsistencias == 0).toList();
    }
    return result;
  }

  Map<String, dynamic> get _totals {
    int totalEmpleados = _data.length;
    int totalAsistencias = _data.fold(0, (sum, item) => sum + item.totalAsistencias);
    double totalSueldo = _data.fold(0.0, (sum, item) => sum + item.sueldoTotal);
    double totalAporte = _data.fold(0.0, (sum, item) => sum + item.aporteTotal);
    double totalDescuento = _data.fold(0.0, (sum, item) => sum + item.descuentoTotal);
    double totalFinal = _data.fold(0.0, (sum, item) => sum + item.totalFinal);

    return {
      'totalEmpleados': totalEmpleados,
      'totalAsistencias': totalAsistencias,
      'totalSueldo': totalSueldo,
      'totalAporte': totalAporte,
      'totalDescuento': totalDescuento,
      'totalFinal': totalFinal,
    };
  }

  Future<void> _showEmployeeDetail(AttendanceSummary emp) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _EmployeeDetailDialog(employee: emp);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalsData = _totals;
    final monthLabel = DateFormat('MMMM yyyy', 'es_ES').format(_currentDate);

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
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    'Asistencias',
                                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  Text(
                                    monthLabel[0].toUpperCase() + monthLabel.substring(1),
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
                              onTap: _goToCurrentMonth,
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

                    // Global Summary
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurfaceColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RESUMEN GLOBAL',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                            ),
                            Text(
                              '${totalsData['totalEmpleados']} empleados · ${totalsData['totalAsistencias']} asistencias',
                              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.darkTextSecondary),
                            ),
                            const Divider(color: Colors.white10, height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSummaryItem('Sueldo', _formatCurrency(totalsData['totalSueldo']), Colors.white),
                                _buildSummaryItem('Aporte', '-${_formatCurrency(totalsData['totalAporte'])}', Colors.red),
                                if (totalsData['totalDescuento'] > 0)
                                  _buildSummaryItem('Desc.', '-${_formatCurrency(totalsData['totalDescuento'])}', Colors.orange),
                                _buildSummaryItem('Total a Pagar', _formatCurrency(totalsData['totalFinal']), AppTheme.primaryColor, isLarge: true),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        onChanged: (val) => setState(() => _searchText = val),
                        style: GoogleFonts.inter(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre o nick...',
                          prefixIcon: const Icon(Icons.search, color: AppTheme.darkTextSecondary),
                          suffixIcon: _searchText.isNotEmpty
                              ? GestureDetector(
                                  onTap: () => setState(() => _searchText = ''),
                                  child: const Icon(Icons.close_rounded, color: AppTheme.darkTextSecondary),
                                )
                              : null,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Filter chips row (Todos, Con asistencias, Sin asistencias)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          _buildFilterChip('Todos', 'all'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Con asistencias', 'con_asistencias'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Sin asistencias', 'sin_asistencias'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Employees list
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _error.isNotEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40.0),
                                child: Text('Error: $_error', style: GoogleFonts.inter(color: Colors.red)),
                              ),
                            )
                          : _filteredData.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 60.0),
                                    child: Column(
                                      children: [
                                        Icon(Icons.people_outline_rounded, size: 48, color: AppTheme.darkTextSecondary),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No hay empleados en esta categoría',
                                          style: GoogleFonts.inter(color: AppTheme.darkTextSecondary, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _filteredData.length,
                                  itemBuilder: (context, index) {
                                    final emp = _filteredData[index];
                                    final totalX = emp.sueldoTotal - emp.aporteTotal - emp.descuentoTotal;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.darkSurfaceColor,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _showEmployeeDetail(emp),
                                            child: Padding(
                                              padding: const EdgeInsets.all(16.0),
                                              child: Column(
                                                children: [
                                                  Row(
                                                    children: [
                                                      Container(
                                                        width: 44,
                                                        height: 44,
                                                        decoration: BoxDecoration(
                                                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                                          borderRadius: BorderRadius.circular(14),
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            _getInitials(emp.nombreCompleto),
                                                            style: GoogleFonts.inter(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.bold,
                                                              color: AppTheme.primaryColor,
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
                                                              emp.nombreCompleto,
                                                              style: GoogleFonts.inter(
                                                                fontSize: 14,
                                                                fontWeight: FontWeight.bold,
                                                                color: Colors.white,
                                                              ),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                            Row(
                                                              children: [
                                                                if (emp.rol != null) ...[
                                                                  Container(
                                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                    decoration: BoxDecoration(
                                                                      color: Colors.grey[850],
                                                                      borderRadius: BorderRadius.circular(9999),
                                                                    ),
                                                                    child: Text(
                                                                      emp.rol!,
                                                                      style: GoogleFonts.inter(fontSize: 9, color: AppTheme.darkTextSecondary, fontWeight: FontWeight.bold),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(width: 6),
                                                                ],
                                                                Text(
                                                                  '@${emp.nick}',
                                                                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.darkTextSecondary),
                                                                ),
                                                              ],
                                                            )
                                                          ],
                                                        ),
                                                      ),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                        decoration: BoxDecoration(
                                                          color: emp.totalAsistencias > 0
                                                              ? Colors.green.withValues(alpha: 0.15)
                                                              : Colors.red.withValues(alpha: 0.15),
                                                          borderRadius: BorderRadius.circular(9999),
                                                        ),
                                                        child: Text(
                                                          '${emp.totalAsistencias} días',
                                                          style: GoogleFonts.inter(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            color: emp.totalAsistencias > 0 ? Colors.green : Colors.red,
                                                          ),
                                                        ),
                                                      )
                                                    ],
                                                  ),
                                                  const Divider(color: Colors.white10, height: 24),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      _buildEmployeeAmount('Sueldo', _formatCurrency(emp.sueldoTotal), Colors.white),
                                                      _buildEmployeeAmount('Aporte', '-${_formatCurrency(emp.aporteTotal)}', Colors.red),
                                                      if (emp.descuentoTotal > 0)
                                                        _buildEmployeeAmount('Desc.', '-${_formatCurrency(emp.descuentoTotal)}', Colors.orange),
                                                      _buildEmployeeAmount('Total', _formatCurrency(totalX), AppTheme.primaryColor, isBold: true),
                                                    ],
                                                  )
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color, {bool isLarge = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 9, color: AppTheme.darkTextSecondary, fontWeight: FontWeight.bold),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: isLarge ? 15 : 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        )
      ],
    );
  }

  Widget _buildEmployeeAmount(String label, String value, Color color, {bool isBold = false}) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 9, color: AppTheme.darkTextSecondary, fontWeight: FontWeight.bold),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            color: color,
          ),
        )
      ],
    );
  }

  Widget _buildFilterChip(String text, String value) {
    final isSelected = _filter == value;
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? AppTheme.primaryColor : AppTheme.darkSurfaceColor,
          foregroundColor: isSelected ? Colors.white : AppTheme.darkTextSecondary,
          padding: const EdgeInsets.symmetric(vertical: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
            side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.white10),
          ),
        ),
        onPressed: () => setState(() => _filter = value),
        child: Text(
          text,
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
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
          const SkeletonCard(lines: 3),
          const SizedBox(height: 16),
          ...List.generate(5, (i) => const SkeletonCard(showAvatar: true, lines: 2)),
        ],
      ),
    );
  }
}

class _EmployeeDetailDialog extends ConsumerStatefulWidget {
  final AttendanceSummary employee;

  const _EmployeeDetailDialog({required this.employee});

  @override
  ConsumerState<_EmployeeDetailDialog> createState() => _EmployeeDetailDialogState();
}

class _EmployeeDetailDialogState extends ConsumerState<_EmployeeDetailDialog> {
  bool _loading = true;
  List<AttendanceDetail> _details = [];

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.get('/attendance/${widget.employee.idUsuario}/detalle');
      
      if (response.data != null && response.data['success'] == true) {
        final List<dynamic> list = response.data['data'] ?? [];
        if (mounted) {
          setState(() {
            _details = list.map((json) => AttendanceDetail.fromJson(json)).toList();
            _loading = false;
          });
        }
      } else {
        throw Exception();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _details = [];
          _loading = false;
        });
      }
    }
  }

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);
    return format.format(amount);
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return '??';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final emp = widget.employee;
    final totalSueldos = _details.fold(0.0, (s, a) => s + a.sueldo);
    final totalAportes = _details.fold(0.0, (s, a) => s + a.aporte);
    final totalDescuentos = _details.fold(0.0, (s, a) => s + a.descuentoTotal);
    final totalPagar = totalSueldos - totalAportes - totalDescuentos;

    return AlertDialog(
      backgroundColor: AppTheme.darkSurfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.all(20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      actionsPadding: const EdgeInsets.all(16),
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                _getInitials(emp.nombreCompleto),
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emp.nombreCompleto,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '@${emp.nick}',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.darkTextSecondary),
                ),
              ],
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
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 40.0),
                child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Financial Summary Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RESUMEN FINANCIERO',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.darkTextSecondary),
                        ),
                        const SizedBox(height: 10),
                        _buildRow('Total sueldos', _formatCurrency(totalSueldos), Colors.white),
                        _buildRow('Total aportes', '-${_formatCurrency(totalAportes)}', Colors.red),
                        if (totalDescuentos > 0)
                          _buildRow('Descuento habitación', '-${_formatCurrency(totalDescuentos)}', Colors.orange),
                        const Divider(color: Colors.white10, height: 16),
                        _buildRow('Total a pagar', _formatCurrency(totalPagar), AppTheme.primaryColor, isBold: true),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  
                  Text(
                    'Registro de Asistencias',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 10),

                  // Attendance List
                  Flexible(
                    child: _details.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 30.0),
                            child: Center(
                              child: Text(
                                'No hay asistencias registradas',
                                style: GoogleFonts.inter(color: AppTheme.darkTextSecondary, fontSize: 13),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _details.length,
                            itemBuilder: (context, index) {
                              final det = _details[index];
                              final isPagado = det.estado == 0;
                              final stateColor = isPagado ? Colors.green : Colors.orange;
                              final stateBg = isPagado ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.darkTextSecondary),
                                            const SizedBox(width: 6),
                                            Text(
                                              det.fecha,
                                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: stateBg,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            isPagado ? 'Pagado' : 'Por Pagar',
                                            style: GoogleFonts.inter(fontSize: 9, color: stateColor, fontWeight: FontWeight.bold),
                                          ),
                                        )
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.access_time_rounded, size: 14, color: AppTheme.darkTextSecondary),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Hora: ${det.hora.substring(0, 5)}',
                                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.darkTextSecondary),
                                        )
                                      ],
                                    ),
                                    const Divider(color: Colors.white10, height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildDetailCol('Sueldo', _formatCurrency(det.sueldo), Colors.white),
                                        _buildDetailCol('Aporte AFP', _formatCurrency(det.aporte), Colors.red),
                                        if (det.descuento > 0)
                                          _buildDetailCol('Desc.', _formatCurrency(det.descuento), Colors.orange),
                                      ],
                                    )
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
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
  }

  Widget _buildRow(String label, String value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.darkTextSecondary)),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCol(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 9, color: AppTheme.darkTextSecondary, fontWeight: FontWeight.bold),
        ),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: color),
        )
      ],
    );
  }
}
