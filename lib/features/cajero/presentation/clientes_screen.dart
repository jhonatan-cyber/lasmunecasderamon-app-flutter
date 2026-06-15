import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/currency_text.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/premium_header.dart';
import '../../auth/data/auth_notifier.dart';

class Client {
  final String id;
  final String run;
  final String name;
  final String lastName;
  final String phone;
  final double saldo;
  final double deuda;
  final int status;

  Client({
    required this.id,
    required this.run,
    required this.name,
    required this.lastName,
    required this.phone,
    required this.saldo,
    required this.deuda,
    required this.status,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id']?.toString() ?? '',
      run: json['run']?.toString() ?? json['rut']?.toString() ?? '',
      name: json['name']?.toString() ?? json['nombre']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? json['apellido']?.toString() ?? '',
      phone: json['phone']?.toString() ?? json['telefono']?.toString() ?? '',
      saldo: double.tryParse(json['saldo']?.toString() ?? '0') ?? 0.0,
      deuda: double.tryParse(json['deuda']?.toString() ?? '0') ?? 0.0,
      status: json['status'] is int ? json['status'] : 1,
    );
  }
}

class ClientHistory {
  final String id;
  final String category; // 'CARGA', 'SERVICIO', 'CONSUMO'
  final double monto;
  final String metodoPago;
  final DateTime fechaCrea;
  final String motivo;
  final Map<String, dynamic>? detalle;

  ClientHistory({
    required this.id,
    required this.category,
    required this.monto,
    required this.metodoPago,
    required this.fechaCrea,
    required this.motivo,
    this.detalle,
  });

  factory ClientHistory.fromJson(Map<String, dynamic> json) {
    return ClientHistory(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      monto: double.tryParse(json['monto']?.toString() ?? '0') ?? 0.0,
      metodoPago: json['metodo_pago']?.toString() ?? json['metodoPago']?.toString() ?? '',
      fechaCrea: DateTime.tryParse(json['fecha_crea']?.toString() ?? json['fechaCrea']?.toString() ?? '') ?? DateTime.now(),
      motivo: json['motivo']?.toString() ?? '',
      detalle: json['detalle'] is Map ? Map<String, dynamic>.from(json['detalle']) : null,
    );
  }
}

class CajeroClientesScreen extends ConsumerStatefulWidget {
  const CajeroClientesScreen({super.key});

  @override
  ConsumerState<CajeroClientesScreen> createState() => _CajeroClientesScreenState();
}

class _CajeroClientesScreenState extends ConsumerState<CajeroClientesScreen> {
  List<Client> _clients = [];
  bool _loading = true;
  bool _refreshing = false;
  String _searchTerm = '';

  void _showErrorSnackBar(String message) {
    if (mounted) {
      AppSnackBar.showError(context, message);
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      AppSnackBar.showSuccess(context, message);
    }
  }

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _runCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _submitting = false;

  // Charge controllers
  final _amountCtrl = TextEditingController();
  final _primaryAmountCtrl = TextEditingController();
  final _secondaryAmountCtrl = TextEditingController();
  String _loadMetodoPago = 'efectivo';
  String _primaryMethod = 'efectivo';
  String _secondaryMethod = 'transferencia';

