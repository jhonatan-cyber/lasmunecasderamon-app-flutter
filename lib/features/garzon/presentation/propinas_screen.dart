import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../auth/data/auth_notifier.dart';

class PropinasScreen extends ConsumerStatefulWidget {
  const PropinasScreen({super.key});

  @override
  ConsumerState<PropinasScreen> createState() => _PropinasScreenState();
}

class _PropinasScreenState extends ConsumerState<PropinasScreen> {
  String _filter = 'all'; // 'all', 'pendiente', 'pagado'
  bool _loading = true;
  String _error = '';
  List<dynamic> _propinas = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData({bool isManual = false}) async {
    if (!isManual) {
      setState(() => _loading = true);
    }
    setState(() => _error = '');

    try {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.get('/tips?tipo=detalle');

      List<dynamic> tipsList = [];
      if (response.data != null && response.data['success'] == true) {
        tipsList = response.data['data'] ?? [];
      } else if (response.data is List) {
        tipsList = response.data;
      }

      setState(() {
        _propinas = tipsList;
        _loading = false;
      });

      if (!mounted) return;
      if (isManual) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Propinas actualizadas'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Error al conectar con el servidor';
        _loading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);
    return format.format(amount);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Sin fecha';
    try {
      final parsed = DateTime.parse(dateStr);
      final formatter = DateFormat('dd MMM yyyy', 'es_CL');
      return formatter.format(parsed);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final parsed = DateTime.parse(dateStr);
      final formatter = DateFormat('HH:mm');
      return formatter.format(parsed);
    } catch (_) {
      return '';
    }
  }

