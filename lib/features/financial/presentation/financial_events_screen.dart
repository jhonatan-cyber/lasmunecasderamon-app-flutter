import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/staggered_fade_in.dart';
import '../../auth/data/auth_notifier.dart';
import '../data/financial_notifier.dart';
import '../domain/financial_event.dart';




class FinancialEventsScreen extends ConsumerStatefulWidget {
  final String title;
  final String subtitle;
  final String type; 

  const FinancialEventsScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.type,
  });

  @override
  ConsumerState<FinancialEventsScreen> createState() =>
      _FinancialEventsScreenState();
}

class _FinancialEventsScreenState
    extends ConsumerState<FinancialEventsScreen> {

  final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
  final _dateFormat = DateFormat('d MMM yyyy', 'es');
  final _timeFormat = DateFormat('HH:mm', 'es');

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financialProvider(widget.type));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentTheme = ref.watch(accentColorProvider);

    final bg = isDark ? AppTheme.darkBgColor : const Color(0xFFF9FAFB);
    final cardBg = isDark ? AppTheme.darkSurfaceColor : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary =
        isDark ? AppTheme.darkTextSecondary : const Color(0xFF6B7280);
    final borderColor =
        isDark ? AppTheme.darkBorderColor : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          
          _buildHeader(accentTheme, textSecondary),
          
          _buildFilterChips(
            state.filter,
            accentTheme,
            cardBg,
            borderColor,
            textPrimary,
            textSecondary,
          ),
          
          Expanded(
            child: state.isLoading
                ? _buildSkeleton(accentTheme)
                : state.error != null
                    ? _buildError(state.error!, accentTheme)
                    : state.filteredEvents.isEmpty
                        ? _buildEmpty(accentTheme, textSecondary)
                        : _buildList(
                            state,
                            accentTheme,
                            cardBg,
                            textPrimary,
                            textSecondary,
                            borderColor,
                          ),
          ),
        ],
      ),
    );
  }

  

  Widget _buildHeader(dynamic accentTheme, Color textSecondary) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: accentTheme.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  

  Widget _buildFilterChips(
    String currentFilter,
    dynamic accentTheme,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    const filters = ['all', 'pendiente', 'pagado'];
    const labels = ['Todos', 'Pendiente', 'Pagado'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: List.generate(filters.length, (i) {
          final isSelected = currentFilter == filters[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                ref
                    .read(financialProvider(widget.type).notifier)
                    .setFilter(filters[i]);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? accentTheme.color : cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? accentTheme.color
                        : borderColor,
                  ),
                ),
                child: Text(
                  labels[i],
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  

  Widget _buildList(
    FinancialState state,
    dynamic accentTheme,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        await ref
            .read(financialProvider(widget.type).notifier)
            .refresh();
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: state.filteredEvents.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            
            if (state.hasChanges) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.successColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppTheme.successColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Datos actualizados',
                        style: GoogleFonts.inter(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }

          final event = state.filteredEvents[index - 1];

          return StaggeredFadeIn(
            index: index - 1,
            child: GestureDetector(
              onTap: () => _showDetail(event),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Row(
                  children: [
                    
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: event.isPagado
                            ? AppTheme.successColor.withValues(alpha: 0.1)
                            : AppTheme.warningColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        event.isPagado
                            ? Icons.check_circle_rounded
                            : Icons.schedule_rounded,
                        color: event.isPagado
                            ? AppTheme.successColor
                            : AppTheme.warningColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.codigoVenta ?? event.codigo ?? event.tipo,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(event.fechaCrea),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _currencyFormat.format(event.monto),
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: event.isPagado
                                ? AppTheme.successColor.withValues(alpha: 0.1)
                                : AppTheme.warningColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            event.estadoLabel,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: event.isPagado
                                  ? AppTheme.successColor
                                  : AppTheme.warningColor,
                            ),
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
    );
  }

  

  void _showDetail(FinancialEvent event) {
    
    bool detailLoading = true;
    Map<String, dynamic>? detailSale;
    Map<String, dynamic>? detailPropina;
    void Function(VoidCallback)? triggerRebuild;

    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            triggerRebuild = setSheetState;
            return _DetailSheet(
              event: event,
              loadingDetail: detailLoading,
              saleDetail: detailSale,
              parentPropina: detailPropina,
              currencyFormat: _currencyFormat,
              dateFormat: _dateFormat,
              onClose: () => Navigator.pop(context),
            );
          },
        );
      },
    );

    
    _fetchDetailData(event).then((result) {
      if (!mounted) return;
      triggerRebuild?.call(() {
        detailLoading = false;
        detailSale = result.saleDetail;
        detailPropina = result.parentPropina;
      });

    });
  }

  Future<_DetailData> _fetchDetailData(FinancialEvent event) async {
    Map<String, dynamic>? parentPropina;
    Map<String, dynamic>? saleDetail;

    try {
      final apiClient = ref.read(apiClientProvider);
      if (event.tipo == 'propina' && event.propinaId != null) {
        final tipRes =
            await apiClient.dio.get('/tips/${event.propinaId}');
        final raw = tipRes.data['data'] ?? tipRes.data;
        parentPropina = raw is Map<String, dynamic> ? raw : null;
        if (parentPropina?['venta_id'] != null) {
          saleDetail =
              await _fetchSaleDetailData(parentPropina!['venta_id'] as int);
        }
      } else if (event.codigoVenta != null) {
        saleDetail = await _fetchSaleDetailByCodeData(event.codigoVenta!);
      }
    } catch (_) {}

    return _DetailData(saleDetail: saleDetail, parentPropina: parentPropina);
  }

  Future<Map<String, dynamic>?> _fetchSaleDetailData(int ventaId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.dio.get('/ventas/$ventaId');
      return (res.data['data'] ?? res.data) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchSaleDetailByCodeData(
      String code) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.dio.get('/ventas?codigo=$code');
      final data = res.data['data'] ?? res.data;
      if (data is List && data.isNotEmpty) {
        return data[0] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  

  Widget _buildSkeleton(dynamic accentTheme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 6,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 76,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: CircularProgressIndicator(
            valueColor:
                AlwaysStoppedAnimation<Color>(accentTheme.color),
          ),
        ),
      ),
    );
  }

  

  Widget _buildError(String error, dynamic accentTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppTheme.errorColor, size: 48),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppTheme.errorColor),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () =>
                  ref.read(financialProvider(widget.type).notifier).fetchEvents(),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentTheme.color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  

  Widget _buildEmpty(dynamic accentTheme, Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded,
                color: textSecondary.withValues(alpha: 0.5), size: 64),
            const SizedBox(height: 16),
            Text(
              'Sin eventos',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No hay eventos financieros para mostrar',
              style: GoogleFonts.inter(fontSize: 13, color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return 'Sin fecha';
    try {
      final date = DateTime.parse(dateStr);
      return '${_dateFormat.format(date)} ${_timeFormat.format(date)}';
    } catch (_) {
      return dateStr;
    }
  }
}