  // History states
  bool _historyLoading = false;
  List<ClientHistory> _historyData = [];

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _lastNameCtrl.dispose();
    _runCtrl.dispose();
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    _primaryAmountCtrl.dispose();
    _secondaryAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchClients({bool isManual = false}) async {
    if (!isManual && _clients.isEmpty) {
      setState(() => _loading = true);
    }
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.get('/clients');

      if (response.data != null) {
        final rawList = response.data['success'] == true ? response.data['data'] : response.data;
        if (rawList is List) {
          final List<Client> loaded = rawList.map((c) => Client.fromJson(c)).toList();
          loaded.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          setState(() {
            _clients = loaded;
            _loading = false;
            _refreshing = false;
          });
          return;
        }
      }
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _refreshing = false;
      });
      _showErrorSnackBar('No se pudieron descargar los clientes');
    }
  }

  Future<void> _saveClient(Client? editingClient) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final client = ref.read(apiClientProvider);
      final payload = {
        if (editingClient != null) 'id': editingClient.id,
        'name': _nameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'run': _runCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      };

      final response = editingClient != null
          ? await client.dio.put('/clients', data: payload)
          : await client.dio.post('/clients', data: payload);

      if (response.data != null && (response.data['success'] == true || response.data['id'] != null)) {
        _showSuccessSnackBar(editingClient != null ? 'Cliente actualizado' : 'Cliente creado');
        if (!mounted) return;
        Navigator.pop(context);
        _fetchClients(isManual: true);
      } else {
        _showErrorSnackBar(response.data['message'] ?? 'Error al guardar');
      }
    } catch (e) {
      _showErrorSnackBar('Error de conexión al guardar cliente');
    } finally {
      setState(() => _submitting = false);
    }
  }

  Future<void> _deleteClient(Client clientToDelete) async {
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.delete('/clients?id=${clientToDelete.id}');

      if (response.data != null && (response.data['success'] == true || response.data['message'] != null)) {
        _showSuccessSnackBar('Cliente eliminado correctamente');
        _fetchClients(isManual: true);
      } else {
        _showErrorSnackBar(response.data['message'] ?? 'No se pudo eliminar');
      }
    } catch (e) {
      _showErrorSnackBar('Error de conexión al eliminar cliente');
    }
  }

  Future<void> _loadBalance(Client clientToLoad) async {
    final rawAmountStr = _amountCtrl.text.replaceAll('.', '');
    final rawAmount = double.tryParse(rawAmountStr) ?? 0.0;

    if (rawAmount <= 0) {
      _showErrorSnackBar('Ingrese un monto válido');
      return;
    }

    if (_loadMetodoPago == 'mixto') {
      final pAmount = double.tryParse(_primaryAmountCtrl.text.replaceAll('.', '')) ?? 0.0;
      final sAmount = double.tryParse(_secondaryAmountCtrl.text.replaceAll('.', '')) ?? 0.0;

      if (pAmount + sAmount != rawAmount) {
        _showErrorSnackBar('Los montos primario y secundario no suman el total');
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final client = ref.read(apiClientProvider);
      final body = {
        'cliente_id': clientToLoad.id,
        'monto': rawAmount,
        'tipo': 'CARGA',
        'metodo_pago': _loadMetodoPago,
        'motivo': 'Carga de saldo prepago (Módulo Clientes)'
      };

      if (_loadMetodoPago == 'mixto') {
        body['pago_mixto'] = {
          'metodo_primario': _primaryMethod,
          'monto_primario': double.tryParse(_primaryAmountCtrl.text.replaceAll('.', '')) ?? 0.0,
          'metodo_secundario': _secondaryMethod,
          'monto_secundario': double.tryParse(_secondaryAmountCtrl.text.replaceAll('.', '')) ?? 0.0,
        };
      }

      final response = await client.dio.post('/clients/prepago', data: body);

      if (response.data != null && response.data['success'] == true) {
        _showSuccessSnackBar('Saldo cargado correctamente');
        if (!mounted) return;
        Navigator.pop(context);
        _fetchClients(isManual: true);
      } else {
        _showErrorSnackBar(response.data['message'] ?? 'Error al cargar saldo');
      }
    } catch (e) {
      _showErrorSnackBar('Error de conexión al cargar saldo');
    } finally {
      setState(() => _submitting = false);
    }
  }

  Future<void> _fetchHistory(String clientId, {bool isManual = false}) async {
    if (!isManual) {
      setState(() => _historyLoading = true);
    }

    try {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.get('/clients/history?cliente_id=$clientId');

      if (response.data != null) {
        final rawList = response.data['success'] == true ? response.data['data'] : response.data;
        if (rawList is List) {
          final List<ClientHistory> loaded = rawList.map((h) => ClientHistory.fromJson(h)).toList();
          setState(() {
            _historyData = loaded;
            _historyLoading = false;
          });
          return;
        }
      }
      setState(() {
        _historyLoading = false;
      });
    } catch (e) {
      setState(() {
        _historyLoading = false;
      });
      _showErrorSnackBar('No se pudo cargar el historial');
    }
  }

  String _formatNumberString(String value) {
    final clean = value.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return '';
    final numValue = int.parse(clean);
    final formatter = NumberFormat.decimalPattern('es_CL');
    return formatter.format(numValue);
  }

  void _onAmountChanged(String val, TextEditingController controller) {
    final formatted = _formatNumberString(val);
    if (formatted != val) {
      controller.text = formatted;
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: formatted.length),
      );
    }
  }

  void _onPrimaryAmountChanged(String val) {
    _onAmountChanged(val, _primaryAmountCtrl);
    final totalStr = _amountCtrl.text.replaceAll('.', '');
    final primaryStr = val.replaceAll('.', '');
    final total = int.tryParse(totalStr) ?? 0;
    final primary = int.tryParse(primaryStr) ?? 0;
    if (total >= primary) {
      final secondary = total - primary;
      final formattedSecondary = _formatNumberString(secondary.toString());
      _secondaryAmountCtrl.text = formattedSecondary;
      _secondaryAmountCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: formattedSecondary.length),
      );
    } else {
      _secondaryAmountCtrl.text = '0';
    }
  }

  void _onSecondaryAmountChanged(String val) {
    _onAmountChanged(val, _secondaryAmountCtrl);
    final totalStr = _amountCtrl.text.replaceAll('.', '');
    final secondaryStr = val.replaceAll('.', '');
    final total = int.tryParse(totalStr) ?? 0;
    final secondary = int.tryParse(secondaryStr) ?? 0;
    if (total >= secondary) {
      final primary = total - secondary;
      final formattedPrimary = _formatNumberString(primary.toString());
      _primaryAmountCtrl.text = formattedPrimary;
      _primaryAmountCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: formattedPrimary.length),
      );
    } else {
      _primaryAmountCtrl.text = '0';
    }
  }



  void _openClientFormDialog(Client? client) {
    if (client != null) {
      _nameCtrl.text = client.name;
      _lastNameCtrl.text = client.lastName;
      _runCtrl.text = client.run;
      _phoneCtrl.text = client.phone;
    } else {
      _nameCtrl.clear();
      _lastNameCtrl.clear();
      _runCtrl.clear();
      _phoneCtrl.clear();
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
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
                              client != null ? 'Editar Cliente' : 'Nuevo Cliente',
                              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameCtrl,
                          style: GoogleFonts.inter(fontSize: 14),
                          decoration: const InputDecoration(labelText: 'Nombre *'),
                          validator: (val) => (val == null || val.isEmpty) ? 'El nombre es obligatorio' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _lastNameCtrl,
                          style: GoogleFonts.inter(fontSize: 14),
                          decoration: const InputDecoration(labelText: 'Apellido *'),
                          validator: (val) => (val == null || val.isEmpty) ? 'El apellido es obligatorio' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _runCtrl,
                          style: GoogleFonts.inter(fontSize: 14),
                          decoration: const InputDecoration(labelText: 'RUN / RUT'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneCtrl,
                          style: GoogleFonts.inter(fontSize: 14),
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Teléfono'),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: AppTheme.getPrimaryButtonStyle(context),
                            onPressed: _submitting
                                ? null
                                : () async {
                                    setModalState(() => _submitting = true);
                                    await _saveClient(client);
                                    setModalState(() => _submitting = false);
                                  },
                            child: _submitting
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(client != null ? 'ACTUALIZAR' : 'CREAR CLIENTE'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openChargeDialog(Client client) {
    _amountCtrl.clear();
    _primaryAmountCtrl.clear();
    _secondaryAmountCtrl.clear();
    _loadMetodoPago = 'efectivo';
    _primaryMethod = 'efectivo';
    _secondaryMethod = 'transferencia';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cargar Saldo',
                                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${client.name} ${client.lastName}',
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'MONTO A CARGAR',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800),
                          prefixText: r'$ ',
                        ),
                        onChanged: (val) {
                          _onAmountChanged(val, _amountCtrl);
                          if (_loadMetodoPago == 'mixto') {
                            _primaryAmountCtrl.clear();
                            _secondaryAmountCtrl.clear();
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildPaymentMethodSelector(
                        selected: _loadMetodoPago,
                        onSelect: (val) {
                          setModalState(() {
                            _loadMetodoPago = val;
                          });
                        },
                        showMixto: true,
                      ),
                      if (_loadMetodoPago == 'mixto') ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Distribución de Pago',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: _buildPaymentMethodSelector(
                                      selected: _primaryMethod,
                                      onSelect: (val) {
                                        setModalState(() {
                                          _primaryMethod = val;
                                        });
                                      },
                                      showMixto: false,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: _primaryAmountCtrl,
                                      keyboardType: TextInputType.number,
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                                      decoration: const InputDecoration(hintText: r'$ 0', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                                      onChanged: (val) => setModalState(() => _onPrimaryAmountChanged(val)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: _buildPaymentMethodSelector(
                                      selected: _secondaryMethod,
                                      onSelect: (val) {
                                        setModalState(() {
                                          _secondaryMethod = val;
                                        });
                                      },
                                      showMixto: false,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: _secondaryAmountCtrl,
                                      keyboardType: TextInputType.number,
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                                      decoration: const InputDecoration(hintText: r'$ 0', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                                      onChanged: (val) => setModalState(() => _onSecondaryAmountChanged(val)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: AppTheme.getPrimaryButtonStyle(context),
                          onPressed: _submitting
                              ? null
                              : () async {
                                  setModalState(() => _submitting = true);
                                  await _loadBalance(client);
                                  setModalState(() => _submitting = false);
                                },
                          child: _submitting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text('CONFIRMAR CARGA'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openHistoryDialog(Client client) {
    _fetchHistory(client.id);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final double totalServicios = _historyData.where((i) => i.category == 'SERVICIO').fold(0.0, (sum, i) => sum + i.monto);
            final double totalConsumo = _historyData.where((i) => i.category == 'CONSUMO').fold(0.0, (sum, i) => sum + i.monto);
            final double totalCargas = _historyData.where((i) => i.category == 'CARGA').fold(0.0, (sum, i) => sum + i.monto);

            return Dialog(
              backgroundColor: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.8,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Historial de Cuenta',
                                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${client.name} ${client.lastName}',
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_historyLoading)
                        const Expanded(
                          child: Center(
                            child: CircularProgressIndicator(color: AppTheme.primaryColor),
                          ),
                        )
                      else ...[
                        // Totals summary row
                        Row(
                          children: [
                            Expanded(
                              child: _buildHistorySummaryPill(
                                label: 'Servicios',
                                amount: totalServicios,
                                color: Colors.blue,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildHistorySummaryPill(
                                label: 'Consumo',
                                amount: totalConsumo,
                                color: Colors.amber,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildHistorySummaryPill(
                                label: 'Cargado',
                                amount: totalCargas,
                                color: Colors.green,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: RefreshIndicator(
                            color: AppTheme.primaryColor,
                            onRefresh: () => _fetchHistory(client.id, isManual: true),
                            child: _historyData.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Sin movimientos',
                                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _historyData.length,
                                    itemBuilder: (context, idx) {
                                      final item = _historyData[idx];
                                      final isCarga = item.category == 'CARGA';
                                      final isServicio = item.category == 'SERVICIO';
                                      final isConsumo = item.category == 'CONSUMO';
                                      final color = isCarga ? Colors.green : isServicio ? Colors.blue : Colors.amber;
                                      final icon = isCarga ? Icons.arrow_upward_rounded : isServicio ? Icons.bed_rounded : Icons.shopping_cart_rounded;
                                      final label = isCarga ? 'Carga de Saldo' : isServicio ? 'Servicio' : 'Consumo';

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.015),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: color.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Icon(icon, color: color, size: 16),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        label,
                                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                                                      ),
                                                      Text(
                                                        DateFormat('dd MMM yyyy, HH:mm').format(item.fechaCrea),
                                                        style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: color.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child:                                Text(
                                  '${isCarga ? '+' : '-'}${formatCurrency(item.monto)}',
                                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: color),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (isServicio && item.detalle != null) ...[
                                              const SizedBox(height: 10),
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withValues(alpha: 0.05),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
                                                ),
                                                child: Column(
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        if (item.detalle!['habitacion'] != null)
                                                          _buildSmallDetailRow(Icons.bed_outlined, 'Habitación', item.detalle!['habitacion'].toString()),
                                                        if (item.detalle!['tiempo'] != null)
                                                          _buildSmallDetailRow(Icons.timer_outlined, 'Duración', '${item.detalle!['tiempo']} min'),
                                                      ],
                                                    ),
                                                    if (item.detalle!['anfitrionas'] is List && (item.detalle!['anfitrionas'] as List).isNotEmpty) ...[
                                                      const SizedBox(height: 8),
                                                      Row(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          const Icon(Icons.people_outline_rounded, size: 14, color: Colors.blue),
                                                          const SizedBox(width: 6),
                                                          Expanded(
                                                            child: Wrap(
                                                              spacing: 6,
                                                              runSpacing: 4,
                                                              children: (item.detalle!['anfitrionas'] as List).map((n) {
                                                                return Container(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                  decoration: BoxDecoration(
                                                                    color: Colors.blue.withValues(alpha: 0.12),
                                                                    borderRadius: BorderRadius.circular(6),
                                                                  ),
                                                                  child: Text(
                                                                    n.toString(),
                                                                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue),
                                                                  ),
                                                                );
                                                              }).toList(),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                            if (isConsumo && item.detalle != null) ...[
                                              const SizedBox(height: 10),
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.withValues(alpha: 0.05),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.1)),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    if (item.detalle!['productos'] is List) ...[
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.fastfood_outlined, size: 14, color: Colors.amber),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            'PRODUCTOS',
                                                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                      ...(item.detalle!['productos'] as List).map((p) {
                                                        final qty = p['cantidad'] ?? 1;
                                                        final name = p['nombre'] ?? 'Producto';
                                                        return Padding(
                                                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                                                          child: Row(
                                                            children: [
                                                              Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)),
                                                              const SizedBox(width: 6),
                                                              Text('${qty}x $name', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                                                            ],
                                                          ),
                                                        );
                                                      }),
                                                    ],
                                                    if (item.detalle!['anfitrionas'] is List && (item.detalle!['anfitrionas'] as List).isNotEmpty) ...[
                                                      const SizedBox(height: 8),
                                                      Row(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          const Icon(Icons.people_outline_rounded, size: 14, color: Colors.amber),
                                                          const SizedBox(width: 6),
                                                          Expanded(
                                                            child: Wrap(
                                                              spacing: 6,
                                                              runSpacing: 4,
                                                              children: (item.detalle!['anfitrionas'] as List).map((n) {
                                                                return Container(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                  decoration: BoxDecoration(
                                                                    color: Colors.amber.withValues(alpha: 0.12),
                                                                    borderRadius: BorderRadius.circular(6),
                                                                  ),
                                                                  child: Text(
                                                                    n.toString(),
                                                                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber),
                                                                  ),
                                                                );
                                                              }).toList(),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    item.metodoPago == 'efectivo'
                                                        ? Icons.payments_outlined
                                                        : item.metodoPago == 'tarjeta'
                                                            ? Icons.credit_card_outlined
                                                            : item.metodoPago == 'transferencia'
                                                                ? Icons.swap_horiz_outlined
                                                                : item.metodoPago == 'prepago'
                                                                    ? Icons.account_balance_wallet_outlined
                                                                    : Icons.shuffle_outlined,
                                                    size: 10,
                                                    color: Colors.grey,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    item.metodoPago.toUpperCase(),
                                                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistorySummaryPill({
    required String label,
    required double amount,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5),
          ),
          const SizedBox(height: 2),
          Text(
            formatCurrency(amount),
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSmallDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.blue),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.blue)),
            Text(value, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSelector({
    required String selected,
    required Function(String) onSelect,
    required bool showMixto,
  }) {
    final methods = [
      {'id': 'efectivo', 'label': 'Efectivo', 'icon': Icons.money_rounded},
      {'id': 'tarjeta', 'label': 'Tarjeta', 'icon': Icons.credit_card_rounded},
      {'id': 'transferencia', 'label': 'Transferencia', 'icon': Icons.swap_horiz_rounded},
      if (showMixto) {'id': 'mixto', 'label': 'Mixto', 'icon': Icons.shuffle_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MÉTODO DE PAGO',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Colors.grey,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: methods.map((m) {
            final isSelected = selected == m['id'];
            return Expanded(
              child: GestureDetector(
                onTap: () => onSelect(m['id'] as String),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor.withValues(alpha: 0.15)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryColor : Colors.grey.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        m['icon'] as IconData,
                        size: 18,
                        color: isSelected ? AppTheme.primaryColor : Colors.grey,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m['label'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? AppTheme.primaryColor : Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _confirmDeleteClient(Client client) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Eliminar Cliente', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Text('¿Está seguro que desea eliminar a ${client.name} ${client.lastName}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteClient(client);
              },
              child: Text('Eliminar', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = MediaQuery.of(context).size.width >= 768;

    final filteredClients = _clients.where((c) {
      final s = _searchTerm.toLowerCase();
      return c.name.toLowerCase().contains(s) ||
          c.lastName.toLowerCase().contains(s) ||
          c.run.toLowerCase().contains(s) ||
          c.phone.toLowerCase().contains(s);
    }).toList();

    // Calculate totals
    double totalSaldo = 0.0;
    double totalDeuda = 0.0;
    for (var c in filteredClients) {
      totalSaldo += c.saldo;
      totalDeuda += c.deuda;
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
      body: Column(
        children: [
          // Shared gradient header
          PremiumHeader(
            title: 'Clientes',
            showBackButton: true,
            onBack: () => Navigator.pop(context),
            showRefreshButton: true,
            isRefreshing: _refreshing,
            onRefresh: () {
              setState(() => _refreshing = true);
              _fetchClients(isManual: true);
            },
            subtitle: 'Gestión de Clientes',
          ),

          // Buscador y Totales
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              children: [
                // Buscador
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          style: GoogleFonts.inter(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Buscar por nombre, RUN o teléfono...',
                            hintStyle: GoogleFonts.inter(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                            border: InputBorder.none,
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchTerm = val;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Summary metrics
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.account_balance_wallet_outlined, size: 16, color: Colors.green),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('TOTAL SALDO', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.green)),
                                Text(formatCurrency(totalSaldo), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.green)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 16, color: Colors.redAccent),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('TOTAL DEUDA', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                                Text(formatCurrency(totalDeuda), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.redAccent)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main list
          Expanded(
            child: FadeLoadingSwitcher(
              isLoading: _loading,
              skeleton: _buildSkeletonGrid(),
              content: RefreshIndicator(
                    color: AppTheme.primaryColor,
                    onRefresh: () => _fetchClients(isManual: true),
                    child: filteredClients.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.people_outline_rounded, size: 64, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchTerm.isEmpty ? 'No hay clientes registrados' : 'No se encontraron resultados',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: isTablet ? 2 : 1,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: isTablet ? 1.6 : 1.7,
                            ),
                            itemCount: filteredClients.length,
                            itemBuilder: (context, index) {
                              final c = filteredClients[index];
                              return Card(
                                elevation: 4,
                                color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => _openHistoryDialog(c),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      children: [
                                        // Left info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${c.name} ${c.lastName}',
                                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  const Icon(Icons.card_membership_outlined, size: 12, color: Colors.grey),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      c.run.isNotEmpty ? c.run : 'Sin RUN',
                                                      style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  const Icon(Icons.phone_android_outlined, size: 12, color: Colors.grey),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      c.phone.isNotEmpty ? c.phone : 'Sin Teléfono',
                                                      style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const Spacer(),
                                              // Saldo pill
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: c.saldo > 0 ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.wallet_rounded, size: 12, color: c.saldo > 0 ? Colors.green : Colors.grey),
                                                    const SizedBox(width: 6),
                                                    Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text('SALDO', style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.bold, color: c.saldo > 0 ? Colors.green : Colors.grey)),
                                                        Text(formatCurrency(c.saldo), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: c.saldo > 0 ? Colors.green : (isDark ? Colors.white : Colors.black))),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              // Deuda pill
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: c.deuda > 0 ? Colors.redAccent.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.warning_amber_rounded, size: 12, color: c.deuda > 0 ? Colors.redAccent : Colors.grey),
                                                    const SizedBox(width: 6),
                                                    Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text('DEUDA', style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.bold, color: c.deuda > 0 ? Colors.redAccent : Colors.grey)),
                                                        Text(formatCurrency(c.deuda), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: c.deuda > 0 ? Colors.redAccent : (isDark ? Colors.white : Colors.black))),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Actions Sidebar
                                        Container(
                                          width: 1,
                                          height: double.infinity,
                                          color: Colors.grey.withValues(alpha: 0.1),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            GestureDetector(
                                              onTap: () => _openHistoryDialog(c),
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                                child: const Icon(Icons.visibility_outlined, size: 18, color: Colors.purple),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            GestureDetector(
                                              onTap: () => _openChargeDialog(c),
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(10)),
                                                child: const Icon(Icons.account_balance_wallet_rounded, size: 18, color: Colors.white),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            GestureDetector(
                                              onTap: () => _openClientFormDialog(c),
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                                child: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            GestureDetector(
                                              onTap: () => _confirmDeleteClient(c),
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                                                child: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                              ),
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: () => _openClientFormDialog(null),
        icon: const Icon(Icons.person_add_rounded),
        label: Text('NUEVO CLIENTE', style: GoogleFonts.inter(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return ShimmerWrapper(
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.of(context).size.width >= 768 ? 2 : 1,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: MediaQuery.of(context).size.width >= 768 ? 1.6 : 1.7,
        ),
        itemCount: 5,
        itemBuilder: (context, index) => const SkeletonCard(showAvatar: true, lines: 4),
      ),
    );
  }
}