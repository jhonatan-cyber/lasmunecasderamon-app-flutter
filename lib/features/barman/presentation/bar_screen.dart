import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/global_messenger.dart';
import '../../auth/data/auth_notifier.dart';
import '../../../core/haptic_service.dart';
import '../../../core/refresh_bus.dart';
import '../../../core/theme.dart';
import 'widgets/envase_scanner_modal.dart';
import '../data/bar_service.dart';

/// Pantalla Bar del barman: espejo de `app/(app)/barman/bar.tsx` de la app
/// Expo con sus 4 tabs — Stock, Pendientes (transferencias), Historial
/// (movimientos) y Envases (paso 1 del control de envases con escáner).
class BarScreen extends ConsumerStatefulWidget {
  const BarScreen({super.key});

  @override
  ConsumerState<BarScreen> createState() => _BarScreenState();
}

class _BarScreenState extends ConsumerState<BarScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final BarService _bar;
  StreamSubscription<RefreshChannel>? _refreshSub;

  List<dynamic> _stock = [];
  List<dynamic> _transfers = [];
  List<dynamic> _movements = [];
  List<dynamic> _devoluciones = [];

  bool _loading = true;
  bool _loadingTransfers = false;
  bool _loadingMovements = false;
  bool _loadingEnvases = false;
  bool _verificando = false;
  int? _resolvingId;

  String _search = '';

  // Escaneo de envases (sesión actual, del más reciente al más antiguo).
  final List<Map<String, dynamic>> _sesion = [];
  static const int _maximoSesion = 50;
  int _consecutivo = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() {
      if (mounted) setState(() {});
      if (!_tabs.indexIsChanging) {
        if (_tabs.index == 2) _loadMovements();
        if (_tabs.index == 1) _fetchTransfers();
        if (_tabs.index == 3) _fetchDevoluciones();
      }
    });
    _bar = BarService(ref.read(apiClientProvider).dio);
    Future.microtask(() => _initialLoad());
    _refreshSub = RefreshBus.stream.listen((channel) {
      // `bar_shot_alert` del dispatcher: refresca el stock sin esperar al pull.
      if (channel == RefreshChannel.bar) {
        _fetchStock();
        _fetchTransfers();
      }
    });
  }

  @override
  void dispose() {
    _refreshSub?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    await Future.wait([_fetchStock(), _fetchTransfers()]);
    if (mounted) setState(() => _loading = false);
  }


  Future<void> _fetchStock() async {
    try {
      final res = await _bar.stock();
      if (mounted) setState(() => _stock = res);
    } catch (_) {}
  }

  Future<void> _fetchTransfers() async {
    setState(() => _loadingTransfers = true);
    try {
      final all = await _bar.pendingTransfers();
      final pendientes = all
          .where((t) => t is Map && t['estado']?.toString() == 'pendiente')
          .toList();
      if (mounted) setState(() => _transfers = pendientes);
    } catch (_) {
      if (mounted) {
        GlobalToast.show(
          title: 'Error',
          body: 'No se pudieron cargar las recepciones',
          kind: GlobalToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loadingTransfers = false);
    }
  }

  Future<void> _fetchMovements() async {
    setState(() => _loadingMovements = true);
    try {
      final res = await _bar.movements();
      if (mounted) setState(() => _movements = res);
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingMovements = false);
    }
  }

  void _loadMovements() {
    if (_loading) return;
    _fetchMovements();
  }

  Future<void> _fetchDevoluciones() async {
    setState(() => _loadingEnvases = true);
    try {
      final res = await _bar.containers();
      if (mounted) setState(() => _devoluciones = res);
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingEnvases = false);
    }
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      _fetchStock(),
      _fetchTransfers(),
      _fetchMovements(),
      _fetchDevoluciones(),
    ]);
  }

  Future<void> _resolver(Map transfer, bool aprobar) async {
    final id = transfer['id']?.toString() ?? '';
    if (id.isEmpty) return;
    setState(() => _resolvingId = transfer.hashCode);
    try {
      if (aprobar) {
        await _bar.acceptTransfer(id);
      } else {
        await _bar.rejectTransfer(id);
      }
      HapticService.light();
      GlobalToast.show(
        title: aprobar ? 'Transferencia aprobada' : 'Transferencia rechazada',
        body: '${transfer['producto_nombre'] ?? ''} · ${transfer['cantidad'] ?? ''}',
        kind: GlobalToastKind.success,
        duration: const Duration(seconds: 3),
      );
      await Future.wait([_fetchStock(), _fetchTransfers(), _fetchMovements()]);
    } catch (e) {
      GlobalToast.show(
        title: 'Error',
        body: 'No se pudo resolver la solicitud',
        kind: GlobalToastKind.error,
      );
    } finally {
      if (mounted) setState(() => _resolvingId = null);
    }
  }

  int get _totalBar => _stock.fold<int>(
      0, (acc, i) => acc + (int.tryParse('${i?['stock_bar'] ?? 0}') ?? 0));

  List<dynamic> get _stockFiltrado {
    var list = _stock
        .where((i) => (int.tryParse('${i?['stock_bar'] ?? 0}') ?? 0) > 0)
        .toList();
    final term = _search.trim().toLowerCase();
    if (term.isNotEmpty) {
      list = list.where((i) {
        if (i is! Map) return false;
        return '${i['producto_nombre'] ?? ''}'.toLowerCase().contains(term) ||
            '${i['nombre'] ?? ''}'.toLowerCase().contains(term) ||
            '${i['codigo_barras'] ?? ''}'.toLowerCase().contains(term);
      }).toList();
    }
    return list;
  }

  int get _entregados => _sesion.where((e) => e['ok'] == true).length;
  int get _rechazados => _sesion.length - _entregados;
  int get _pendientes => _devoluciones
      .where((d) => d is Map && d['pendiente_confirmacion'] == true)
      .length;

  /// Procesa un código escaneado (o tecleado) contra `POST /bar/containers`.
  /// Devuelve el veredicto para que el scanner muestre el aviso, o null si no
  /// se procesó (código vacío o error de red ya avisado).
  Future<({bool ok, String texto})?> _enviarEscaneo(String valor) async {
    final escaneo = valor.trim().toUpperCase();
    if (escaneo.isEmpty || _verificando) return null;
    setState(() => _verificando = true);
    try {
      final veredicto = await _bar.returnContainer(escaneo);
      final ok = veredicto['ok'] == true;
      final texto = ok
          ? '${veredicto['mensaje'] ?? 'Envase entregado'}'
          : motivoEnvase['${veredicto['motivo'] ?? ''}'] ??
              '${veredicto['mensaje'] ?? 'No se pudo entregar'}';

      HapticService.trigger(ok ? 'light' : 'medium');
      setState(() {
        _sesion.insert(0, {
          'id': '${DateTime.now().millisecondsSinceEpoch}-$escaneo-${_consecutivo++}',
          'codigo': escaneo,
          'ok': ok,
          'mensaje': texto,
          'hora': TimeOfDay.now().format(context),
        });
        if (_sesion.length > _maximoSesion) _sesion.removeLast();
      });

      // Un envase entregado ya aparece en el historial del almacén: refresca.
      if (ok) _fetchDevoluciones();
      return (ok: ok, texto: texto);
    } catch (e) {
      GlobalToast.show(
        title: 'No se pudo verificar el envase',
        body: 'Revisa tu conexión e intenta de nuevo',
        kind: GlobalToastKind.error,
        duration: const Duration(seconds: 4),
      );
      return null;
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final bg = isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor;
    final cardBg =
        isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor;
    final borderColor =
        isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor;
    final textSecondary =
        isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bar',
                style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            Text('$_totalBar unidades en barra',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          if (_tabs.index == 3)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded),
              onPressed: () => EnvaseScannerModal.show(
                context,
                onScanned: (codigo) => _enviarEscaneo(codigo).then(
                  (v) => v == null
                      ? null
                      : EnvaseVeredicto(ok: v.ok, texto: v.texto),
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: [
            const Tab(text: 'Stock'),
            Tab(
                text: _transfers.isEmpty
                    ? 'Pendientes'
                    : 'Pendientes (${_transfers.length})'),
            const Tab(text: 'Historial'),
            Tab(
                text: _pendientes > 0 ? 'Envases ($_pendientes)' : 'Envases'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ─── Stock ────────────────────────────────────────────────────────
          RefreshIndicator(
            onRefresh: _onRefresh,
            color: accent,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: TextField(
                          onChanged: (v) => setState(() => _search = v),
                          style: GoogleFonts.inter(fontSize: 14),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search, size: 20),
                            hintText: 'Buscar producto, presentación...',
                            hintStyle: GoogleFonts.inter(fontSize: 13),
                            isDense: true,
                            filled: true,
                            fillColor: cardBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: BorderSide(color: borderColor),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _stockFiltrado.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) =>
                              _stockTile(_stockFiltrado[index], cardBg,
                                  borderColor, accent),
                        ),
                      ),
                    ],
                  ),
          ),

          // ─── Pendientes (transferencias) ─────────────────────────────────
          RefreshIndicator(
            onRefresh: _onRefresh,
            color: accent,
            child: _loadingTransfers
                ? const Center(child: CircularProgressIndicator())
                : _transfers.isEmpty
                    ? _emptyState(
                        Icons.check_circle_outline_rounded,
                        'Sin recepciones pendientes',
                        textSecondary)
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _transfers.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _transferCard(_transfers[index], cardBg,
                                borderColor, isDark),
                      ),
          ),

          // ─── Historial (movimientos) ─────────────────────────────────────
          RefreshIndicator(
            onRefresh: _onRefresh,
            color: accent,
            child: _loadingMovements
                ? const Center(child: CircularProgressIndicator())
                : _movements.isEmpty
                    ? _emptyState(Icons.history, 'Sin movimientos',
                        textSecondary)
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _movements.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _movementTile(_movements[index], cardBg,
                                borderColor, isDark),
                      ),
          ),

          // ─── Envases ─────────────────────────────────────────────────────
          RefreshIndicator(
            onRefresh: () async {
              await _fetchDevoluciones();
            },
            color: accent,
            child: _loadingEnvases && _devoluciones.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _envasesPanel(cardBg, borderColor, isDark, accent),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(IconData icon, String text, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: textSecondary),
          const SizedBox(height: 10),
          Text(text,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textSecondary)),
        ],
      ),
    );
  }

  Widget _stockTile(Map item, Color cardBg, Color borderColor, Color accent) {
    final nombre = '${item['producto_nombre'] ?? ''}';
    final presentacion = '${item['nombre'] ?? ''}';
    final stock = int.tryParse('${item['stock_bar'] ?? 0}') ?? 0;
    final mlAbierta = int.tryParse('${item['ml_abierta'] ?? 0}') ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.sports_bar_rounded, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre,
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(presentacion,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: textSecondary2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$stock',
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w900)),
              if (mlAbierta > 0)
                Text('abierto · ${mlAbierta}ml',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: Colors.orange)),
            ],
          ),
        ],
      ),
    );
  }

  Color get textSecondary2 =>
      Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkTextSecondary
          : AppTheme.lightTextSecondary;

  Widget _transferCard(
      Map item, Color cardBg, Color borderColor, bool isDark) {
    final resolving = _resolvingId == item.hashCode;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${item['producto_nombre'] ?? ''}',
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
              '${item['presentacion_nombre'] ?? ''} · x${item['cantidad'] ?? ''} · de ${item['usuario_nombre'] ?? 'almacén'}',
              style:
                  GoogleFonts.inter(fontSize: 12, color: textSecondary2)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      resolving ? null : () => _resolver(item, false),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Rechazar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: BorderSide(
                        color: Colors.redAccent.withValues(alpha: 0.5)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: resolving ? null : () => _resolver(item, true),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Aceptar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _movementTile(
      Map item, Color cardBg, Color borderColor, bool isDark) {
    final tipo = '${item['tipo'] ?? ''}';
    final esEntrada = tipo == 'traspaso' || tipo == 'ingreso';
    final color = esEntrada ? const Color(0xFF10B981) : Colors.orange;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(esEntrada ? Icons.arrow_downward : Icons.arrow_upward,
              color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${item['producto_nombre'] ?? 'Producto'} · ${item['presentacion_nombre'] ?? ''}',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                    '$tipo · x${item['cantidad'] ?? ''} · ${item['usuario_nick'] ?? item['usuario_nombre'] ?? ''}',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: textSecondary2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _envasesPanel(
      Color cardBg, Color borderColor, bool isDark, Color accent) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.inventory_2_outlined, color: accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Entrega de envases al almacén',
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: Icon(Icons.qr_code_scanner_rounded, color: accent),
                    tooltip: 'Escanear envase',
                    onPressed: () => EnvaseScannerModal.show(
                      context,
                      onScanned: (codigo) => _enviarEscaneo(codigo).then(
                        (v) => v == null
                            ? null
                            : EnvaseVeredicto(ok: v.ok, texto: v.texto),
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                'Escanea o teclea el código de barras del envase vacío. El '
                'servidor verifica que es nuestro, que está vacío y que no se '
                'entregó antes; la recepción la confirma después el almacén.',
                style:
                    GoogleFonts.inter(fontSize: 12, color: textSecondary2),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _sessionChip('Entregados', '$_entregados',
                      const Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  _sessionChip('Rechazados', '$_rechazados', Colors.redAccent),
                  const Spacer(),
                  if (_sesion.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(_sesion.clear),
                      child: Text('Limpiar',
                          style: GoogleFonts.inter(fontSize: 12)),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_sesion.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _emptyState(
                Icons.qr_code_scanner_rounded,
                'Escanea el primer envase de la sesión',
                textSecondary2),
          )
        else
          ..._sesion.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (e['ok'] == true
                            ? const Color(0xFF10B981)
                            : Colors.redAccent)
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      e['ok'] == true
                          ? Icons.check_circle_outline_rounded
                          : Icons.error_outline_rounded,
                      color: e['ok'] == true
                          ? const Color(0xFF10B981)
                          : Colors.redAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${e['codigo']}',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3)),
                          Text('${e['mensaje']}',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: textSecondary2)),
                        ],
                      ),
                    ),
                    Text('${e['hora']}',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: textSecondary2)),
                  ],
                ),
              )),
        const SizedBox(height: 16),
        if (_pendientes > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Pendientes de recepción por almacén',
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ..._devoluciones
            .where((d) => d is Map && d['pendiente_confirmacion'] == true)
            .map((d) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_top_rounded,
                          color: Colors.orange, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${d['producto_nombre'] ?? 'Envase'} · ${d['codigo'] ?? ''}',
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )),
      ],
    );
  }

  Widget _sessionChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ',
              style: GoogleFonts.inter(fontSize: 12)),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }
}
