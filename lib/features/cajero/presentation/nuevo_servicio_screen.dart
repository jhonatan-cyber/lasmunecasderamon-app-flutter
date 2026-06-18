import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../core/hooks/refresh_provider.dart';
import '../../../core/hooks/set_state_provider.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/premium_header.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../auth/data/auth_notifier.dart';

class NuevoServicioScreen extends ConsumerStatefulWidget {
  const NuevoServicioScreen({super.key});

  @override
  ConsumerState<NuevoServicioScreen> createState() =>
      _NuevoServicioScreenState();
}

class _NuevoServicioScreenState extends ConsumerState<NuevoServicioScreen> {

  // Asset lists
  List<dynamic> _anfitrionas = [];
  List<dynamic> _habitaciones = [];
  List<dynamic> _clientes = [];
  bool _cajaAbierta = false;

  // Selected values
  dynamic _selectedRoom;
  final List<dynamic> _selectedHostesses = [];
  final List<dynamic> _selectedClients = [];

  // Form controllers & state
  final TextEditingController _precioServicioController = TextEditingController(
    text: "0",
  );
  final TextEditingController _balanceAmountController = TextEditingController(
    text: "0",
  );
  String _paymentMethod =
      'efectivo'; // efectivo, tarjeta, transferencia, prepago, mixto
  String _metodoPagoAdicional = ''; // additional method if prepago is partial

