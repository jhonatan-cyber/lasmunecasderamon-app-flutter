import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/hooks/set_state_provider.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/currency_text.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../auth/data/auth_notifier.dart';
import '../../data/solicitud_item.dart';

class CheckoutModalWidget extends ConsumerStatefulWidget {
  final SolicitudItem item;
  final VoidCallback onSuccess;

  const CheckoutModalWidget({
    super.key,
    required this.item,
    required this.onSuccess,
  });

  @override
  ConsumerState<CheckoutModalWidget> createState() =>
      _CheckoutModalWidgetState();
}

class _CheckoutModalWidgetState extends ConsumerState<CheckoutModalWidget> {
  List<dynamic> _details = [];
  Map<String, dynamic>? _clientData;
  bool _loading = true;

  
  String _metodoPago = 'efectivo';
  String _metodoPagoAdicional = '';
  bool _agregarPropina = false;
  int _selectedMinutes = 30;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final client = ref.read(apiClientProvider);

      final detailRes =
          await client.dio.get('/orders/detail?id=${widget.item.id}');

      if (detailRes.data != null && detailRes.data['success'] == true) {
        final List<dynamic> loadedDetails = detailRes.data['data'] ?? [];
        _details = loadedDetails;

        final firstItem = loadedDetails.isNotEmpty ? loadedDetails[0] : null;
        final clientId =
            firstItem?['cliente_id'] ?? widget.item.metodoPago;

        if (clientId != null && clientId.toString().isNotEmpty) {
          final clientRes = await client.dio.get('/clients?id=$clientId');
          if (clientRes.data != null &&
              clientRes.data['success'] == true) {
            _clientData = clientRes.data['data'];

            final double saldoVal =
                double.tryParse(
                      _clientData?['saldo']?.toString() ?? '0',
                    ) ??
                    0.0;
            if (saldoVal > 0) {
              _metodoPago = 'prepago';
            }
          }
        }

        final double tipVal =
            double.tryParse(firstItem?['propina']?.toString() ?? '0') ??
                0.0;
        if (tipVal > 0) {
          _agregarPropina = true;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _handleSubmitCheckout() async {
    ref.read(setStateProvider('checkout_modal').notifier).startSubmit();

    final double existingTip = _details.isNotEmpty
        ? (double.tryParse(
                _details[0]['propina']?.toString() ?? '0') ??
            0.0)
        : 0.0;
    final double subtotalBase = widget.item.monto - existingTip > 0
        ? widget.item.monto - existingTip
        : widget.item.monto;
    final double tipAmount = existingTip > 0
        ? existingTip
        : (_agregarPropina ? subtotalBase * 0.10 : 0.0);
    final double totalFinal = subtotalBase + tipAmount;

    final double saldoPrepago =
        _clientData != null
            ? (double.tryParse(
                    _clientData?['saldo']?.toString() ?? '0') ??
                0.0)
            : 0.0;
    double montoPrepago = 0;
    if (_metodoPago == 'prepago' &&
        _clientData != null &&
        saldoPrepago > 0) {
      montoPrepago =
          saldoPrepago < totalFinal ? saldoPrepago : totalFinal;
    }

    String finalMetodoPago = _metodoPago;
    String? finalMetodoAdicional;

    if (_metodoPago == 'prepago' &&
        saldoPrepago < totalFinal &&
        saldoPrepago > 0) {
      finalMetodoPago = 'prepago';
      finalMetodoAdicional =
          _metodoPagoAdicional.isNotEmpty ? _metodoPagoAdicional : 'efectivo';
    }

    final Map<String, dynamic> payload = {
      'id_pedido': widget.item.id,
      'cliente_id': _clientData?['id'],
      'metodo_pago': finalMetodoPago,
      'monto_prepago': montoPrepago,
      'duracion_habitacion': _selectedMinutes,
      'sub_total': subtotalBase,
      'total': totalFinal,
      'ganancia_tipo': 'fijo',
      'ganancia_monto': 0,
      'comision_por_cliente': false,
      'recompensa_binario': false,
      'recompensa_activos': false,
      'recompensa_activos_monto': 0,
      'ganancia_anfitriona': 0,
      'ganancia_garzon': 0,
      'ganancia_local': 0,
      'ganancia_empresa': 0,
      'total_comision': 0,
      'tiempo': _selectedMinutes,
      'usuarios': [],
      'detalles': _details.map((d) => {
            'producto_id': d['producto_id'],
            'cantidad': d['cantidad'],
            'precio': d['precio'],
            'sub_total': d['subtotal_detalle'] ??
                ((double.tryParse(d['cantidad']?.toString() ?? '0') ??
                        0.0) *
                    (double.tryParse(d['precio']?.toString() ?? '0') ??
                        0.0)),
          }).toList(),
    };

    if (finalMetodoAdicional != null) {
      payload['metodo_pago_adicional'] = finalMetodoAdicional;
    }

    if (tipAmount > 0) {
      payload['propina'] = tipAmount;
    }

    try {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.post('/sales', data: payload);

      if (response.data != null && response.data['success'] == true) {
        if (!mounted) return;
        AppSnackBar.showSuccess(
          context,
          'Pedido cobrado y cerrado con éxito',
        );
        Navigator.pop(context);
        widget.onSuccess();
      } else {
        final msg =
            response.data?['message'] ?? 'Error al liquidar el pedido';
        if (!mounted) return;
        AppSnackBar.showError(context, 'Error: $msg');
      }
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.showError(context, 'Error de red al liquidar pedido');
    } finally {
      if (mounted) {
        ref.read(setStateProvider('checkout_modal').notifier).endSubmit();
      }
    }
  }

  Future<void> _handleAddToCuenta() async {
    if (_clientData == null) return;
    ref.read(setStateProvider('checkout_modal').notifier).startSubmit();

    try {
      final detailsFormatted = _details.map((d) {
        final double qty =
            double.tryParse(d['cantidad']?.toString() ?? '0') ?? 0.0;
        final double prc =
            double.tryParse(d['precio']?.toString() ?? '0') ?? 0.0;
        return {
          'producto_id': d['producto_id'],
          'cantidad': qty,
          'precio': prc,
          'sub_total': qty * prc,
        };
      }).toList();

      final double subTotal = detailsFormatted.fold(
        0.0,
        (sum, d) => sum + (d['sub_total'] as double),
      );

      final payload = {
        'codigo':
            'CUENTA-${DateTime.now().millisecondsSinceEpoch}',
        'cliente_id': _clientData?['id'],
        'habitacion_id': _details.isNotEmpty
            ? _details[0]['habitacion_id']
            : null,
        'tiempo': _selectedMinutes,
        'metodo_pago': 'efectivo',
        'sub_total': subTotal,
        'total': subTotal,
        'total_comision': 0,
        'detalles': detailsFormatted,
      };

      final client = ref.read(apiClientProvider);
      final response = await client.dio.post('/cuentas', data: payload);

      if (response.data != null && response.data['success'] == true) {
        if (!mounted) return;
        AppSnackBar.showSuccess(
          context,
          'Pedido registrado en cuenta de ${_clientData?['name'] ?? ''}',
        );
        Navigator.pop(context);
        widget.onSuccess();
      } else {
        final msg =
            response.data?['message'] ?? 'Error al registrar en cuenta';
        if (!mounted) return;
        AppSnackBar.showError(context, 'Error: $msg');
      }
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.showError(context, 'Error de red al registrar cuenta');
    } finally {
      if (mounted) {
        ref.read(setStateProvider('checkout_modal').notifier).endSubmit();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double existingTip = _details.isNotEmpty
        ? (double.tryParse(
                _details[0]['propina']?.toString() ?? '0') ??
            0.0)
        : 0.0;
    final double subtotalBase = widget.item.monto - existingTip > 0
        ? widget.item.monto - existingTip
        : widget.item.monto;
    final double tipAmount = existingTip > 0
        ? existingTip
        : (_agregarPropina ? subtotalBase * 0.10 : 0.0);
    final double totalFinal = subtotalBase + tipAmount;

    final double saldoPrepago =
        _clientData != null
            ? (double.tryParse(
                    _clientData?['saldo']?.toString() ?? '0') ??
                0.0)
            : 0.0;
    final bool isMixed = _metodoPago == 'prepago' &&
        saldoPrepago > 0 &&
        saldoPrepago < totalFinal;
    final double restanteMixed = isMixed ? (totalFinal - saldoPrepago) : 0.0;

    final hasHabitacion =
        _details.isNotEmpty && _details[0]['habitacion_id'] != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkSurfaceColor
            : AppTheme.lightSurfaceColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border.all(
          color: isDark
              ? AppTheme.darkBorderColor
              : AppTheme.lightBorderColor,
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: _loading
          ? const SizedBox(
              height: 250,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: SkeletonCard(lines: 5),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cerrar Pedido',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Código: ${widget.item.codigo}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark
                            ? AppTheme.darkBorderColor
                            : AppTheme.lightBorderColor,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'GARZÓN',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _details.isNotEmpty
                                    ? (_details[0]['garzon']
                                            ?.toString() ??
                                        'N/A')
                                    : 'N/A',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: isDark
                              ? AppTheme.darkBorderColor
                              : AppTheme.lightBorderColor,
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'CLIENTE',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _details.isNotEmpty
                                    ? (_details[0]['cliente']
                                            ?.toString() ??
                                        'Sin registrar')
                                    : 'Sin registrar',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: isDark
                              ? AppTheme.darkBorderColor
                              : AppTheme.lightBorderColor,
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'LUGAR',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.item.roomName,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  
                  if (hasHabitacion) ...[
                    Text(
                      'TIEMPO HABITACIÓN',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [30, 45, 60, 90, 120].map((mins) {
                        final isSel = _selectedMinutes == mins;
                        return Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 2.0),
                            child: InkWell(
                              onTap: () =>
                                  setState(() => _selectedMinutes = mins),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSel
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                        : (isDark
                                              ? AppTheme.darkBorderColor
                                              : AppTheme.lightBorderColor),
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    '$mins min',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSel
                                          ? Colors.white
                                          : (isDark
                                                ? AppTheme.darkTextSecondary
                                                : AppTheme
                                                    .lightTextSecondary),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  
                  Text(
                    'PRODUCTOS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.03)
                          : Colors.black.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? AppTheme.darkBorderColor
                            : AppTheme.lightBorderColor,
                      ),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: _details.length,
                      itemBuilder: (context, idx) {
                        final det = _details[idx];
                        final qty =
                            int.tryParse(det['cantidad']?.toString() ?? '1') ??
                                1;
                        final price =
                            double.tryParse(
                                    det['precio']?.toString() ?? '0') ??
                                0.0;
                        final sub = qty * price;

                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            children: [
                              Text(
                                '${qty}x ',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  det['nombre']?.toString() ??
                                      det['producto_nombre']?.toString() ??
                                      'Producto',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Text(
                                formatCurrency(sub),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  
                  ..._buildPaymentSection(
                    isDark,
                    subtotalBase,
                    tipAmount,
                    totalFinal,
                    saldoPrepago,
                    isMixed,
                    restanteMixed,
                  ),

                  
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (_clientData != null)
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              onPressed: ref.watch(setStateProvider('checkout_modal')).isSubmitting
                                  ? null
                                  : _handleAddToCuenta,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: isDark
                                      ? AppTheme.darkBorderColor
                                      : AppTheme.lightBorderColor,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                'Ag. a Cuenta',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_clientData != null)
                        const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed:
                                ref.watch(setStateProvider('checkout_modal')).isSubmitting ? null : _handleSubmitCheckout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: ref.watch(setStateProvider('checkout_modal')).isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Cobrar \$${formatCurrency(totalFinal)}',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildPaymentSection(
    bool isDark,
    double subtotalBase,
    double tipAmount,
    double totalFinal,
    double saldoPrepago,
    bool isMixed,
    double restanteMixed,
  ) {
    return [
      
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Subtotal',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
          Text(
            formatCurrency(subtotalBase),
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
      if (tipAmount > 0) ...[
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Propina',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
            ),
            Text(
              '+ ${formatCurrency(tipAmount)}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ],
      const Divider(height: 24, thickness: 1),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'TOTAL',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            formatCurrency(totalFinal),
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: Colors.green,
            ),
          ),
        ],
      ),

      
      if (existingTip <= 0) ...[
        const SizedBox(height: 12),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Agregar propina del 10%',
            style: GoogleFonts.inter(fontSize: 12),
          ),
          value: _agregarPropina,
          onChanged: (v) {
            setState(() => _agregarPropina = v ?? false);
          },
          dense: true,
        ),
      ],

      
      const SizedBox(height: 8),
      Text(
        'Método de Pago',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        initialValue: _metodoPago,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: [
          'efectivo',
          'tarjeta',
          'transferencia',
          'prepago',
        ].map((m) {
          return DropdownMenuItem(
            value: m,
            child: Text(
              m == 'efectivo'
                  ? 'Efectivo'
                  : m == 'tarjeta'
                      ? 'Tarjeta'
                      : m == 'transferencia'
                          ? 'Transferencia'
                          : 'Prepago (Saldo)',
              style: const TextStyle(fontSize: 13),
            ),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) {
            setState(() => _metodoPago = val);
          }
        },
      ),

      if (isMixed) ...[
        const SizedBox(height: 8),
        Text(
          'Saldo insuficiente. Restan: ${formatCurrency(restanteMixed)}',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: _metodoPagoAdicional.isNotEmpty
              ? _metodoPagoAdicional
              : 'efectivo',
          decoration: const InputDecoration(
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            labelText: 'Pago Adicional',
          ),
          items: ['efectivo', 'tarjeta', 'transferencia'].map((m) {
            return DropdownMenuItem(
              value: m,
              child: Text(
                m == 'efectivo'
                    ? 'Efectivo'
                    : m == 'tarjeta'
                        ? 'Tarjeta'
                        : 'Transferencia',
                style: const TextStyle(fontSize: 13),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _metodoPagoAdicional = val);
            }
          },
        ),
      ],

      
      if (_clientData != null) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.blue.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: Colors.blueAccent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Cliente: ${_clientData?['name'] ?? ''} - '
                  'Saldo: ${formatCurrency(saldoPrepago)}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  double get existingTip => _details.isNotEmpty
      ? (double.tryParse(_details[0]['propina']?.toString() ?? '0') ?? 0.0)
      : 0.0;
}
