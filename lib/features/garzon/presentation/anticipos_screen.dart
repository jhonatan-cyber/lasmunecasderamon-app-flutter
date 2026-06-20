import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../core/hooks/refresh_provider.dart';
import '../../../core/widgets/premium_fab.dart';
import '../../../core/widgets/premium_header.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../auth/data/auth_notifier.dart';

class AnticiposScreen extends ConsumerStatefulWidget {
  const AnticiposScreen({super.key});

  @override
  ConsumerState<AnticiposScreen> createState() => _AnticiposScreenState();
}

class _AnticiposScreenState extends ConsumerState<AnticiposScreen> {
  String _viewMode = 'solicitudes'; 
  String _filter = 'todos'; 

  List<dynamic> _solicitudes = [];
  List<dynamic> _pagos = [];

  
  double _montoMaximo = 0;
  double _montoAsistencia = 0;
  double _montoComisiones = 0;
  double _montoPropinas = 0;
  bool _tieneSolicitudPendiente = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchData());
  }

  Future<void> _fetchData({bool isManual = false}) async {
    final notifier = ref.read(refreshProvider('anticipos').notifier);
    notifier.startRefresh(isManual: isManual);

    try {
      final client = ref.read(apiClientProvider);

      final responses = await Future.wait([
        client.dio.get('/anticipos/solicitudes'),
        client.dio.get('/anticipos/user'),
        client.dio.get('/anticipos/maximo'),
      ]);

      final solicitudesRes = responses[0];
      final pagosRes = responses[1];
      final maximoRes = responses[2];

      List<dynamic> solList = [];
      if (solicitudesRes.data != null &&
          solicitudesRes.data['success'] == true) {
        solList = solicitudesRes.data['data'] ?? [];
      } else if (solicitudesRes.data is List) {
        solList = solicitudesRes.data;
      }

      List<dynamic> pagosList = [];
      if (pagosRes.data != null && pagosRes.data['success'] == true) {
        pagosList = pagosRes.data['data'] ?? [];
      } else if (pagosRes.data is List) {
        pagosList = pagosRes.data;
      }

      double maxMonto = 0;
      double maxAsist = 0;
      double maxComis = 0;
      double maxProp = 0;
      bool pendingSol = false;

      if (maximoRes.data != null &&
          maximoRes.data['success'] == true &&
          maximoRes.data['data'] != null) {
        final data = maximoRes.data['data'];
        maxMonto =
            double.tryParse(data['monto_maximo']?.toString() ?? '0') ?? 0.0;
        maxAsist =
            double.tryParse(data['monto_asistencia']?.toString() ?? '0') ?? 0.0;
        maxComis =
            double.tryParse(data['monto_comisiones']?.toString() ?? '0') ?? 0.0;
        maxProp =
            double.tryParse(data['monto_propinas']?.toString() ?? '0') ?? 0.0;
        pendingSol = data['tiene_solicitud_pendiente'] == true;
      }

      if (!mounted) return;
      setState(() {
        _solicitudes = solList;
        _pagos = pagosList;
        _montoMaximo = maxMonto;
        _montoAsistencia = maxAsist;
        _montoComisiones = maxComis;
        _montoPropinas = maxProp;
        _tieneSolicitudPendiente = pendingSol;
      });
      notifier.endRefresh();

      if (isManual) notifier.showSuccessSnack(context, 'Datos actualizados');
    } catch (e) {
      if (!mounted) return;
      notifier.endRefresh(error: 'Error al conectar con el servidor');
    }
  }

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(
      locale: 'es_CL',
      symbol: '\$',
      decimalDigits: 0,
    );
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

  String _normalizeEstado(dynamic estado) {
    final str = estado.toString().toLowerCase();
    if (str == '2' || str == 'pendiente') return 'pendiente';
    if (str == '1' ||
        str == 'confirmada' ||
        str == 'aprobado' ||
        str == 'aprobada') {
      return 'confirmada';
    }
    if (str == '0' ||
        str == 'pagada' ||
        str == 'pagado' ||
        str == 'entregada' ||
        str == 'entregado') {
      return 'pagada';
    }
    if (str == '3' || str == 'rechazada' || str == 'rechazado') {
      return 'rechazada';
    }
    return str;
  }

  Future<void> _solicitarAnticipo(double monto, String motivo) async {
    final client = ref.read(apiClientProvider);

    try {
      final response = await client.dio.post(
        '/anticipos/solicitudes',
        data: {'monto': monto, 'motivo': motivo},
      );

      if (response.data != null && response.data['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitud de anticipo enviada correctamente'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchData();
      } else {
        final msg =
            response.data['message'] ?? 'No se pudo enviar la solicitud';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Atención: $msg'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al enviar la solicitud'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openSolicitarModal() {
    if (_tieneSolicitudPendiente) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ya tienes una solicitud de anticipo pendiente de aprobación',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_montoMaximo <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes saldo disponible para solicitar anticipos'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final montoController = TextEditingController();
    final motivoController = TextEditingController();
    bool sending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 40,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        Text(
                          'Solicitar Anticipo',
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkSurfaceColor
                            : AppTheme.lightSurfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? AppTheme.darkBorderColor
                              : AppTheme.lightBorderColor,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL DISPONIBLE',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatCurrency(_montoMaximo),
                            style: GoogleFonts.inter(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildDesgloseItem(
                                'Asistencia',
                                _montoAsistencia,
                                isDark,
                              ),
                              _buildDesgloseItem(
                                'Comisiones',
                                _montoComisiones,
                                isDark,
                              ),
                              _buildDesgloseItem(
                                'Propinas',
                                _montoPropinas,
                                isDark,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    
                    TextFormField(
                      controller: montoController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monto a Solicitar',
                        prefixText: '\$ ',
                        hintText: 'Ej: 50000',
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Ingresa un monto';
                        }
                        final parsed = double.tryParse(val);
                        if (parsed == null || parsed <= 0) {
                          return 'Ingresa un monto válido';
                        }
                        if (parsed > _montoMaximo) {
                          return 'El monto máximo disponible es ${_formatCurrency(_montoMaximo)}';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    
                    TextFormField(
                      controller: motivoController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Motivo (Opcional)',
                        hintText: 'Ej: Emergencia médica',
                      ),
                    ),
                    const SizedBox(height: 24),

                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: AppTheme.getPrimaryButtonStyle(context).copyWith(
                          backgroundColor: WidgetStateProperty.all(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        onPressed: sending
                            ? null
                            : () async {
                                if (formKey.currentState?.validate() == true) {
                                  setModalState(() => sending = true);
                                  final double val = double.parse(
                                    montoController.text,
                                  );
                                  final navigator = Navigator.of(context);
                                  await _solicitarAnticipo(
                                    val,
                                    motivoController.text,
                                  );
                                  navigator.pop();
                                }
                              },
                        child: sending
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                'Enviar Solicitud',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDesgloseItem(String label, double val, bool isDark) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: isDark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _formatCurrency(val),
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentData = _viewMode == 'solicitudes' ? _solicitudes : _pagos;

    final filteredData = currentData.where((item) {
      if (_viewMode == 'solicitudes') {
        final estado = _normalizeEstado(item['estado']);
        if (_filter == 'pendiente') return estado == 'pendiente';
        if (_filter == 'aprobado') return estado == 'confirmada';
        if (_filter == 'rechazado') return estado == 'rechazada';
      } else {
        final estado = _normalizeEstado(item['estado']);
        return estado == 'pagada';
      }
      return true;
    }).toList();

    
    final double totalPendiente = _solicitudes
        .where((s) => _normalizeEstado(s['estado']) == 'pendiente')
        .fold(
          0.0,
          (sum, item) =>
              sum + (double.tryParse(item['monto']?.toString() ?? '0') ?? 0.0),
        );

    final double totalEnCaja = _solicitudes
        .where((s) => _normalizeEstado(s['estado']) == 'confirmada')
        .fold(
          0.0,
          (sum, item) =>
              sum + (double.tryParse(item['monto']?.toString() ?? '0') ?? 0.0),
        );

    final double totalPagado = _pagos
        .where((p) => _normalizeEstado(p['estado']) == 'pagada')
        .fold(
          0.0,
          (sum, item) =>
              sum + (double.tryParse(item['monto']?.toString() ?? '0') ?? 0.0),
        );

    final double activeSummaryAmount = _viewMode == 'solicitudes'
        ? totalPendiente
        : totalPagado;

    final accentTheme = ref.watch(accentColorProvider);
    final gradientColors = accentTheme.gradient;
    final refresh = ref.watch(refreshProvider('anticipos'));

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
      floatingActionButton: PremiumFAB(
        icon: const Icon(Icons.add, size: 28),
        onPressed: _openSolicitarModal,
      ),
      body: Column(
        children: [
          PremiumHeader(
            title: 'Anticipos',
            gradient: gradientColors,
            showRefreshButton: true,
            isRefreshing: refresh.isRefreshing,
            onRefresh: () => _fetchData(isManual: true),
          ),
          Expanded(
            child: FadeLoadingSwitcher(
              isLoading: refresh.isLoading,
              skeleton: _buildSkeletonGrid(),
              content: RefreshIndicator(
                onRefresh: () => _fetchData(isManual: true),
                color: Theme.of(context).colorScheme.primary,
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  children: [
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildMainTabButton(
                            title: 'Solicitudes',
                            isActive: _viewMode == 'solicitudes',
                            icon: Icons.document_scanner_rounded,
                            onTap: () => setState(() {
                              _viewMode = 'solicitudes';
                              _filter = 'todos';
                            }),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMainTabButton(
                            title: 'Historial',
                            isActive: _viewMode == 'anticipos',
                            icon: Icons.receipt_long_rounded,
                            onTap: () => setState(() {
                              _viewMode = 'anticipos';
                              _filter = 'todos';
                            }),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    
                    _buildSummaryCard(
                      isDark: isDark,
                      activeSummaryAmount: activeSummaryAmount,
                      totalEnCaja: totalEnCaja,
                      totalPendiente: totalPendiente,
                      totalPagado: totalPagado,
                    ),
                    const SizedBox(height: 16),

                    
                    if (_viewMode == 'solicitudes') ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterButton('todos', 'Todos', isDark),
                            const SizedBox(width: 8),
                            _buildFilterButton(
                              'pendiente',
                              'Solicitados',
                              isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterButton('aprobado', 'Aprobados', isDark),
                            const SizedBox(width: 8),
                            _buildFilterButton(
                              'rechazado',
                              'Rechazados',
                              isDark,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (refresh.error.isNotEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(                                refresh.error,
                            style: GoogleFonts.inter(
                              color: Colors.redAccent,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    else if (filteredData.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(40),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkSurfaceColor
                              : AppTheme.lightSurfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.darkBorderColor
                                : AppTheme.lightBorderColor,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.card_giftcard_rounded,
                              size: 48,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.lightTextSecondary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No se encontraron anticipos',
                              style: GoogleFonts.inter(
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredData.length,
                        itemBuilder: (context, index) {
                          final item = filteredData[index];
                          return _buildAnticipoCard(item, index, isDark);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
            Row(
              children: const [
                Expanded(child: SkeletonCard(lines: 1)),
                SizedBox(width: 12),
                Expanded(child: SkeletonCard(lines: 1)),
              ],
            ),
            const SizedBox(height: 16),
            const SkeletonCard(lines: 3),
            const SizedBox(height: 16),
            Row(
              children: const [
                Expanded(child: SkeletonCard(lines: 1)),
                SizedBox(width: 8),
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
      ),
    );
  }

  Widget _buildMainTabButton({
    required String title,
    required bool isActive,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : (isDark
                      ? AppTheme.darkSurfaceColor
                      : AppTheme.lightSurfaceColor),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : (isDark
                        ? AppTheme.darkBorderColor
                        : AppTheme.lightBorderColor),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive
                    ? Colors.white
                    : (isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isActive
                      ? Colors.white
                      : (isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required bool isDark,
    required double activeSummaryAmount,
    required double totalEnCaja,
    required double totalPendiente,
    required double totalPagado,
  }) {
    final color = _viewMode == 'solicitudes'
        ? AppTheme.warningColor
        : Theme.of(context).colorScheme.primary;

    return Container(
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
            _viewMode == 'solicitudes'
                ? 'SITUACIÓN DE SOLICITUDES'
                : 'ANTICIPOS ENTREGADOS',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(activeSummaryAmount),
            style: GoogleFonts.inter(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _viewMode == 'solicitudes'
                ? 'Solicitudes: ${_formatCurrency(totalPendiente)} | Aprobadas: ${_formatCurrency(totalEnCaja)}'
                : 'Total retirado históricamente: ${_formatCurrency(totalPagado)}',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String filterVal, String label, bool isDark) {
    final isActive = _filter == filterVal;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _filter = filterVal),
        borderRadius: BorderRadius.circular(9999),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : (isDark
                      ? AppTheme.darkSurfaceColor
                      : AppTheme.lightSurfaceColor),
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : (isDark
                        ? AppTheme.darkBorderColor
                        : AppTheme.lightBorderColor),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? Colors.white
                  : (isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnticipoCard(dynamic item, int index, bool isDark) {
    final estado = _normalizeEstado(item['estado']);
    final isPendiente = estado == 'pendiente';
    final isAprobado = estado == 'confirmada';
    final isRechazado = estado == 'rechazada';
    final isPagada = estado == 'pagada';

    final double monto =
        double.tryParse(item['monto']?.toString() ?? '0') ?? 0.0;

    String statusText = 'Desconocido';
    Color statusBg = Colors.grey;
    Color statusFg = Colors.black;

    if (isPendiente) {
      statusText = 'Pendiente';
      statusBg = isDark ? const Color(0x33F59E0B) : AppTheme.warningLightBg;
      statusFg = isDark ? AppTheme.warningColor : AppTheme.warningDarkColor;
    } else if (isAprobado) {
      statusText = 'Aprobado';
      statusBg = isDark ? const Color(0x3310B981) : AppTheme.successLightBg;
      statusFg = isDark ? AppTheme.successColor : AppTheme.successDarkColor;
    } else if (isRechazado) {
      statusText = 'Rechazado';
      statusBg = isDark ? const Color(0x33EF4444) : AppTheme.errorLightBg;
      statusFg = isDark ? AppTheme.errorColor : AppTheme.errorDarkColor;
    } else if (isPagada) {
      statusText = 'Pagado';
      statusBg = isDark ? const Color(0x333B82F6) : AppTheme.infoLightBg;
      statusFg = isDark ? AppTheme.infoColor : AppTheme.infoDarkColor;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        borderRadius: BorderRadius.circular(16),
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
                '#${item['id_solicitud'] ?? item['id_anticipo'] ?? index + 1}',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                _formatDate(item['fecha_crea']),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.lightTextPrimary,
                ),
              ),
            ],
          ),
          if (item['motivo'] != null &&
              item['motivo'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Motivo: ${item['motivo']}',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
            ),
          ],
          if (item['motivo_rechazo'] != null &&
              item['motivo_rechazo'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Rechazo: ${item['motivo_rechazo']}',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.redAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monto',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                ),
              ),
              Text(
                _formatCurrency(monto),
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
