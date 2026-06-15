import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../auth/data/auth_notifier.dart';

class CajaScreen extends ConsumerStatefulWidget {
  const CajaScreen({super.key});

  @override
  ConsumerState<CajaScreen> createState() => _CajaScreenState();
}

class _CajaScreenState extends ConsumerState<CajaScreen> {
  bool _loading = true;
  String _error = '';

  bool _cajaAbierta = false;
  Map<String, dynamic>? _cajaInfo;
  Map<String, dynamic>? _stats;

  final _montoController = TextEditingController();
  final _motivoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _montoController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _fetchData({bool isManual = false}) async {
    if (!mounted) return;
    setState(() {
      _loading = !isManual;
      _error = '';
    });

    try {
      final client = ref.read(apiClientProvider);

      // Concurrently fetch cashregister status and stats summary
      final responses = await Future.wait([
        client.dio.get('/cashregister/status'),
        client.dio.get('/cashregister?resumen=1'),
      ]);

      final statusRes = responses[0];
      final statsRes = responses[1];

      bool abierta = false;
      Map<String, dynamic>? info;
      if (statusRes.data != null && statusRes.data['success'] == true) {
        abierta = statusRes.data['data']?['hasOpenCaja'] == true;
        info = statusRes.data['data']?['cajaInfo'];
      }

      Map<String, dynamic>? statsData;
      if (statsRes.data != null && statsRes.data['success'] == true) {
        statsData = statsRes.data['data'];
      }

      if (!mounted) return;
      setState(() {
        _cajaAbierta = abierta;
        _cajaInfo = info;
        _stats = statsData;
        _loading = false;
      });

      if (isManual) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Datos de caja actualizados'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al cargar los datos de caja';
        _loading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);
    return format.format(amount);
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Sin fecha';
    try {
      final parsed = DateTime.parse(dateStr).toLocal();
      final formatter = DateFormat('dd MMM, HH:mm', 'es_CL');
      return formatter.format(parsed);
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _abrirCaja(double monto) async {
    final user = ref.read(authProvider).user;
    final client = ref.read(apiClientProvider);

    try {
      final response = await client.dio.post(
        '/cashregister',
        data: {
          'monto_apertura': monto,
          'usuario_id_apertura': user?.id ?? 1,
        },
      );

      if (response.data != null && response.data['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Caja abierta correctamente'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchData();
      } else {
        final msg = response.data?['message'] ?? 'Error al abrir caja';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $msg'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error de conexión al abrir caja'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _retirarEfectivo(double monto, String motivo) async {
    final user = ref.read(authProvider).user;
    final client = ref.read(apiClientProvider);
    final idCaja = _cajaInfo?['id_caja'];

    if (idCaja == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay caja activa para retirar'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    try {
      final response = await client.dio.post(
        '/cashregister/retiros',
        data: {
          'id_caja': idCaja,
          'monto': monto,
          'motivo': motivo,
          'usuario_id': user?.id ?? 1,
        },
      );

      if (response.data != null && response.data['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Retiro de ${_formatCurrency(monto)} realizado con éxito'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchData();
      } else {
        final msg = response.data?['message'] ?? 'Error al retirar efectivo';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $msg'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error de conexión al realizar retiro'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _cerrarCaja(double montoCierre) async {
    final user = ref.read(authProvider).user;
    final client = ref.read(apiClientProvider);
    final idCaja = _cajaInfo?['id_caja'];

    if (idCaja == null) return;

    try {
      final response = await client.dio.patch(
        '/cashregister',
        data: {
          'id_caja': idCaja,
          'monto_cierre': montoCierre,
          'usuario_id_cierre': user?.id ?? 1,
        },
      );

      if (response.data != null && response.data['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Caja cerrada correctamente y turno finalizado'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchData();
      } else {
        final msg = response.data?['message'] ?? 'Error al cerrar caja';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $msg'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error de conexión al cerrar caja'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAbrirCajaSheet() {
    _montoController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Apertura de Turno',
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ingresa el monto base de efectivo para iniciar la caja de este turno.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _montoController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monto de Apertura (\$)',
                      hintText: 'Ej: 100000',
                      prefixIcon: Icon(Icons.attach_money_rounded),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Ingresa un monto';
                      final n = double.tryParse(val);
                      if (n == null || n < 0) return 'Ingresa un número válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: AppTheme.getPrimaryButtonStyle(context).copyWith(
                        backgroundColor: WidgetStateProperty.all(Colors.green),
                      ),
                      onPressed: () async {
                        if (_formKey.currentState?.validate() == true) {
                          final double val = double.parse(_montoController.text);
                          final navigator = Navigator.of(context);
                          await _abrirCaja(val);
                          navigator.pop();
                        }
                      },
                      child: Text(
                        'Iniciar Turno',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRetiroCajaSheet() {
    _montoController.clear();
    _motivoController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final double disp = double.tryParse(_stats?['total_efectivo']?.toString() ?? '0') ?? 0.0;

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Retirar Efectivo',
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Retirar dinero en efectivo de la caja activa. Quedará registrado en el historial.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Efectivo disponible en caja: ${_formatCurrency(disp)}',
                          style: GoogleFonts.inter(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _montoController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monto a Retirar (\$)',
                      hintText: 'Ej: 20000',
                      prefixIcon: Icon(Icons.attach_money_rounded),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Ingresa un monto';
                      final n = double.tryParse(val);
                      if (n == null || n <= 0) return 'Ingresa un monto válido';
                      if (n > disp) return 'Monto supera el efectivo en caja';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _motivoController,
                    decoration: const InputDecoration(
                      labelText: 'Motivo del Retiro',
                      hintText: 'Ej: Entrega a administración',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Ingresa el motivo del retiro';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: AppTheme.getPrimaryButtonStyle(context).copyWith(
                        backgroundColor: WidgetStateProperty.all(Colors.orange),
                      ),
                      onPressed: () async {
                        if (_formKey.currentState?.validate() == true) {
                          final double val = double.parse(_montoController.text);
                          final navigator = Navigator.of(context);
                          await _retirarEfectivo(val, _motivoController.text);
                          navigator.pop();
                        }
                      },
                      child: Text(
                        'Confirmar Retiro',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCerrarCajaSheet() {
    final double totalNeto = double.tryParse(_stats?['balance_total']?.toString() ?? '0') ?? 0.0;
    final double apertura = double.tryParse(_stats?['monto_apertura']?.toString() ?? '0') ?? 0.0;
    final double efectivo = double.tryParse(_stats?['total_efectivo']?.toString() ?? '0') ?? 0.0;
    final double tarjeta = double.tryParse(_stats?['total_tarjeta']?.toString() ?? '0') ?? 0.0;
    final double transferencia = double.tryParse(_stats?['total_transferencia']?.toString() ?? '0') ?? 0.0;
    final double devoluciones = double.tryParse(_stats?['total_devoluciones']?.toString() ?? '0') ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cierre de Turno',
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Revisa el desglose de ingresos acumulados en el turno antes de proceder a cerrar la caja.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 16),

              // Breakdown items
              _buildBreakdownRow(isDark, 'Monto Apertura (Base)', _formatCurrency(apertura)),
              _buildBreakdownRow(isDark, 'Efectivo en Caja', _formatCurrency(efectivo)),
              _buildBreakdownRow(isDark, 'Ventas con Tarjeta', _formatCurrency(tarjeta)),
              _buildBreakdownRow(isDark, 'Ventas con Transferencias', _formatCurrency(transferencia)),
              if (devoluciones > 0)
                _buildBreakdownRow(isDark, 'Devoluciones / Anulaciones', '- ${_formatCurrency(devoluciones)}', isNegative: true),
              
              const Divider(height: 24, thickness: 1),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'BALANCE TOTAL',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    _formatCurrency(totalNeto),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.redAccent),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: AppTheme.getPrimaryButtonStyle(context).copyWith(
                    backgroundColor: WidgetStateProperty.all(Colors.redAccent),
                  ),
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await _cerrarCaja(totalNeto);
                    navigator.pop();
                  },
                  child: Text(
                    'Confirmar Cierre de Caja',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBreakdownRow(bool isDark, String label, String value, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isNegative ? Colors.redAccent : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
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

    final double balanceTotal = double.tryParse(_stats?['balance_total']?.toString() ?? '0') ?? 0.0;
    final double totalVentas = double.tryParse(_stats?['total_ventas']?.toString() ?? '0') ?? 0.0;
    final double totalServicios = double.tryParse(_stats?['total_servicios']?.toString() ?? '0') ?? 0.0;
    final double totalEfectivo = double.tryParse(_stats?['total_efectivo']?.toString() ?? '0') ?? 0.0;
    final double totalTarjeta = double.tryParse(_stats?['total_tarjeta']?.toString() ?? '0') ?? 0.0;
    final double totalTransferencia = double.tryParse(_stats?['total_transferencia']?.toString() ?? '0') ?? 0.0;
    final double totalIva = double.tryParse(_stats?['total_iva']?.toString() ?? '0') ?? 0.0;
    final double totalComisiones = double.tryParse(_stats?['total_comisiones']?.toString() ?? '0') ?? 0.0;
    final double totalPropina = double.tryParse(_stats?['total_propina']?.toString() ?? '0') ?? 0.0;
    final double totalAnticipo = double.tryParse(_stats?['total_anticipo']?.toString() ?? '0') ?? 0.0;
    final double efectivoEnCaja = double.tryParse(_stats?['efectivo_en_caja']?.toString() ?? '0') ?? 0.0;
    final double apertura = double.tryParse(_stats?['monto_apertura']?.toString() ?? '0') ?? 0.0;
    final int cantidadVentas = int.tryParse(_stats?['cantidad_ventas']?.toString() ?? '0') ?? 0;
    final int cantidadServicios = int.tryParse(_stats?['cantidad_servicios']?.toString() ?? '0') ?? 0;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        elevation: 0,
        title: Text(
          'Control de Caja',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
            onPressed: () => _fetchData(isManual: true),
          ),
        ],
      ),
      body: _loading
          ? _buildSkeletonGrid()
          : RefreshIndicator(
              onRefresh: () => _fetchData(isManual: true),
              color: AppTheme.primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error,
                                style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Status Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Status pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _cajaAbierta
                                      ? Colors.green.withValues(alpha: 0.12)
                                      : Colors.redAccent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: _cajaAbierta ? Colors.green : Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _cajaAbierta ? 'Caja Abierta' : 'Caja Cerrada',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _cajaAbierta ? Colors.green : Colors.redAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Shift Action Buttons
                              Row(
                                children: [
                                  if (_cajaAbierta) ...[
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange.withValues(alpha: 0.15),
                                        foregroundColor: Colors.orange,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                      icon: const Icon(Icons.arrow_downward_rounded, size: 14),
                                      label: Text('Retiro', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                                      onPressed: _showRetiroCajaSheet,
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                                        foregroundColor: Colors.redAccent,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                      icon: const Icon(Icons.lock_rounded, size: 14),
                                      label: Text('Cerrar', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                                      onPressed: _showCerrarCajaSheet,
                                    ),
                                  ] else ...[
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.withValues(alpha: 0.15),
                                        foregroundColor: Colors.green,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                                      label: Text('Abrir Caja', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                                      onPressed: _showAbrirCajaSheet,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          if (_cajaAbierta && _cajaInfo != null) ...[
                            const Divider(height: 24, thickness: 1),
                            Row(
                              children: [
                                Icon(Icons.schedule_rounded, size: 14, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  'Apertura: ${_formatDateTime(_cajaInfo!['fecha_apertura'])}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_cajaAbierta && _stats != null) ...[
                      // Metrics Cards Grid
                      GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.5,
                        ),
                        children: [
                          _buildDetailMetricCard(isDark, 'Balance Total', balanceTotal, Icons.account_balance_wallet_rounded, AppTheme.primaryColor),
                          _buildDetailMetricCard(isDark, 'Total Ventas', totalVentas, Icons.shopping_cart_rounded, Colors.green, subtitle: '$cantidadVentas ventas'),
                          _buildDetailMetricCard(isDark, 'Total Servicios', totalServicios, Icons.hotel_rounded, Colors.blueAccent, subtitle: '$cantidadServicios servicios'),
                          _buildDetailMetricCard(isDark, 'Efectivo', totalEfectivo, Icons.attach_money_rounded, Colors.orange),
                          _buildDetailMetricCard(isDark, 'Tarjetas', totalTarjeta, Icons.credit_card_rounded, Colors.purple),
                          _buildDetailMetricCard(isDark, 'Transferencias', totalTransferencia, Icons.swap_horizontal_circle_rounded, Colors.pink),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Shift Breakdown Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.bar_chart_rounded, color: AppTheme.primaryColor),
                                const SizedBox(width: 8),
                                Text(
                                  'Desglose del Turno',
                                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildBreakdownItem(isDark, 'Efectivo en Caja', efectivoEnCaja, color: Colors.green),
                            _buildBreakdownItem(isDark, 'Tarjetas', totalTarjeta),
                            _buildBreakdownItem(isDark, 'Transferencias', totalTransferencia),
                            _buildBreakdownItem(isDark, 'Monto Apertura', apertura),
                            _buildBreakdownItem(isDark, 'Servicios', totalServicios),
                            _buildBreakdownItem(isDark, 'Ventas', totalVentas),
                            _buildBreakdownItem(isDark, 'Anticipos Pagados', totalAnticipo, isNegative: true),
                            _buildBreakdownItem(isDark, 'Devoluciones', double.tryParse(_stats?['total_devoluciones']?.toString() ?? '0') ?? 0.0, isNegative: true),
                            _buildBreakdownItem(isDark, 'IVA', totalIva),
                            _buildBreakdownItem(isDark, 'Propinas', totalPropina),
                            _buildBreakdownItem(isDark, 'Comisiones', totalComisiones),
                            
                            const Divider(height: 24, thickness: 1),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'TOTAL INGRESADO',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                                ),
                                Text(
                                  _formatCurrency(balanceTotal),
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.primaryColor),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Empty state / Open shift suggestion
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.grey[850] : Colors.grey[100])!,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.wallet_rounded, size: 36, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Caja Cerrada',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Inicia el turno para poder registrar las ventas, servicios, propinas y retiros del local.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              style: AppTheme.getPrimaryButtonStyle(context).copyWith(
                                backgroundColor: WidgetStateProperty.all(Colors.green),
                                padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                              ),
                              icon: const Icon(Icons.power_settings_new_rounded, color: Colors.white),
                              label: Text('Iniciar Turno', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
                              onPressed: _showAbrirCajaSheet,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
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
          const SkeletonCard(lines: 3),
          const SizedBox(height: 20),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.5,
            ),
            children: List.generate(6, (i) => const SkeletonCard(lines: 2)),
          ),
          const SizedBox(height: 20),
          const SkeletonCard(lines: 5),
        ],
      ),
    );
  }

  Widget _buildDetailMetricCard(bool isDark, String label, double value, IconData icon, Color color, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatCurrency(value),
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(bool isDark, String label, double value, {Color? color, bool isNegative = false}) {
    if (value == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
          Text(
            isNegative ? '- ${_formatCurrency(value)}' : _formatCurrency(value),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color ?? (isNegative ? Colors.redAccent : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
            ),
          ),
        ],
      ),
    );
  }
}