  Future<void> _showTipDetail(dynamic item) async {
    final tipId = item['propina_id'] ?? item['id'];
    if (tipId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: FutureBuilder<Map<String, dynamic>>(
                future: _fetchDetailData(tipId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.primaryColor),
                    );
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return Center(
                      child: Text(
                        'Error al cargar detalles',
                        style: GoogleFonts.inter(color: Colors.redAccent),
                      ),
                    );
                  }

                  final data = snapshot.data!;
                  final parentTip = data['parentTip'] ?? {};
                  final saleDetail = data['saleDetail'] ?? {};
                  final products = saleDetail['productos'] != null
                      ? (saleDetail['productos'] is List
                          ? saleDetail['productos'] as List
                          : [])
                      : [];

                  final double propinaMonto = double.tryParse(parentTip['monto']?.toString() ?? '0') ?? 0.0;
                  final double comisionAnfitriona = double.tryParse(parentTip['comision_anfitriona']?.toString() ?? '0') ?? 0.0;
                  final double comisionCasa = double.tryParse(parentTip['comision_casa']?.toString() ?? '0') ?? 0.0;
                  final double netoGarzon = double.tryParse(parentTip['neto_garzon']?.toString() ?? '0') ?? 0.0;

                  return ListView(
                    controller: controller,
                    padding: const EdgeInsets.all(24),
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Detalles de Propina',
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (parentTip['codigo'] != null)
                                Text(
                                  'Venta: ${parentTip['codigo']}',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                  ),
                                ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Division Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL PROPINA REGISTRADA',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatCurrency(propinaMonto),
                              style: GoogleFonts.inter(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _buildDivisionItem('Anfitrionas', comisionAnfitriona, isDark),
                                _buildVerticalDivider(isDark),
                                _buildDivisionItem('Casa', comisionCasa, isDark),
                                _buildVerticalDivider(isDark),
                                _buildDivisionItem('Mi Neto', netoGarzon, isDark, highlight: true),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // General Commission Info
                      Text(
                        'DATOS DE LA ATENCIÓN',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Cliente', saleDetail['cliente_nombre'] ?? 'Particular', isDark),
                      _buildInfoRow('Habitación / Mesa', saleDetail['habitacion_nombre'] ?? 'Barra', isDark),
                      _buildInfoRow('Fecha de Venta', _formatDate(saleDetail['fecha_crea'] ?? parentTip['fecha_crea']), isDark),
                      const SizedBox(height: 24),

                      // Products list in sale
                      if (products.isNotEmpty) ...[
                        Text(
                          'PRODUCTOS',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: products.map<Widget>((p) {
                              final double sub = double.tryParse(p['subtotal']?.toString() ?? '0') ?? 0.0;
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${p['cantidad']}x ${p['nombre']}',
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      _formatCurrency(sub),
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Total Sale Amount
                      if (saleDetail['total'] != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Venta',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _formatCurrency(double.tryParse(saleDetail['total'].toString()) ?? 0.0),
                              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      const SizedBox(height: 32),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchDetailData(dynamic tipId) async {
    final client = ref.read(apiClientProvider);

    final response = await client.dio.get('/tips/$tipId');
    if (response.data != null && response.data['success'] == true) {
      final parentTip = response.data['data'] ?? {};
      final ventaId = parentTip['venta_id'];

      dynamic saleDetail = {};
      if (ventaId != null) {
        final saleResponse = await client.dio.get('/ventas/$ventaId');
        if (saleResponse.data != null) {
          saleDetail = saleResponse.data['data'] ?? saleResponse.data;
        }
      }

      return {
        'parentTip': parentTip,
        'saleDetail': saleDetail,
      };
    }

    throw Exception('Error loading detail');
  }

  Widget _buildDivisionItem(String label, double val, bool isDark, {bool highlight = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatCurrency(val),
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: highlight ? AppTheme.primaryColor : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider(bool isDark) {
    return Container(
      width: 1,
      height: 30,
      color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filteredData = _propinas.where((item) {
      final estado = item['estado']?.toString();
      if (_filter == 'pendiente') return estado == '1';
      if (_filter == 'pagado') return estado == '0';
      return true;
    }).toList();

    // Calculations
    final double totalPendiente = _propinas
        .where((a) => a['estado']?.toString() == '1')
        .fold(0.0, (sum, item) => sum + (double.tryParse(item['comision']?.toString() ?? item['monto']?.toString() ?? '0') ?? 0.0));

    final double totalGeneral = _propinas
        .fold(0.0, (sum, item) => sum + (double.tryParse(item['comision']?.toString() ?? item['monto']?.toString() ?? '0') ?? 0.0));

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
      appBar: AppBar(
        title: Text(
          'Propinas',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: _loading
          ? _buildSkeletonGrid()
          : RefreshIndicator(
              onRefresh: () => _fetchData(isManual: true),
              color: AppTheme.primaryColor,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                children: [
                  // Summary Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'TOTAL PENDIENTE',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatCurrency(totalPendiente),
                          style: GoogleFonts.inter(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Historial: ${_formatCurrency(totalGeneral)}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 12,
                              color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
                              margin: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            Text(
                              '${_propinas.length} ítems',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Filter Row
                  Row(
                    children: [
                      _buildFilterButton('all', 'Todas (${_propinas.length})', isDark),
                      const SizedBox(width: 8),
                      _buildFilterButton('pendiente', 'Pendientes (${_propinas.where((a) => a['estado']?.toString() == '1').length})', isDark),
                      const SizedBox(width: 8),
                      _buildFilterButton('pagado', 'Cobradas (${_propinas.where((a) => a['estado']?.toString() == '0').length})', isDark),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_error.isNotEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          _error,
                          style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 14),
                        ),
                      ),
                    )
                  else if (filteredData.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(40),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 48,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No se encontraron propinas registradas',
                            style: GoogleFonts.inter(
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    // ListView of items
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredData.length,
                      itemBuilder: (context, index) {
                        final item = filteredData[index];
                        return _buildTipCard(item, index, isDark);
                      },
                    ),
                ],
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
          const SkeletonCard(lines: 3),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(child: SkeletonCard(lines: 1)),
              SizedBox(width: 8),
              Expanded(child: SkeletonCard(lines: 1)),
              SizedBox(width: 8),
              Expanded(child: SkeletonCard(lines: 1)),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(4, (i) => const SkeletonCard(lines: 3)),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String filterVal, String label, bool isDark) {
    final isActive = _filter == filterVal;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _filter = filterVal),
          borderRadius: BorderRadius.circular(9999),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.primaryColor
                  : (isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor),
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(
                color: isActive
                    ? AppTheme.primaryColor
                    : (isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? Colors.white
                    : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTipCard(dynamic item, int index, bool isDark) {
    final estado = item['estado']?.toString();
    final isPendiente = estado == '1';
    final double amount = double.tryParse(item['comision']?.toString() ?? item['monto']?.toString() ?? '0') ?? 0.0;
    final code = item['codigo'] ?? item['codigo_venta'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showTipDetail(item),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        if (code != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.receipt_outlined, size: 12, color: AppTheme.primaryColor),
                                const SizedBox(width: 4),
                                Text(
                                  code,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPendiente
                                ? (isDark ? const Color(0x33065F46) : const Color(0xFFD1FAE5))
                                : (isDark ? const Color(0x331E3B8A) : const Color(0xFFDBEAFE)),
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Text(
                            isPendiente ? 'Pendiente' : 'Cobrado',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isPendiente
                                  ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46))
                                  : (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(item['fecha_crea']),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(item['fecha_crea']),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Propina',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                    Text(
                      _formatCurrency(amount),
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isPendiente ? AppTheme.primaryColor : const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Ver detalles',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 14, color: AppTheme.primaryColor),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
