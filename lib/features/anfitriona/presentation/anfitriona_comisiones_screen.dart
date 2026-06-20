import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/premium_header.dart';
import '../../../core/theme.dart';
import '../../../core/hooks/refresh_provider.dart';
import '../../auth/data/auth_notifier.dart';

class AnfitrionaComisionesScreen extends ConsumerStatefulWidget {
  const AnfitrionaComisionesScreen({super.key});

  @override
  ConsumerState<AnfitrionaComisionesScreen> createState() => _AnfitrionaComisionesScreenState();
}

class _AnfitrionaComisionesScreenState extends ConsumerState<AnfitrionaComisionesScreen> {
  List<dynamic> _comisiones = [];
  String _filter = 'all'; 

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchComisiones());
  }

  Future<void> _fetchComisiones({bool isManual = false}) async {
    final notifier = ref.read(refreshProvider('anfitriona_comisiones').notifier);
    notifier.startRefresh(isManual: isManual);

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.get('/commissions/user');
      final data = response.data;

      if (data != null && data['success'] == true) {
        final List<dynamic> rawList = data['data'] ?? [];
        
        final ventaComisiones = rawList.where((c) => c != null && c['tipo'] == 'venta').toList();

        if (!mounted) return;
        setState(() => _comisiones = ventaComisiones);
        notifier.endRefresh();
      } else {
        if (!mounted) return;
        notifier.endRefresh(error: data?['message'] ?? 'Error al cargar comisiones');
      }
    } catch (e) {
      if (!mounted) return;
      notifier.endRefresh(error: 'Error de conexion con el servidor');
    }
  }

  List<dynamic> get _filteredComisiones {
    return _comisiones.where((c) {
      if (c == null) return false;
      final estadoNum = int.tryParse(c['estado']?.toString() ?? '0') ?? 0;
      final isPendiente = estadoNum == 1;

      if (_filter == 'pendiente') {
        return isPendiente;
      }
      if (_filter == 'pagado') {
        return !isPendiente;
      }
      return true;
    }).toList();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Sin fecha';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMM yyyy', 'es_ES').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('HH:mm').format(date);
    } catch (_) {
      return '';
    }
  }

  void _showComisionDetail(dynamic item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;
    final cardBg = isDark ? AppTheme.nearBlackColor : Colors.white;
    final textPrimary = isDark ? Colors.white : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.gray500Color;
    final borderColor = isDark ? accentColor.withValues(alpha: 0.25) : Colors.grey.shade200;

    final double amount = double.tryParse((item['comision'] ?? item['monto'] ?? 0).toString()) ?? 0.0;
    final isPendiente = (int.tryParse(item['estado']?.toString() ?? '0') ?? 0) == 1;
    final formatter = NumberFormat.decimalPattern('es_ES');

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Detalle de Comisión',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black : AppTheme.lightBgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('Código Venta:', item['codigo_venta']?.toString() ?? item['codigo']?.toString() ?? '----', textPrimary, textSecondary),
                      const SizedBox(height: 10),
                      _buildDetailRow('Fecha:', _formatDate(item['fecha_crea']), textPrimary, textSecondary),
                      const SizedBox(height: 10),
                      _buildDetailRow('Hora:', _formatTime(item['fecha_crea']), textPrimary, textSecondary),
                      const SizedBox(height: 10),
                      _buildDetailRow('Tipo:', 'Venta de Servicio', textPrimary, textSecondary),
                      const SizedBox(height: 12),
                      Container(height: 1, color: borderColor),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'MONTO COMISIÓN',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary),
                          ),
                          Text(
                            '\$${formatter.format(amount)}',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: isPendiente ? accentColor : AppTheme.successColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Estado de Pago:',
                            style: GoogleFonts.inter(fontSize: 12, color: textSecondary),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isPendiente ? accentColor.withValues(alpha: 0.1) : AppTheme.successColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isPendiente ? 'PENDIENTE' : 'COBRADO',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isPendiente ? accentColor : AppTheme.successColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, Color textPrimary, Color textSecondary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: textSecondary),
        ),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;
    final bg = isDark ? Colors.black : AppTheme.lightBgColor;
    final cardBg = isDark ? AppTheme.nearBlackColor : Colors.white;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.gray500Color;
    final textPrimary = isDark ? Colors.white : AppTheme.lightTextPrimary;
    final borderColor = isDark ? accentColor.withValues(alpha: 0.25) : Colors.grey.shade200;

    
    final pendientes = _comisiones.where((c) => c != null && (int.tryParse(c['estado']?.toString() ?? '0') ?? 0) == 1);
    final cobrados = _comisiones.where((c) => c != null && (int.tryParse(c['estado']?.toString() ?? '0') ?? 0) != 1);

    final double totalPendiente = pendientes.fold(0.0, (sum, c) {
      final val = double.tryParse((c['comision'] ?? c['monto'] ?? 0).toString()) ?? 0.0;
      return sum + val;
    });

    final double totalAcumulado = _comisiones.fold(0.0, (sum, c) {
      if (c == null) return sum;
      final val = double.tryParse((c['comision'] ?? c['monto'] ?? 0).toString()) ?? 0.0;
      return sum + val;
    });

    final formatter = NumberFormat.simpleCurrency(decimalDigits: 0, name: 'CLP');

    final accentTheme = ref.watch(accentColorProvider);
    final gradientColors = accentTheme.gradient;

    final refresh = ref.watch(refreshProvider('anfitriona_comisiones'));

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          PremiumHeader(
            title: 'Comisiones',
            gradient: gradientColors,
            showRefreshButton: true,
            isRefreshing: refresh.isRefreshing,
            onRefresh: () => _fetchComisiones(isManual: true),
          ),
          Expanded(
            child: Column(
              children: [
                
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
                      'COMISIONES PENDIENTES',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatter.format(totalPendiente),
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total Acumulado: ${formatter.format(totalAcumulado)}',
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

            
            Container(
              height: 48,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                children: [
                  _buildFilterChip(
                    filterKey: 'all',
                    label: 'Todos (${_comisiones.length})',
                    accentColor: accentColor,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    filterKey: 'pendiente',
                    label: 'Pendientes (${pendientes.length})',
                    accentColor: accentColor,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    filterKey: 'pagado',
                    label: 'Cobrados (${cobrados.length})',
                    accentColor: accentColor,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textSecondary: textSecondary,
                  ),
                ],
              ),
            ),

            
            Expanded(
              child: refresh.isLoading
                  ? Center(child: CircularProgressIndicator(color: accentColor))
                  : refresh.error.isNotEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  refresh.error,
                                  style: GoogleFonts.inter(color: Colors.redAccent),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: accentColor),
                                  onPressed: () => _fetchComisiones(),
                                  child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _fetchComisiones(isManual: true),
                          color: accentColor,
                          backgroundColor: cardBg,
                          child: _filteredComisiones.isEmpty
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
                                            Icon(Icons.folder_open_rounded, size: 48, color: textSecondary.withValues(alpha: 0.5)),
                                            const SizedBox(height: 16),
                                            Text(
                                              'No se encontraron registros',
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
                                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
                                  itemCount: _filteredComisiones.length,
                                  itemBuilder: (context, index) {
                                    final item = _filteredComisiones[index];
                                    final double amount = double.tryParse((item['comision'] ?? item['monto'] ?? 0).toString()) ?? 0.0;
                                    final isPendiente = (int.tryParse(item['estado']?.toString() ?? '0') ?? 0) == 1;

                                    return Card(
                                      color: cardBg,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(color: borderColor, width: 1),
                                      ),
                                      margin: const EdgeInsets.only(top: 10),
                                      elevation: 0,
                                      child: InkWell(
                                        onTap: () => _showComisionDetail(item),
                                        borderRadius: BorderRadius.circular(16),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        _formatDate(item['fecha_crea']),
                                                        style: GoogleFonts.inter(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.bold,
                                                          color: textPrimary,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        _formatTime(item['fecha_crea']),
                                                        style: GoogleFonts.inter(
                                                          fontSize: 12,
                                                          color: textSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        'Comisión de Venta',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 12,
                                                          color: textSecondary,
                                                        ),
                                                      ),
                                                      if (item['codigo_venta'] != null || item['codigo'] != null) ...[
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          '#${item['codigo_venta'] ?? item['codigo']}',
                                                          style: GoogleFonts.inter(
                                                            fontSize: 11,
                                                            color: accentColor,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  Text(
                                                    '\$${formatter.format(amount).replaceAll('CLP', '').trim()}',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.w900,
                                                      color: isPendiente ? accentColor : AppTheme.successColor,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Icon(
                                                    Icons.chevron_right_rounded,
                                                    color: textSecondary.withValues(alpha: 0.5),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
            ),
          ],
        ),
      ),
    ],
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