  // Mixed payments state
  final List<Map<String, dynamic>> _pagosMixtos =
      []; // { 'metodo': String, 'monto': double }

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _precioServicioController.dispose();
    _balanceAmountController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData({bool isManual = false}) async {
    if (!mounted) return;
    ref.read(refreshProvider('nuevo_servicio').notifier).startRefresh(isManual: isManual);

    try {
      final client = ref.read(apiClientProvider);

      final responses = await Future.wait([
        client.dio
            .get('/cashregister/status')
            .catchError(
              (_) => Response(
                requestOptions: RequestOptions(),
                data: {'success': false},
              ),
            ),
        client.dio
            .get('/anfitrionas')
            .catchError(
              (_) => Response(
                requestOptions: RequestOptions(),
                data: {'success': false},
              ),
            ),
        client.dio
            .get('/rooms')
            .catchError(
              (_) => Response(
                requestOptions: RequestOptions(),
                data: {'success': false},
              ),
            ),
        client.dio
            .get('/clients')
            .catchError(
              (_) => Response(
                requestOptions: RequestOptions(),
                data: {'success': false},
              ),
            ),
      ]);

      final cajaRes = responses[0];
      final anfitrionasRes = responses[1];
      final roomsRes = responses[2];
      final clientsRes = responses[3];

      bool hasOpenCaja = false;
      if (cajaRes.data != null && cajaRes.data['success'] == true) {
        hasOpenCaja = cajaRes.data['data']['hasOpenCaja'] ?? false;
      }

      List<dynamic> rawAnfitrionas = [];
      if (anfitrionasRes.data != null &&
          anfitrionasRes.data['success'] == true) {
        rawAnfitrionas = anfitrionasRes.data['data'] ?? [];
      } else if (anfitrionasRes.data is List) {
        rawAnfitrionas = anfitrionasRes.data;
      }

      List<dynamic> rawHabitaciones = [];
      if (roomsRes.data != null && roomsRes.data['success'] == true) {
        rawHabitaciones = roomsRes.data['data'] ?? [];
      }

      List<dynamic> rawClientes = [];
      if (clientsRes.data != null && clientsRes.data['success'] == true) {
        rawClientes = clientsRes.data['data'] ?? [];
      } else if (clientsRes.data is List) {
        rawClientes = clientsRes.data;
      }

      // Deduplicate by ID helper
      List<dynamic> deduplicate(List<dynamic> list, String idKey) {
        final seen = <String>{};
        final result = [];
        for (var item in list) {
          final id = (item[idKey] ?? item['id'] ?? '').toString();
          if (!seen.contains(id)) {
            seen.add(id);
            result.add(item);
          }
        }
        return result;
      }

      // Normalize rooms
      final habitacionesNormalizadas = rawHabitaciones.map((room) {
        final name =
            room['nombre'] ??
            room['name'] ??
            'Habitación ${room['numero'] ?? room['id_habitacion'] ?? room['id'] ?? ''}'
                .trim();
        return {
          ...room,
          'estado': room['estado'] ?? room['status'] ?? 0,
          'status': room['status'] ?? room['estado'] ?? 0,
          'precio':
              double.tryParse(room['precio']?.toString() ?? '') ??
              double.tryParse(room['price']?.toString() ?? '') ??
              0.0,
          'price':
              double.tryParse(room['price']?.toString() ?? '') ??
              double.tryParse(room['precio']?.toString() ?? '') ??
              0.0,
          'tiempo':
              int.tryParse(room['tiempo']?.toString() ?? '') ??
              int.tryParse(room['time']?.toString() ?? '') ??
              0,
          'time':
              int.tryParse(room['time']?.toString() ?? '') ??
              int.tryParse(room['tiempo']?.toString() ?? '') ??
              0,
          'nombre': name,
          'comision_anfitriona':
              double.tryParse(room['comision_anfitriona']?.toString() ?? '') ??
              0.0,
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _cajaAbierta = hasOpenCaja;
        _anfitrionas = deduplicate(rawAnfitrionas, 'id_usuario');
        _habitaciones = deduplicate(habitacionesNormalizadas, 'id_habitacion');
        _clientes = deduplicate(rawClientes, 'id_cliente');
      });
      ref.read(refreshProvider('nuevo_servicio').notifier).endRefresh();

      if (!hasOpenCaja) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Atención: Debes abrir la caja antes de crear servicios.',
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ref.read(refreshProvider('nuevo_servicio').notifier).endRefresh(error: 'Error al cargar los recursos iniciales del servicio');
    }
  }

  // Calculate pricing values
  Map<String, double> _calculateTotals() {
    final double roomPrice = _selectedRoom != null
        ? double.tryParse(_selectedRoom['precio']?.toString() ?? '0') ?? 0.0
        : 0.0;
    final int minutes = _selectedRoom != null
        ? int.tryParse(_selectedRoom['tiempo']?.toString() ?? '0') ?? 0
        : 0;

    final double inputPrecioServicio =
        double.tryParse(_precioServicioController.text.replaceAll('.', '')) ??
        0.0;

    final int numAnfitrionas = _selectedHostesses.isEmpty
        ? 1
        : _selectedHostesses.length;
    final int numClientes = _selectedClients.isEmpty
        ? 1
        : _selectedClients.length;

    final int multiplicadorTiempo = minutes == 60 ? 2 : 1;
    final int multiplicadorServicio = numAnfitrionas;

    final double comisionAnfitriona = _selectedRoom != null
        ? double.tryParse(
                _selectedRoom['comision_anfitriona']?.toString() ?? '0',
              ) ??
              0.0
        : 0.0;
    final bool tieneComision = comisionAnfitriona > 0;

    final double multiplicadorHabitacion = tieneComision
        ? 1.0
        : (numAnfitrionas > numClientes ? numAnfitrionas : numClientes)
              .toDouble();

    final double precioServicioActual =
        inputPrecioServicio * multiplicadorTiempo * multiplicadorServicio;
    final double precioHabitacionActual =
        roomPrice * multiplicadorTiempo * multiplicadorHabitacion;

    double calculatedIva = 0.0;
    if (_paymentMethod == 'tarjeta') {
      calculatedIva = (precioServicioActual * 0.20).floorToDouble();
    }

    double currentTotal =
        precioServicioActual + precioHabitacionActual + calculatedIva;

    if (_paymentMethod == 'tarjeta') {
      final double totalRedondeado = (currentTotal / 5000).ceil() * 5000.0;
      final double excedente = totalRedondeado - currentTotal;
      currentTotal = totalRedondeado;
      calculatedIva += excedente;
    }

    final double comisionPorAnfitriona =
        (tieneComision && _selectedHostesses.isNotEmpty)
        ? (comisionAnfitriona / _selectedHostesses.length).floorToDouble()
        : comisionAnfitriona;

    return {
      'subTotal': precioServicioActual,
      'iva': calculatedIva,
      'total': currentTotal,
      'precioHabitacionActual': precioHabitacionActual,
      'precioServicioActual': precioServicioActual,
      'comisionPorAnfitriona': comisionPorAnfitriona,
    };
  }

  // Generate random 8-character code
  String _generateCode() {
    final dt = DateTime.now().microsecondsSinceEpoch.toString();
    final hashStr = dt.substring(dt.length - 8);
    return 'SRV$hashStr';
  }

  // Update client prepago list after loading balance
  void _updateClientSaldo(dynamic clientId, double nuevoSaldo) {
    setState(() {
      _clientes = _clientes.map((c) {
        final id = c['id_cliente'] ?? c['id'];
        if (id.toString() == clientId.toString()) {
          return {...c, 'saldo': nuevoSaldo};
        }
        return c;
      }).toList();

      // Update selected client details
      if (_selectedClients.isNotEmpty) {
        final primaryId =
            (_selectedClients.first['id_cliente'] ??
                    _selectedClients.first['id'])
                .toString();
        if (primaryId == clientId.toString()) {
          _selectedClients[0] = {
            ..._selectedClients.first,
            'saldo': nuevoSaldo,
          };
        }
      }
    });
  }

  Future<void> _handleLoadBalance(dynamic clientData) async {
    final clientId = clientData['id_cliente'] ?? clientData['id'];
    if (clientId == null) return;

    final double amount =
        double.tryParse(_balanceAmountController.text.replaceAll('.', '')) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese un monto válido a cargar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final api = ref.read(apiClientProvider);
    final loadNotifier = ref.read(setStateProvider('nuevo_servicio').notifier);
    loadNotifier.startSubmit();

    try {
      final res = await api.dio.post(
        '/clients/prepago',
        data: {'cliente_id': clientId, 'monto': amount, 'tipo': 'CARGA'},
      );

      if (res.data != null && res.data['success'] == true) {
        final double nuevoSaldo =
            double.tryParse(
              res.data['data']['nuevo_saldo']?.toString() ?? '',
            ) ??
            0.0;
        _updateClientSaldo(clientId, nuevoSaldo);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saldo cargado correctamente. Nuevo Saldo: ${_formatCurrency(nuevoSaldo)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
        _balanceAmountController.text = "0";
      } else {
        final msg = res.data?['message'] ?? 'No se pudo cargar el saldo';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $msg'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al procesar la carga de saldo'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) loadNotifier.endSubmit();
    }
  }

  void _showCargarSaldoModal(dynamic clientData) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark
              ? AppTheme.darkSurfaceColor
              : AppTheme.lightSurfaceColor,
          title: Text(
            'Cargar Saldo Prepago',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cliente: ${clientData['nombre'] ?? ''} ${clientData['apellido'] ?? ''}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _balanceAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monto a Cargar (\$)',
                  prefixText: '\$ ',
                ),
                onChanged: (val) {
                  final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
                  if (clean.isEmpty) return;
                  final formatted = NumberFormat.currency(
                    locale: 'es_CL',
                    symbol: '',
                    decimalDigits: 0,
                  ).format(double.tryParse(clean)).trim();
                  _balanceAmountController.value = TextEditingValue(
                    text: formatted.replaceAll(',', '.'),
                    selection: TextSelection.collapsed(
                      offset: formatted.length,
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: GoogleFonts.inter(
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _handleLoadBalance(clientData),
              child: Text(
                'Cargar Saldo',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitServicio() async {
    if (!_cajaAbierta) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe abrir la caja antes de registrar servicios.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione una habitación o mesa'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedHostesses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione al menos una anfitriona'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final totals = _calculateTotals();
    final double total = totals['total']!;
    final double inputPrecioServicio =
        double.tryParse(_precioServicioController.text.replaceAll('.', '')) ??
        0.0;
    final double comisionAnfitriona =
        double.tryParse(
          _selectedRoom['comision_anfitriona']?.toString() ?? '0',
        ) ??
        0.0;
    final bool hasAnfitrionaComision = comisionAnfitriona > 0;

    // Mixed payment validation
    if (_paymentMethod == 'mixto') {
      final double totalIngresado = _pagosMixtos.fold(
        0.0,
        (sum, item) => sum + (item['monto'] as double),
      );
      if ((totalIngresado - total).abs() > 1.0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'El monto total ingresado (\$${_formatCurrency(totalIngresado)}) debe coincidir con el total (\$${_formatCurrency(total)})',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      if (_pagosMixtos.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Seleccione al menos 2 métodos de pago para pago mixto',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    // Prepago balance validation
    final primaryClient = _selectedClients.isNotEmpty
        ? _selectedClients.first
        : null;
    final double saldoPrepago = primaryClient != null
        ? double.tryParse(primaryClient['saldo']?.toString() ?? '0') ?? 0.0
        : 0.0;

    if (_paymentMethod == 'prepago') {
      if (primaryClient == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Seleccione un cliente para realizar el pago con prepago',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      if (saldoPrepago < total && _metodoPagoAdicional.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El saldo es insuficiente. Seleccione un método de pago adicional.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    if (_paymentMethod == 'mixto') {
      final prepagoItem = _pagosMixtos.firstWhere(
        (p) => p['metodo'] == 'prepago',
        orElse: () => {},
      );
      if (prepagoItem.isNotEmpty) {
        final double prepagoMonto = prepagoItem['monto'] as double;
        if (prepagoMonto > saldoPrepago) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'El monto de prepago ingresado excede el saldo disponible del cliente.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }
      }
    }

    final submitNotifier = ref.read(setStateProvider('nuevo_servicio').notifier);
    submitNotifier.startSubmit();
    final client = ref.read(apiClientProvider);

    try {
      final List<String> hostessesIds = _selectedHostesses
          .map((h) => (h['id_usuario'] ?? h['id']).toString())
          .toList();
      final List<String> clientsIds = _selectedClients
          .map((c) => (c['id_cliente'] ?? c['id']).toString())
          .toList();
      final String? mainClientId = primaryClient != null
          ? (primaryClient['id_cliente'] ?? primaryClient['id']).toString()
          : null;

      final Map<String, dynamic> payload = {
        'codigo': _generateCode(),
        'cliente_id': mainClientId,
        'clientes': clientsIds,
        'habitacion_id': (_selectedRoom['id_habitacion'] ?? _selectedRoom['id'])
            .toString(),
        'precio_habitacion': totals['precioHabitacionActual'],
        'precio_servicio': inputPrecioServicio,
        'iva': totals['iva'],
        'sub_total': hasAnfitrionaComision
            ? totals['precioHabitacionActual']
            : totals['subTotal'],
        'total': total,
        'tiempo': _selectedRoom['tiempo'] ?? 0,
        'fecha_crea': DateTime.now().toUtc().toIso8601String(),
        'metodo_pago': _paymentMethod,
        'usuarios': hostessesIds,
      };

      if (_paymentMethod == 'mixto') {
        payload['pagos_mixtos'] = _pagosMixtos;
        final prepagoItem = _pagosMixtos.firstWhere(
          (p) => p['metodo'] == 'prepago',
          orElse: () => {},
        );
        if (prepagoItem.isNotEmpty && (prepagoItem['monto'] as double) > 0) {
          payload['metodo_pago'] = 'prepago';
          payload['monto_prepago'] = prepagoItem['monto'];
        }
      } else if (_paymentMethod == 'prepago' && saldoPrepago < total) {
        payload['metodo_pago_adicional'] = _metodoPagoAdicional;
      }

      final response = await client.dio.post('/servicios', data: payload);

      if (response.data != null && response.data['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Servicio creado correctamente'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Return with delay to show snackbar
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) context.pop();
        });
      } else {
        final msg =
            response.data?['message'] ?? 'Error al registrar el servicio';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $msg'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error de conexión al registrar servicio'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) submitNotifier.endSubmit();
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

  void _showHostessSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkSurfaceColor
                    : AppTheme.lightSurfaceColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Seleccionar Anfitrionas',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _anfitrionas.length,
                      itemBuilder: (context, index) {
                        final host = _anfitrionas[index];
                        final hostId = host['id_usuario'] ?? host['id'];
                        final isSelected = _selectedHostesses.any(
                          (h) =>
                              (h['id_usuario'] ?? h['id']).toString() ==
                              hostId.toString(),
                        );

                        return CheckboxListTile(
                          value: isSelected,
                          title: Text(
                            host['nick'] ?? host['nombre'] ?? 'Anfitriona',
                          ),
                          subtitle: Text(
                            'Estado: ${host['status'] ?? 'Activa'}',
                          ),
                          activeColor: Theme.of(context).colorScheme.primary,
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                _selectedHostesses.add(host);
                              } else {
                                _selectedHostesses.removeWhere(
                                  (h) =>
                                      (h['id_usuario'] ?? h['id']).toString() ==
                                      hostId.toString(),
                                );
                              }
                            });
                            setState(() {}); // refresh outer screen
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showClientSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkSurfaceColor
                    : AppTheme.lightSurfaceColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Seleccionar Clientes',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _clientes.length,
                      itemBuilder: (context, index) {
                        final client = _clientes[index];
                        final clientId = client['id_cliente'] ?? client['id'];
                        final isSelected = _selectedClients.any(
                          (c) =>
                              (c['id_cliente'] ?? c['id']).toString() ==
                              clientId.toString(),
                        );

                        return CheckboxListTile(
                          value: isSelected,
                          title: Text(
                            '${client['nombre'] ?? ''} ${client['apellido'] ?? ''}'
                                .trim(),
                          ),
                          subtitle: Text(
                            'Saldo: ${_formatCurrency(double.tryParse(client['saldo']?.toString() ?? '0') ?? 0.0)}',
                          ),
                          activeColor: Theme.of(context).colorScheme.primary,
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                // Max 4 clients
                                if (_selectedClients.length >= 4) return;
                                _selectedClients.add(client);
                              } else {
                                _selectedClients.removeWhere(
                                  (c) =>
                                      (c['id_cliente'] ?? c['id']).toString() ==
                                      clientId.toString(),
                                );
                              }
                            });
                            setState(() {}); // refresh outer screen
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddMixedPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        String selectedMethod = 'efectivo';
        final amountController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark
                  ? AppTheme.darkSurfaceColor
                  : AppTheme.lightSurfaceColor,
              title: Text(
                'Agregar Medio de Pago',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedMethod,
                    items: const [
                      DropdownMenuItem(
                        value: 'efectivo',
                        child: Text('Efectivo'),
                      ),
                      DropdownMenuItem(
                        value: 'tarjeta',
                        child: Text('Tarjeta'),
                      ),
                      DropdownMenuItem(
                        value: 'transferencia',
                        child: Text('Transferencia'),
                      ),
                      DropdownMenuItem(
                        value: 'prepago',
                        child: Text('Prepago'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedMethod = val);
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Método de Pago',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monto (\$)',
                      prefixText: '\$ ',
                    ),
                    onChanged: (val) {
                      final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
                      if (clean.isEmpty) return;
                      final formatted = NumberFormat.currency(
                        locale: 'es_CL',
                        symbol: '',
                        decimalDigits: 0,
                      ).format(double.tryParse(clean)).trim();
                      amountController.value = TextEditingValue(
                        text: formatted.replaceAll(',', '.'),
                        selection: TextSelection.collapsed(
                          offset: formatted.length,
                        ),
                      );
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.inter(
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final double val =
                        double.tryParse(
                          amountController.text.replaceAll('.', ''),
                        ) ??
                        0.0;
                    if (val <= 0) return;
                    setState(() {
                      _pagosMixtos.removeWhere(
                        (p) => p['metodo'] == selectedMethod,
                      );
                      _pagosMixtos.add({
                        'metodo': selectedMethod,
                        'monto': val,
                      });
                    });
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Agregar',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final refreshState = ref.watch(refreshProvider('nuevo_servicio'));

    final totals = _calculateTotals();
    final double total = totals['total']!;
    final double roomPriceActual = totals['precioHabitacionActual']!;
    final double servicePriceActual = totals['precioServicioActual']!;
    final double iva = totals['iva']!;

    final double comisionAnfitriona = _selectedRoom != null
        ? double.tryParse(
                _selectedRoom['comision_anfitriona']?.toString() ?? '0',
              ) ??
              0.0
        : 0.0;
    final bool hasAnfitrionaComision = comisionAnfitriona > 0;

    final primaryClient = _selectedClients.isNotEmpty
        ? _selectedClients.first
        : null;
    final double saldoPrepago = primaryClient != null
        ? double.tryParse(primaryClient['saldo']?.toString() ?? '0') ?? 0.0
        : 0.0;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
      body: Column(
        children: [
          PremiumHeader(
            title: 'Lanzar Nuevo Servicio',
            showBackButton: true,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: FadeLoadingSwitcher(
              isLoading: refreshState.isLoading,
              skeleton: _buildSkeletonForm(),
              content: RefreshIndicator(
                onRefresh: () => _fetchInitialData(isManual: true),
                color: Theme.of(context).colorScheme.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (refreshState.error.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Colors.redAccent,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  refreshState.error,
                                  style: GoogleFonts.inter(
                                    color: Colors.redAccent,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      Text(
                        'Configuración del Servicio',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Selector de Habitación
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
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
                        child: DropdownButtonFormField<dynamic>(
                          initialValue: _selectedRoom,
                          hint: Text(
                            'Seleccionar Habitación / Mesa (Requerido)',
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          items: _habitaciones.map((room) {
                            return DropdownMenuItem<dynamic>(
                              value: room,
                              child: Text(
                                '${room['nombre']} - (${room['tiempo'] ?? 0} mins) - \$${(room['precio'] as double).toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedRoom = val;
                            });
                          },
                        ),
                      ),

                      // Selector de Anfitrionas
                      InkWell(
                        onTap: _showHostessSelectionSheet,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Anfitrionas (${_selectedHostesses.length})',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _selectedHostesses.isEmpty
                                          ? 'Seleccionar anfitrionas para el servicio'
                                          : _selectedHostesses
                                                .map(
                                                  (h) =>
                                                      h['nick'] ??
                                                      h['nombre'] ??
                                                      '',
                                                )
                                                .join(', '),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppTheme.darkTextSecondary
                                            : AppTheme.lightTextSecondary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Selector de Clientes
                      InkWell(
                        onTap: _showClientSelectionSheet,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Clientes (${_selectedClients.length})',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _selectedClients.isEmpty
                                          ? 'Seleccionar clientes (Opcional)'
                                          : _selectedClients
                                                .map(
                                                  (c) =>
                                                      '${c['nombre'] ?? ''} ${c['apellido'] ?? ''}'
                                                          .trim(),
                                                )
                                                .join(', '),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppTheme.darkTextSecondary
                                            : AppTheme.lightTextSecondary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Precio del Servicio (Si la habitación NO tiene comisión predefinida)
                      if (!hasAnfitrionaComision) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Precio Unitario del Servicio',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _precioServicioController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            prefixText: '\$ ',
                            hintText: '0',
                          ),
                          onChanged: (val) {
                            final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
                            if (clean.isEmpty) {
                              _precioServicioController.text = "0";
                              return;
                            }
                            final formatted = NumberFormat.currency(
                              locale: 'es_CL',
                              symbol: '',
                              decimalDigits: 0,
                            ).format(double.tryParse(clean)).trim();
                            _precioServicioController.value = TextEditingValue(
                              text: formatted.replaceAll(',', '.'),
                              selection: TextSelection.collapsed(
                                offset: formatted.length,
                              ),
                            );
                            setState(() {}); // Recalculate totals
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Card de Carga de Prepago del Cliente
                      if (primaryClient != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SALDO PREPAGO DEL CLIENTE',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatCurrency(saldoPrepago),
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: () =>
                                    _showCargarSaldoModal(primaryClient),
                                child: Text(
                                  'CARGAR',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),
                      Text(
                        'Método de Pago',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Selector de Forma de Pago Principal
                      Container(
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
                        child: DropdownButtonFormField<String>(
                          initialValue: _paymentMethod,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'efectivo',
                              child: Text('Efectivo'),
                            ),
                            const DropdownMenuItem(
                              value: 'tarjeta',
                              child: Text('Tarjeta'),
                            ),
                            const DropdownMenuItem(
                              value: 'transferencia',
                              child: Text('Transferencia'),
                            ),
                            if (primaryClient != null)
                              const DropdownMenuItem(
                                value: 'prepago',
                                child: Text('Prepago (Saldo Cliente)'),
                              ),
                            const DropdownMenuItem(
                              value: 'mixto',
                              child: Text('Mixto (Varios Métodos)'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _paymentMethod = val;
                                _metodoPagoAdicional = '';
                                _pagosMixtos.clear();

                                if (val == 'mixto' &&
                                    primaryClient != null &&
                                    saldoPrepago > 0) {
                                  _pagosMixtos.add({
                                    'metodo': 'prepago',
                                    'monto': saldoPrepago,
                                  });
                                }
                              });
                            }
                          },
                        ),
                      ),

                      // Si selecciona prepago y el saldo es insuficiente, solicita método adicional
                      if (_paymentMethod == 'prepago' &&
                          saldoPrepago < total) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Método de Pago Adicional (Saldo Insuficiente)',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
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
                          child: DropdownButtonFormField<String>(
                            initialValue: _metodoPagoAdicional.isEmpty
                                ? null
                                : _metodoPagoAdicional,
                            hint: const Text('Seleccionar método adicional'),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'efectivo',
                                child: Text('Efectivo'),
                              ),
                              DropdownMenuItem(
                                value: 'tarjeta',
                                child: Text('Tarjeta'),
                              ),
                              DropdownMenuItem(
                                value: 'transferencia',
                                child: Text('Transferencia'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _metodoPagoAdicional = val;
                                });
                              }
                            },
                          ),
                        ),
                      ],

                      // UI de Pagos Mixtos
                      if (_paymentMethod == 'mixto') ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Distribución de Pago Mixto',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.add_circle_outline_rounded,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    onPressed: _showAddMixedPaymentDialog,
                                  ),
                                ],
                              ),
                              const Divider(),
                              if (_pagosMixtos.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12.0,
                                  ),
                                  child: Text(
                                    'No ha agregado métodos de pago.',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppTheme.darkTextSecondary
                                          : AppTheme.lightTextSecondary,
                                    ),
                                  ),
                                )
                              else
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _pagosMixtos.length,
                                  itemBuilder: (context, index) {
                                    final item = _pagosMixtos[index];
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        item['metodo'].toString().toUpperCase(),
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _formatCurrency(
                                              item['monto'] as double,
                                            ),
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.redAccent,
                                              size: 18,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _pagosMixtos.removeAt(index);
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      // Desglose Financiero Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
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
                              'Resumen de Liquidación',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const Divider(height: 20),
                            _buildSummaryRow(
                              isDark,
                              'Habitación / Mesa',
                              _formatCurrency(roomPriceActual),
                            ),
                            _buildSummaryRow(
                              isDark,
                              'Servicio Temporal',
                              _formatCurrency(servicePriceActual),
                            ),
                            if (iva > 0)
                              _buildSummaryRow(
                                isDark,
                                'Recargo de Tarjeta (IVA/Com.)',
                                _formatCurrency(iva),
                                color: Colors.orange,
                              ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'TOTAL NETO',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                Text(
                                  _formatCurrency(total),
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20,
                                    color: Colors.green,
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
                          style: AppTheme.getPrimaryButtonStyle(context),            onPressed: ref.watch(setStateProvider('nuevo_servicio')).isSubmitting ? null : _submitServicio,
            child: ref.watch(setStateProvider('nuevo_servicio')).isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Registrar Lanzamiento de Servicio',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonForm() {
    return ShimmerWrapper(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: const [
            SkeletonCard(lines: 2),
            SizedBox(height: 12),
            SkeletonCard(lines: 2),
            SizedBox(height: 12),
            SkeletonCard(lines: 2),
            SizedBox(height: 12),
            SkeletonCard(lines: 2),
            SizedBox(height: 24),
            SkeletonCard(lines: 5),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    bool isDark,
    String label,
    String value, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
