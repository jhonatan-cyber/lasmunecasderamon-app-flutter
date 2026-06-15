import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../auth/data/auth_notifier.dart';

class CuentasScreen extends ConsumerStatefulWidget {
  const CuentasScreen({super.key});

  @override
  ConsumerState<CuentasScreen> createState() => _CuentasScreenState();
}

class _CuentasScreenState extends ConsumerState<CuentasScreen> {
  bool _loading = true;
  String _error = '';
  List<dynamic> _cuentas = [];
  Map<String, dynamic> _resumen = {};
  Timer? _timer;
  String _searchQuery = '';
  String _activeTab = 'todas'; // 'todas' or 'pendientes'
  final _searchController = TextEditingController();

  // Active controllers for modals
  final _tipController = TextEditingController();
  final _motivoAnulacionController = TextEditingController();
  final _anulacionFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _fetchData();
    // Refresh UI every second to update active timers in real time
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tipController.dispose();
    _motivoAnulacionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> get _filteredCuentas {
    var list = _activeTab == 'pendientes'
        ? _cuentas.where((c) => (c['estado']?.toString() ?? '') == '1').toList()
        : _cuentas;
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list.where((c) {
        final codigo = (c['codigo']?.toString() ?? '').toLowerCase();
        final cliente = (c['cliente_nombre']?.toString() ?? '').toLowerCase();
        final room = (c['room_name']?.toString() ?? c['room_number']?.toString() ?? '').toLowerCase();
        return codigo.contains(query) || cliente.contains(query) || room.contains(query);
      }).toList();
    }
    return list;
  }

  Future<void> _fetchData({bool isManual = false}) async {
    if (!mounted) return;
    setState(() {
      _loading = !isManual;
      _error = '';
    });

    try {
      final client = ref.read(apiClientProvider);

      final responses = await Future.wait([
        client.dio.get('/cuentas?limit=50').catchError((_) => Response(requestOptions: RequestOptions(), data: {'success': false})),
        client.dio.get('/cuentas?tipo=resumen').catchError((_) => Response(requestOptions: RequestOptions(), data: {'success': false})),
      ]);

      final accountsRes = responses[0];
      final summaryRes = responses[1];

      List<dynamic> accountsList = [];
      if (accountsRes.data != null && accountsRes.data['success'] == true) {
        accountsList = accountsRes.data['data'] ?? [];
      }

      Map<String, dynamic> summaryMap = {};
      if (summaryRes.data != null && summaryRes.data['success'] == true) {
        summaryMap = summaryRes.data['data'] ?? {};
      }

      if (!mounted) return;
      setState(() {
        _cuentas = accountsList;
        _resumen = summaryMap;
        _loading = false;
      });

      if (isManual) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuentas actualizadas'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al cargar las cuentas activas';
        _loading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);
    return format.format(amount);
  }

  String _formatElapsedTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '00:00:00';
    try {
      final parsed = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(parsed);
      if (diff.isNegative) return '00:00:00';

      final hours = diff.inHours.toString().padLeft(2, '0');
      final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    } catch (_) {
      return '00:00:00';
    }
  }

  Future<void> _detenerTiempo(int idCuenta) async {
    final client = ref.read(apiClientProvider);
    try {
      final response = await client.dio.post('/cuentas/$idCuenta/stop');
      if (response.data != null && response.data['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tiempo de estancia detenido'), backgroundColor: Colors.green),
        );
        _fetchData();
      } else {
        final msg = response.data?['message'] ?? 'Error al detener tiempo';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $msg'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión al detener tiempo'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showCuentaActionSheet(dynamic cuenta) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int idCuenta = int.tryParse(cuenta['id_cuenta']?.toString() ?? '') ??
        int.tryParse(cuenta['id']?.toString() ?? '') ?? 0;

    if (idCuenta == 0) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mesa / Habitación: ${cuenta['room_name'] ?? cuenta['room_number'] ?? 'Sin número'}',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'Anfitriona: ${cuenta['anfitriona_nombre'] ?? 'Ninguna'} • Garzón: ${cuenta['garzon_nombre'] ?? 'Ninguno'}',
                style: GoogleFonts.inter(fontSize: 13, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.receipt_long_rounded, color: Colors.blueAccent),
                title: const Text('Ver Consumos y Detalles'),
                onTap: () {
                  Navigator.pop(context);
                  _showCuentaDetailModal(idCuenta, cuenta);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_shopping_cart_rounded, color: AppTheme.primaryColor),
                title: const Text('Agregar Productos'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/cajero/cuentas/agregar/$idCuenta');
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer_off_outlined, color: Colors.orange),
                title: const Text('Detener Tiempo / Parar Reloj'),
                onTap: () {
                  Navigator.pop(context);
                  _detenerTiempo(idCuenta);
                },
              ),
              ListTile(
                leading: const Icon(Icons.point_of_sale_rounded, color: Colors.green),
                title: const Text('Cobrar / Facturar Cuenta'),
                onTap: () {
                  Navigator.pop(context);
                  _showCuentaCobroModal(idCuenta, cuenta);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                title: const Text('Anular / Cancelar Cuenta'),
                onTap: () {
                  Navigator.pop(context);
                  _showCuentaAnulacionModal(idCuenta);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCuentaDetailModal(int idCuenta, dynamic cuentaShort) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Consumer(
              builder: (context, ref, child) {
                final client = ref.read(apiClientProvider);
                return FutureBuilder(
                  future: client.dio.get('/cuentas/$idCuenta'),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(color: AppTheme.primaryColor),
                        ),
                      );
                    }

                    if (snapshot.hasError || snapshot.data == null) {
                      return Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: const Center(
                          child: Text('Error al cargar detalles de la cuenta'),
                        ),
                      );
                    }

                    final res = snapshot.data!;
                    final cuenta = res.data != null && res.data['success'] == true
                        ? res.data['data']
                        : cuentaShort;

                    final listItems = (cuenta['items'] as List<dynamic>?) ?? [];
                    final double subtotal = double.tryParse(cuenta['subtotal']?.toString() ?? '0') ?? 0.0;
                    final double descuento = double.tryParse(cuenta['descuento']?.toString() ?? '0') ?? 0.0;
                    final double total = double.tryParse(cuenta['total']?.toString() ?? '0') ?? 0.0;

                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        border: Border.all(color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: ListView(
                        controller: scrollController,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Consumo Mesa ${cuenta['room_name'] ?? ''}',
                                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow(isDark, 'Apertura', _formatElapsedTime(cuenta['fecha_apertura'])),
                          _buildDetailRow(isDark, 'Garzón', cuenta['garzon_nombre'] ?? 'Ninguno'),
                          _buildDetailRow(isDark, 'Anfitriona', cuenta['anfitriona_nombre'] ?? 'Ninguna'),
                          _buildDetailRow(isDark, 'Cliente', cuenta['cliente_nombre'] ?? 'Cliente General'),
                          
                          const Divider(height: 32, thickness: 1),
                          Text(
                            'Detalle Consumos',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),

                          if (listItems.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: Text(
                                'No se han registrado consumos en esta comanda.',
                                style: GoogleFonts.inter(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                              ),
                            )
                          else
                            ...listItems.map((item) {
                              final double precio = double.tryParse(item['precio']?.toString() ?? '0') ?? 0.0;
                              final int qty = int.tryParse(item['cantidad']?.toString() ?? '1') ?? 1;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['producto_nombre'] ?? 'Producto',
                                            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                                          ),
                                          Text(
                                            '$qty x ${_formatCurrency(precio)}',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      _formatCurrency(precio * qty),
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              );
                            }),

                          const Divider(height: 32, thickness: 1),
                          _buildPriceRow('Subtotal', _formatCurrency(subtotal)),
                          if (descuento > 0)
                            _buildPriceRow('Descuento', '- ${_formatCurrency(descuento)}', color: Colors.redAccent),
                          _buildPriceRow('Consumo Estimado', _formatCurrency(total), isTotal: true, color: Colors.green),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(bool isDark, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 13, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: valueColor ?? (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isTotal = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isTotal ? 15 : 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isTotal ? 17 : 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showCuentaCobroModal(int idCuenta, dynamic cuenta) {
    final double totalConsumo = double.tryParse(cuenta['total']?.toString() ?? '0') ?? 0.0;
    _tipController.clear();
    String cobroMetodoPago = 'efectivo';
    bool applyTip = false;
    double tipAmount = 0.0;
    double cardFee = 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final double finalAmount = totalConsumo + tipAmount + cardFee;

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
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
                          'Cobrar Cuenta Mesa ${cuenta['room_name'] ?? ''}',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Totals Breakdown
                    _buildBreakdownRow(isDark, 'Subtotal Consumo', _formatCurrency(totalConsumo)),
                    
                    // Tip check
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Añadir Propina sugerida (10%)', style: GoogleFonts.inter(fontSize: 13)),
                      value: applyTip,
                      onChanged: (val) {
                        setLocalState(() {
                          applyTip = val ?? false;
                          if (applyTip) {
                            tipAmount = totalConsumo * 0.1;
                            _tipController.text = tipAmount.toStringAsFixed(0);
                          } else {
                            tipAmount = 0;
                            _tipController.clear();
                          }
                        });
                      },
                    ),

                    if (applyTip) ...[
                      TextFormField(
                        controller: _tipController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Monto Propina (\$)',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (val) {
                          setLocalState(() {
                            tipAmount = double.tryParse(val) ?? 0.0;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Payment Method selector
                    Text(
                      'Forma de Pago',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: cobroMetodoPago,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'efectivo', child: Text('Efectivo', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'transferencia', child: Text('Transferencia', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'prepago', child: Text('Prepago (Saldos)', style: TextStyle(fontSize: 13))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setLocalState(() {
                            cobroMetodoPago = val;
                            // Add 2% card fee if card payment
                            if (cobroMetodoPago == 'tarjeta') {
                              cardFee = totalConsumo * 0.02;
                            } else {
                              cardFee = 0.0;
                            }
                          });
                        }
                      },
                    ),
                    
                    if (cardFee > 0) ...[
                      const SizedBox(height: 8),
                      _buildBreakdownRow(isDark, 'Cargo tarjeta (2%)', _formatCurrency(cardFee), color: Colors.orange),
                    ],

                    const Divider(height: 24, thickness: 1),

                    _buildBreakdownRow(
                      isDark,
                      'MONTO TOTAL A COBRAR',
                      _formatCurrency(finalAmount),
                      isTotal: true,
                      color: Colors.green,
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: AppTheme.getPrimaryButtonStyle(context).copyWith(
                          backgroundColor: WidgetStateProperty.all(Colors.green),
                        ),
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          await _cobrarCuenta(idCuenta, cobroMetodoPago, tipAmount, cardFee);
                          navigator.pop();
                        },
                        child: Text(
                          'Completar Cobro',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
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

  Widget _buildBreakdownRow(bool isDark, String label, String value, {bool isTotal = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isTotal ? 14 : 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isTotal ? 18 : 13,
              fontWeight: FontWeight.bold,
              color: color ?? (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cobrarCuenta(int idCuenta, String metodoPago, double propina, double cargoTarjeta) async {
    final client = ref.read(apiClientProvider);
    final user = ref.read(authProvider).user;

    try {
      final response = await client.dio.post(
        '/cuentas/$idCuenta/cobrar',
        data: {
          'metodo_pago': metodoPago,
          'propina': propina,
          'cargo_tarjeta': cargoTarjeta,
          'usuario_id': user?.id ?? 1,
        },
      );

      if (response.data != null && response.data['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuenta cobrada correctamente. Mesa liberada.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchData();
      } else {
        final msg = response.data?['message'] ?? 'Error al cobrar cuenta';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $msg'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión al realizar cobro'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showCuentaAnulacionModal(int idCuenta) {
    _motivoAnulacionController.clear();
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
          title: Text(
            'Anulación de Cuenta',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: _anulacionFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '¿Estás seguro de que deseas anular esta cuenta por completo? Esta acción liberará la mesa.',
                  style: GoogleFonts.inter(fontSize: 13, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _motivoAnulacionController,
                  decoration: const InputDecoration(
                    labelText: 'Motivo de Anulación',
                    hintText: 'Ej: Cliente se retira / Error de registro',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'El motivo es requerido';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: GoogleFonts.inter(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () async {
                if (_anulacionFormKey.currentState?.validate() == true) {
                  final navigator = Navigator.of(context);
                  await _anularCuenta(idCuenta, _motivoAnulacionController.text);
                  navigator.pop();
                }
              },
              child: Text('Confirmar Anulación', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _anularCuenta(int idCuenta, String motivo) async {
    final client = ref.read(apiClientProvider);
    try {
      final response = await client.dio.post(
        '/cuentas/anulacion',
        data: {
          'id_cuenta': idCuenta,
          'motivo': motivo,
        },
      );

      if (response.data != null && response.data['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuenta anulada correctamente'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchData();
      } else {
        final msg = response.data?['message'] ?? 'Error al anular cuenta';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $msg'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión al anular cuenta'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final double totalAcumulado = double.tryParse(_resumen['total_estimado']?.toString() ?? '0') ?? 0.0;
    final int mesasOcupadas = int.tryParse(_resumen['mesas_ocupadas']?.toString() ?? '0') ?? 0;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        elevation: 0,
        title: Text(
          'Cuentas Activas',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
            onPressed: () => _fetchData(isManual: true),
          ),
        ],
      ),
      body: FadeLoadingSwitcher(
        isLoading: _loading,
        skeleton: _buildSkeletonList(),
        content: RefreshIndicator(
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

                    // Summary cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            isDark: isDark,
                            label: 'ESTIMADO CONSUMOS',
                            value: _formatCurrency(totalAcumulado),
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard(
                            isDark: isDark,
                            label: 'MESA/HAB OCUPADAS',
                            value: '$mesasOcupadas',
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Search bar
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Buscar por código, cliente o mesa...',
                          hintStyle: GoogleFonts.inter(
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            fontSize: 13,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),

                    // Tabs
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          _buildCuentaTab(isDark, 'todas', 'Todas', _cuentas.length),
                          const SizedBox(width: 8),
                          _buildCuentaTab(isDark, 'pendientes', 'Pendientes', _cuentas.where((c) => (c['estado']?.toString() ?? '') == '1').length),
                        ],
                      ),
                    ),

                    // Count and label
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _activeTab == 'pendientes' ? 'Cuentas Pendientes' : 'Salas y Mesas Activas',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_filteredCuentas.length} cuentas',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_filteredCuentas.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48.0),
                          child: Column(
                            children: [
                              Icon(_activeTab == 'pendientes' ? Icons.check_circle_outline_rounded : Icons.door_sliding_outlined, size: 48, color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
                              const SizedBox(height: 8),
                              Text(
                                _activeTab == 'pendientes' ? 'No hay cuentas pendientes' : 'No hay mesas activas',
                                style: GoogleFonts.inter(
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredCuentas.length,
                        itemBuilder: (context, index) {
                          final cuenta = _filteredCuentas[index];
                          final double total = double.tryParse(cuenta['total']?.toString() ?? '0') ?? 0.0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () => _showCuentaActionSheet(cuenta),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                'Mesa / Hab: ${cuenta['room_name'] ?? cuenta['room_number'] ?? 'Sin Nro'}',
                                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.timer_outlined, size: 10, color: Colors.green),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      _formatElapsedTime(cuenta['fecha_apertura']),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.green,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Anfitriona: ${cuenta['anfitriona_nombre'] ?? 'Ninguna'}',
                                            style: GoogleFonts.inter(fontSize: 13),
                                          ),
                                          Text(
                                            'Garzón: ${cuenta['garzon_nombre'] ?? 'Ninguno'}',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _formatCurrency(total),
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                            color: Colors.green,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 14,
                                          color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
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
                  ],
                ),
              ),
            ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_business_rounded),
        onPressed: () => context.push('/cajero/cuentas/nueva'),
      ),
    );
  }

  Widget _buildSummaryCard({
    required bool isDark,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
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
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ShimmerWrapper(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary cards skeleton
            Row(
              children: [
                const Expanded(child: SkeletonCard(lines: 2)),
                const SizedBox(width: 12),
                const Expanded(child: SkeletonCard(lines: 2)),
              ],
            ),
            const SizedBox(height: 20),
            // List skeleton
            ...List.generate(5, (i) => const SkeletonCard(lines: 4)),
          ],
        ),
      ),
    );
  }

  Widget _buildCuentaTab(bool isDark, String tabId, String label, int count) {
    final isActive = _activeTab == tabId;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _activeTab = tabId),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isActive ? null : Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (count > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white.withValues(alpha: 0.2) : AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: isActive ? Colors.white : AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? Colors.white
                      : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
