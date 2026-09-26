import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// `apiClientProvider` vive en el módulo de auth, como en el resto de los
// widgets compartidos que hacen fetch.
import '../../features/auth/data/auth_notifier.dart';
import '../report_service.dart';
import '../theme.dart';
import 'currency_text.dart';
import 'operations_calendar.dart';

/// Detalle de un evento (`GET /events/detail/{id}?type={type}`) — mismo fetch
/// que hace el administrativo del cajero, con el contenido del
/// `EventDetailModal` de Expo (recuadro + datos del evento + bloques por tipo).
/// [forceDark] mantiene la paleta oscura en pantallas que ya son dark-only
/// (el administrativo del cajero), sin depender del tema activo.
Future<void> showEventDetailModal(
  BuildContext context,
  LiquidationEvent event, {
  String? userRole,
  bool forceDark = false,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _EventDetailDialog(
      event: event,
      userRole: userRole,
      forceDark: forceDark,
    ),
  );
}

class _EventDetailDialog extends ConsumerStatefulWidget {
  const _EventDetailDialog({
    required this.event,
    this.userRole,
    this.forceDark = false,
  });

  final LiquidationEvent event;
  final String? userRole;
  final bool forceDark;

  @override
  ConsumerState<_EventDetailDialog> createState() => _EventDetailDialogState();
}

class _EventDetailDialogState extends ConsumerState<_EventDetailDialog> {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _historyDateFormat = DateFormat(
    'dd MMM HH:mm',
    'es_CL',
  );