class _DetailData {
  final Map<String, dynamic>? saleDetail;
  final Map<String, dynamic>? parentPropina;
  const _DetailData({this.saleDetail, this.parentPropina});
}





class _DetailSheet extends StatelessWidget {
  final FinancialEvent event;
  final bool loadingDetail;
  final Map<String, dynamic>? saleDetail;
  final Map<String, dynamic>? parentPropina;
  final NumberFormat currencyFormat;
  final DateFormat dateFormat;
  final VoidCallback onClose;

  const _DetailSheet({
    required this.event,
    required this.loadingDetail,
    this.saleDetail,
    this.parentPropina,
    required this.currencyFormat,
    required this.dateFormat,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkSurfaceColor : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Detalle del Evento',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Icon(Icons.close_rounded,
                      color: isDark ? Colors.grey : Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Divider(height: 1,
              color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200),
          
          Flexible(
            child: loadingDetail
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildField('Tipo', event.tipo),
                        _buildField(
                            'Monto', currencyFormat.format(event.monto)),
                        if (event.comision != null)
                          _buildField(
                              'Comisión', currencyFormat.format(event.comision)),
                        _buildField('Código', event.codigoVenta ?? event.codigo ?? '-'),
                        _buildField('Estado', event.estadoLabel),
                        _buildField('Fecha',
                            event.fechaCrea.isNotEmpty ? event.fechaCrea : '-'),
                        if (event.clienteNombre != null)
                          _buildField(
                              'Cliente', event.clienteNombre!),
                        if (event.habitacionNombre != null)
                          _buildField(
                              'Habitación', event.habitacionNombre!),
                        if (saleDetail != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Detalle de Venta',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (saleDetail!['productos'] != null)
                            ...List.generate(
                              (saleDetail!['productos'] as List?)?.length ?? 0,
                              (i) {
                                final p =
                                    (saleDetail!['productos'] as List)[i];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '${p['nombre'] ?? p['producto'] ?? ''} x${p['cantidad'] ?? 1}',
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: isDark
                                            ? AppTheme.darkTextSecondary
                                            : Colors.grey.shade600),
                                  ),
                                );
                              },
                            ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
