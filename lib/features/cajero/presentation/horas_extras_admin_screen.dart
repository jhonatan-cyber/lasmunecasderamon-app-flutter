import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../core/hooks/refresh_provider.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../auth/data/auth_notifier.dart';

class OvertimeRecord {
  final int idHoraExtra;
  final int usuarioId;
  final String usuario;
  final String? usuarioFoto;
  final DateTime fechaCrea;
  final DateTime? fechaMod;
  final double hora;
  final double monto;
  final double total;
  final int estado;

  OvertimeRecord({
    required this.idHoraExtra,
    required this.usuarioId,
    required this.usuario,
    this.usuarioFoto,
    required this.fechaCrea,
    this.fechaMod,
    required this.hora,
    required this.monto,
    required this.total,
    required this.estado,
  });

  factory OvertimeRecord.fromJson(Map<String, dynamic> json) {
    return OvertimeRecord(
      idHoraExtra: int.tryParse(json['id_hora_extra']?.toString() ?? '') ?? 0,
      usuarioId: int.tryParse(json['usuario_id']?.toString() ?? '') ?? 0,
      usuario: json['usuario'] ?? '',
      usuarioFoto: json['usuario_foto'],
      fechaCrea: DateTime.tryParse(json['fecha_crea'] ?? '') ?? DateTime.now(),
      fechaMod: json['fecha_mod'] != null ? DateTime.tryParse(json['fecha_mod']) : null,
      hora: double.tryParse(json['hora']?.toString() ?? '0') ?? 0.0,
      monto: double.tryParse(json['monto']?.toString() ?? '0') ?? 0.0,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
      estado: int.tryParse(json['estado']?.toString() ?? '0') ?? 0,
    );
  }
}

class CajeroHorasExtrasAdminScreen extends ConsumerStatefulWidget {
  const CajeroHorasExtrasAdminScreen({super.key});

  @override
  ConsumerState<CajeroHorasExtrasAdminScreen> createState() => _CajeroHorasExtrasAdminScreenState();
}