  bool _isLoading = true;
  Map<String, dynamic>? _detail;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.get(
        '/events/detail/${widget.event.id}?type=${widget.event.type}',
      );
      final body = response.data;
      if (body is Map && body['success'] == true && body['data'] is Map) {
        if (!mounted) return;
        setState(() {
          _detail = Map<String, dynamic>.from(body['data'] as Map);
          _isLoading = false;
        });
        return;
      }
    } catch (_) {
      // Sin detalle adicional: se muestran los datos del propio evento.
    }
    if (mounted) setState(() => _isLoading = false);
  }

  /// Listas que pueden llegar como `List<dynamic>` o como lista de mapas.
  List<Map<String, dynamic>> _listOf(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _money(Object? value) {
    return formatCurrency(double.tryParse('${value ?? 0}') ?? 0);
  }

  String _nameOf(Map<String, dynamic> person) {
    return (person['nick'] ?? person['nombre'] ?? '').toString();
  }

  String _accionLabel(String accion) {
    const labels = {
      'solicitud': 'Solicitado',
      'aprobado': 'Aprobado por admin',
      'rechazado': 'Rechazado',
      'entregado': 'Entregado',
      'anulado': 'Anulado',
      'pendiente': 'Pendiente',
      'actualizado': 'Actualizado',
    };
    return labels[accion] ?? accion;
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'venta':
        return Icons.shopping_cart_rounded;
      case 'propina':
        return Icons.favorite_rounded;
      case 'comision':
        return Icons.star_rounded;
      case 'asistencia':
        return Icons.event_available_rounded;
      case 'servicio':
        return Icons.room_service_rounded;
      case 'anticipo':
        return Icons.payments_rounded;
      default:
        return Icons.monetization_on_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        widget.forceDark || Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final textPrimary = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final textSecondary = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;
    final borderColor = isDark
        ? AppTheme.darkBorderColor
        : AppTheme.lightBorderColor;
    final cardBg = isDark
        ? AppTheme.darkSurfaceColor
        : AppTheme.lightSurfaceColor;

    final event = widget.event;
    final isAnticipo = event.isAnticipo;
    final eventColor = isAnticipo
        ? operationsEventTypeColors['anticipo']!
        : (operationsEventTypeColors[event.type] ?? const Color(0xFF10B981));
    final status = liquidationStatusLabel(event.estado, event.type);
    final detail = _detail;
    final role = widget.userRole?.toLowerCase();

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: eventColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _iconFor(event.type),
                      color: eventColor,
                      size: 30,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Cerrar',
                    icon: Icon(Icons.close_rounded, color: textPrimary),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      event.label.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${isAnticipo ? '-' : '+'}${_money(event.amount)}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: eventColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(color: borderColor, height: 1),
                    const SizedBox(height: 12),
                    _row(
                      'Fecha y Hora',
                      _dateFormat.format(event.date),
                      textSecondary,
                      textPrimary,
                    ),
                    _row('Tipo', event.label, textSecondary, textPrimary),
                    if (event.subType != null)
                      _row(
                        'Origen',
                        event.subType == 'venta'
                            ? 'Venta'
                            : event.subType == 'servicio'
                            ? 'Servicio'
                            : 'General',
                        textSecondary,
                        textPrimary,
                      ),
                    if ((event.type == 'venta' || event.type == 'servicio') &&
                        event.codigo.isNotEmpty)
                      _row('Código', event.codigo, textSecondary, textPrimary),
                    if (status.isNotEmpty)
                      _statusRow(status, event.estado, textSecondary),
                    if (_isLoading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Cargando detalle...',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (detail != null)
                      ..._buildDetailBlocks(
                        detail,
                        role: role,
                        textSecondary: textSecondary,
                        textPrimary: textPrimary,
                        borderColor: borderColor,
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Entendido',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDetailBlocks(
    Map<String, dynamic> detail, {
    required String? role,
    required Color textSecondary,
    required Color textPrimary,
    required Color borderColor,
  }) {
    final blocks = <Widget>[
      const SizedBox(height: 8),
      Divider(color: borderColor, height: 1),
      const SizedBox(height: 12),
    ];

    if (detail['tipo'] == 'asistencia') {
      final descuento =
          double.tryParse('${detail['descuento_total'] ?? 0}') ?? 0;
      blocks.addAll([
        _row('Sueldo', _money(detail['sueldo']), textSecondary, textPrimary),
        _row(
          'Aporte',
          '-${_money(detail['aporte'])}',
          textSecondary,
          const Color(0xFFEF4444),
        ),
        if (descuento > 0)
          _row(
            'Desc. habitación (${detail['semanas_con_descuento'] ?? 0} sem.)',
            '-${_money(detail['descuento_total'])}',
            textSecondary,
            const Color(0xFFEF4444),
          ),
        const SizedBox(height: 8),
        Divider(color: borderColor, height: 1),
        const SizedBox(height: 8),
        _row(
          'Neto por asistencia',
          _money(detail['neto']),
          textSecondary,
          const Color(0xFF10B981),
        ),
      ]);
    }

    if (detail['tipo'] == 'anticipo') {
      final solicitante =
          detail['solicitante_nick'] ?? detail['solicitante_nombre'] ?? '';
      final observacion = detail['observacion'];
      final historial = _listOf(detail['historial']);
      blocks.addAll([
        if ('$solicitante'.isNotEmpty)
          _row('Solicitado por', '$solicitante', textSecondary, textPrimary),
        _row(
          'Monto',
          _money(detail['monto']),
          textSecondary,
          const Color(0xFFEF4444),
        ),
        if (observacion != null && '$observacion'.isNotEmpty)
          _row('Motivo', '$observacion', textSecondary, textPrimary),
        if (historial.isNotEmpty) ...[
          const SizedBox(height: 8),
          Divider(color: borderColor, height: 1),
          const SizedBox(height: 8),
          _sectionTitle('Historial', textPrimary),
          ...historial.map((item) {
            final fecha = DateTime.tryParse('${item['fecha_crea'] ?? ''}');
            final autor = item['usuario_accion_nick'];
            final meta = [
              if (autor != null) 'por $autor',
              if (fecha != null) _historyDateFormat.format(fecha),
            ].join(' — ');
            return _row(
              _accionLabel('${item['accion'] ?? ''}'),
              meta,
              textSecondary,
              textPrimary,
            );
          }),
        ],
      ]);
    }

    final garzon = detail['garzon_nick'] ?? detail['garzon_nombre'];
    final cajero = detail['cajero_nick'] ?? detail['cajero_nombre'];
    final cliente = detail['cliente_nombre'];
    final anfitrionas = _listOf(detail['anfitrionas']);
    final propinas = _listOf(detail['propinas_detalle']);
    final detalles = _listOf(detail['detalles']);
    final tiempo = detail['tiempo'];

    blocks.addAll([
      if (garzon != null && '$garzon'.isNotEmpty)
        _row('Realizó el pedido', '$garzon', textSecondary, textPrimary),
      if (cajero != null && '$cajero'.isNotEmpty)
        _row('Procesó la venta', '$cajero', textSecondary, textPrimary),
      if (detail['habitacion_nombre'] != null)
        _row(
          'Habitación',
          '${detail['habitacion_nombre']}',
          textSecondary,
          textPrimary,
        ),
      if (tiempo != null && '$tiempo'.isNotEmpty)
        _row('Tiempo', '$tiempo min', textSecondary, textPrimary),
      if (cliente != null &&
          '$cliente'.isNotEmpty &&
          '$cliente' != 'Sin cliente')
        _row('Cliente', '$cliente', textSecondary, textPrimary),
      if (anfitrionas.isNotEmpty && role != 'anfitriona')
        _row(
          'Anfitrionas',
          anfitrionas.map(_nameOf).where((n) => n.isNotEmpty).join(', '),
          textSecondary,
          textPrimary,
        ),
      // El reparto de propinas solo interesa a quien no cobra comisión; la
      // anfitriona ve su comisión por anfitriona (igual que en Expo).
      if (role != 'anfitriona' && propinas.isNotEmpty) ...[
        const SizedBox(height: 8),
        Divider(color: borderColor, height: 1),
        const SizedBox(height: 8),
        _row(
          'Propina total',
          _money(
            propinas.fold<double>(
              0,
              (sum, item) =>
                  sum + (double.tryParse('${item['monto'] ?? 0}') ?? 0),
            ),
          ),
          textSecondary,
          const Color(0xFF10B981),
        ),
        _row(
          'Dividida entre',
          '${propinas.length} (${propinas.map(_nameOf).join(', ')})',
          textSecondary,
          textPrimary,
        ),
      ],
      if (role == 'anfitriona' && anfitrionas.isNotEmpty) ...[
        const SizedBox(height: 8),
        _sectionTitle('Comisión por anfitriona', textPrimary),
        ...anfitrionas.map(
          (item) => _row(
            _nameOf(item),
            _money(item['comision']),
            textSecondary,
            const Color(0xFF10B981),
          ),
        ),
      ],
      if (detalles.isNotEmpty) ...[
        const SizedBox(height: 8),
        _sectionTitle('Productos', textPrimary),
        ...detalles.map(
          (item) => _row(
            '${item['cantidad'] ?? 1}x ${item['producto_nombre'] ?? ''}',
            _money(item['subtotal']),
            textSecondary,
            textSecondary,
          ),
        ),
      ],
    ]);

    return blocks;
  }

  Widget _sectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _statusRow(String status, int? estado, Color labelColor) {
    final color = estado == 3
        ? const Color(0xFFEF4444)
        : const Color(0xFF10B981);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Estado',
            style: GoogleFonts.inter(fontSize: 13, color: labelColor),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              status,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color labelColor, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 13, color: labelColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