class _CajeroHorasExtrasAdminScreenState extends ConsumerState<CajeroHorasExtrasAdminScreen> {
  List<OvertimeRecord> _records = [];
  String _statusFilter = 'all'; // all, pendiente, pagado
  String _userFilter = 'all'; // all or userId as string

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchData());
  }

  Future<void> _fetchData({bool isManual = false}) async {
    final notifier = ref.read(refreshProvider('horas_extras_admin').notifier);
    if (!isManual) {
      notifier.startRefresh(isManual: false);
    }
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.get('/overtime');
      
      if (response.data != null && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        if (!mounted) return;
        setState(() {
          _records = data.map((json) => OvertimeRecord.fromJson(json)).toList();
        });
        notifier.endRefresh();
      } else {
        throw Exception(response.data?['message'] ?? 'Error al cargar horas extras');
      }
    } catch (e) {
      if (!mounted) return;
      notifier.endRefresh(error: e.toString());
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
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  // Derived properties using useMemo pattern
  List<Map<String, dynamic>> get _employees {
    final Map<int, String> map = {};
    for (var r in _records) {
      map[r.usuarioId] = r.usuario;
    }
    return map.entries.map((e) => {'id': e.key, 'name': e.value}).toList();
  }

  List<OvertimeRecord> get _filteredRecords {
    var result = _records;
    if (_statusFilter != 'all') {
      final targetEstado = _statusFilter == 'pendiente' ? 1 : 0;
      result = result.where((r) => r.estado == targetEstado).toList();
    }
    if (_userFilter != 'all') {
      final targetUserId = int.tryParse(_userFilter);
      result = result.where((r) => r.usuarioId == targetUserId).toList();
    }
    return result;
  }

  List<Map<String, dynamic>> get _perEmployeeStats {
    final Map<int, Map<String, dynamic>> map = {};
    for (var r in _records) {
      if (map.containsKey(r.usuarioId)) {
        final current = map[r.usuarioId]!;
        current['totalHoras'] = (current['totalHoras'] as double) + r.hora;
        current['totalMonto'] = (current['totalMonto'] as double) + r.monto;
        if (r.estado == 1) {
          current['totalACobrar'] = (current['totalACobrar'] as double) + (r.total != 0 ? r.total : r.monto);
        }
        current['count'] = (current['count'] as int) + 1;
      } else {
        map[r.usuarioId] = {
          'usuario_id': r.usuarioId,
          'usuario': r.usuario,
          'totalHoras': r.hora,
          'totalMonto': r.monto,
          'totalACobrar': r.estado == 1 ? (r.total != 0 ? r.total : r.monto) : 0.0,
          'count': 1,
        };
      }
    }
    final stats = map.values.toList();
    stats.sort((a, b) => (b['totalMonto'] as double).compareTo(a['totalMonto'] as double));
    return stats;
  }

  Map<String, dynamic> get _stats {
    double totalMonto = 0;
    double totalHoras = 0;
    double totalAPagar = 0;
    for (var r in _records) {
      totalMonto += r.monto;
      totalHoras += r.hora;
      if (r.estado == 1) {
        totalAPagar += (r.total != 0 ? r.total : r.monto);
      }
    }
    return {
      'totalRegistros': _records.length,
      'totalMonto': totalMonto,
      'totalHoras': totalHoras,
      'totalAPagar': totalAPagar,
    };
  }

  void _showDetailModal(OvertimeRecord record) {
    showDialog(
      context: context,
      builder: (context) {
        final isPendiente = record.estado == 1;
        final statusColor = isPendiente ? Colors.orange : Colors.green;
        final statusLabel = isPendiente ? 'Por cobrar' : 'Pagado';
        
        return AlertDialog(
          backgroundColor: AppTheme.darkSurfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.all(20),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          actionsPadding: const EdgeInsets.all(16),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Detalle de Hora Extra',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusLabel.toUpperCase(),
                      style: GoogleFonts.inter(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    _buildModalRow('Empleado', record.usuario),
                    _buildModalRow('Horas extras', '${record.hora.toStringAsFixed(1)} hrs'),
                    _buildModalRow('Valor por hora', _formatCurrency(record.monto)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Total Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total a pagar', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.darkTextSecondary)),
                        Text(
                          _formatCurrency(record.total != 0 ? record.total : record.monto),
                          style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                        ),
                      ],
                    ),
                    Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary, size: 32),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Metadata
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
                    Text('METADATOS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.darkTextSecondary)),
                    const SizedBox(height: 8),
                    _buildModalRow('ID Registro', '#${record.idHoraExtra}'),
                    _buildModalRow('Fecha creación', DateFormat('dd/MM/yyyy HH:mm').format(record.fechaCrea)),
                    if (record.fechaMod != null)
                      _buildModalRow('Última mod.', DateFormat('dd/MM/yyyy HH:mm').format(record.fechaMod!)),
                  ],
                ),
              )
            ],
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
  }

  Widget _buildModalRow(String label, String value) {
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
    final statsData = _stats;
    final refresh = ref.watch(refreshProvider('horas_extras_admin'));

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
                                    'Horas Extras',
                                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  Text(
                                    '${_records.length} registros · ${_employees.length} empleados',
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

                    // Stats Cards Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              label: 'HORAS',
                              value: (statsData['totalHoras'] as double).toStringAsFixed(1),
                              icon: Icons.access_time_rounded,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              label: 'TOTAL MONTO',
                              value: _formatCurrency(statsData['totalMonto']),
                              icon: Icons.payments_rounded,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              label: 'POR COBRAR',
                              value: _formatCurrency(statsData['totalAPagar']),
                              icon: Icons.wallet_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Per-employee Stats horizontal list
                    SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _perEmployeeStats.length,
                        itemBuilder: (context, index) {
                          final emp = _perEmployeeStats[index];
                          final isSelected = _userFilter == emp['usuario_id'].toString();

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _userFilter = isSelected ? 'all' : emp['usuario_id'].toString();
                              });
                            },
                            child: Container(
                              width: 150,
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                                    : AppTheme.darkSurfaceColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white10,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        _getInitials(emp['usuario']),
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          emp['usuario'].split(' ')[0],
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${(emp['totalHoras'] as double).toStringAsFixed(1)}h · ${emp['count']} reg.',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: AppTheme.darkTextSecondary,
                                          ),
                                        ),
                                        Text(
                                          _formatCurrency(emp['totalMonto']),
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: emp['totalACobrar'] > 0 ? Colors.orange : Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Filter Row Buttons (All, Por cobrar, Pagado)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          _buildFilterButton('Todas', 'all'),
                          const SizedBox(width: 8),
                          _buildFilterButton('Por cobrar', 'pendiente'),
                          const SizedBox(width: 8),
                          _buildFilterButton('Pagado', 'pagado'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Main list
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: refresh.error.isNotEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40.0),
                                child: Text('Error: ${refresh.error}', style: GoogleFonts.inter(color: Colors.red)),
                              ),
                            )
                          : _filteredRecords.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 60.0),
                                    child: Column(
                                      children: [
                                        Icon(Icons.lock_clock_rounded, size: 48, color: AppTheme.darkTextSecondary),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No hay horas extras registradas',
                                          style: GoogleFonts.inter(color: AppTheme.darkTextSecondary, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _filteredRecords.length,
                                  itemBuilder: (context, index) {
                                    final record = _filteredRecords[index];
                                    final isPendiente = record.estado == 1;
                                    final badgeColor = isPendiente ? Colors.orange : Colors.green;
                                    final badgeBg = isPendiente ? Colors.orange.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15);

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.darkSurfaceColor,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                      ),
                                      child: ListTile(
                                        onTap: () => _showDetailModal(record),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        leading: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              _getInitials(record.usuario),
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          record.usuario,
                                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                                        ),
                                        subtitle: Row(
                                          children: [
                                            Icon(Icons.calendar_today_rounded, size: 12, color: AppTheme.darkTextSecondary),
                                            const SizedBox(width: 4),
                                            Text(
                                              DateFormat('dd/MM/yyyy').format(record.fechaCrea),
                                              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.darkTextSecondary),
                                            )
                                          ],
                                        ),
                                        trailing: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: badgeBg,
                                                borderRadius: BorderRadius.circular(9999),
                                              ),
                                              child: Text(
                                                isPendiente ? 'Por cobrar' : 'Pagado',
                                                style: GoogleFonts.inter(fontSize: 10, color: badgeColor, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _formatCurrency(record.total != 0 ? record.total : record.monto),
                                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                                            )
                                          ],
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
        ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 8, color: AppTheme.darkTextSecondary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        ],
      ),
    );
  }

  Widget _buildFilterButton(String text, String value) {
    final isSelected = _statusFilter == value;
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Theme.of(context).colorScheme.primary : AppTheme.darkSurfaceColor,
          foregroundColor: isSelected ? Colors.white : AppTheme.darkTextSecondary,
          padding: const EdgeInsets.symmetric(vertical: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
            side: BorderSide(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white10),
          ),
        ),
        onPressed: () => setState(() => _statusFilter = value),
        child: Text(
          text,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
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
            // Stats row skeleton
            Row(
              children: const [
                Expanded(child: SkeletonCard(lines: 2)),
                SizedBox(width: 8),
                Expanded(child: SkeletonCard(lines: 2)),
                SizedBox(width: 8),
                Expanded(child: SkeletonCard(lines: 2)),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(5, (i) => const SkeletonCard(showAvatar: true, lines: 2)),
          ],
        ),
      ),
    );
  }
}
