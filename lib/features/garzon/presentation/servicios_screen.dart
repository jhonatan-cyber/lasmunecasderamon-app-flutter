import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/premium_header.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../data/servicios_notifier.dart';

class ServiciosScreen extends ConsumerStatefulWidget {
  const ServiciosScreen({super.key});

  @override
  ConsumerState<ServiciosScreen> createState() => _ServiciosScreenState();
}

class _ServiciosScreenState extends ConsumerState<ServiciosScreen> {
  final TextEditingController _priceController = TextEditingController(
    text: '0',
  );

  @override
  void initState() {
    super.initState();
    // Defer to avoid Riverpod rebuild during mount cycle (avoids !_dirty assertion)
    Future.microtask(() => ref.read(serviciosFormProvider.notifier).fetchFormData());
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  // Formatting currency helper
  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(
      locale: 'es_CL',
      symbol: '\$',
      decimalDigits: 0,
    );
    return format.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(serviciosFormProvider);
    final totals = state.totals;
    final hasClientBalance = state.selectedClients.any((c) => c.saldo > 0);

    if (state.isLoading) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
        body: Column(
          children: [
            PremiumHeader(
              title: 'Nuevo Servicio',
              showBackButton: true,
              onBack: () => context.pop(),
            ),
            Expanded(child: _buildSkeletonForm()),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
      body: Column(
        children: [
          PremiumHeader(
            title: 'Nuevo Servicio',
            showBackButton: true,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (state.error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: Text(
                          state.error!,
                          style: GoogleFonts.inter(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ),

                    // Room Selector Card
                    _buildSectionTitle('Habitación'),
                    const SizedBox(height: 8),
                    _buildSelectorCard(
                      label: state.selectedRoom != null
                          ? state.selectedRoom!.name
                          : 'Selecciona una habitación',
                      value: state.selectedRoom != null
                          ? _formatCurrency(state.selectedRoom!.basePrice)
                          : null,
                      icon: Icons.hotel_rounded,
                      onTap: () => _showRoomPicker(),
                    ),
                    const SizedBox(height: 16),

                    // Hostess Selector Card
                    _buildSectionTitle(
                      'Anfitrionas (${state.selectedHostesses.length})',
                    ),
                    const SizedBox(height: 8),
                    _buildSelectorCard(
                      label: state.selectedHostesses.isNotEmpty
                          ? state.selectedHostesses.map((h) => h.name).join(', ')
                          : 'Selecciona las anfitrionas',
                      value: state.hasComision ? 'Tarifa Comisión' : null,
                      icon: Icons.people_alt_rounded,
                      onTap: () {
                        if (state.selectedRoom == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Por favor, selecciona primero una habitación.',
                              ),
                            ),
                          );
                          return;
                        }
                        _showHostessPicker();
                      },
                    ),
                    const SizedBox(height: 16),

                    // Client Selector Card
                    _buildSectionTitle('Clientes (${state.selectedClients.length})'),
                    const SizedBox(height: 8),
                    _buildSelectorCard(
                      label: state.selectedClients.isNotEmpty
                          ? state.selectedClients.map((c) => c.name).join(', ')
                          : 'Asociar clientes (Opcional)',
                      icon: Icons.person_add_rounded,
                      onTap: () {
                        if (state.selectedRoom == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Por favor, selecciona primero una habitación.',
                              ),
                            ),
                          );
                          return;
                        }
                        _showClientPicker();
                      },
                    ),
                    const SizedBox(height: 16),

                    // Dynamic Commission Banner Alert
                    if (state.hasComision)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Habitación con comisión integrada. Se limita a máx. 3 chicas y el precio del servicio es fijo.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Service Price Input (Hide if room has commission)
                    if (!state.hasComision && state.selectedRoom != null) ...[
                      _buildSectionTitle('Precio del Servicio'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            if (newValue.text.isEmpty) {
                              return newValue.copyWith(text: '0');
                            }
                            final value = int.tryParse(newValue.text) ?? 0;
                            final newText = NumberFormat.decimalPattern(
                              'es_CL',
                            ).format(value);
                            return newValue.copyWith(
                              text: newText,
                              selection: TextSelection.collapsed(
                                offset: newText.length,
                              ),
                            );
                          }),
                        ],
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.monetization_on_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? AppTheme.darkSurfaceColor
                              : AppTheme.lightSurfaceColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? AppTheme.darkBorderColor
                                  : AppTheme.lightBorderColor,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        onChanged: (text) {
                          setState(() {});
                          final parsed = double.tryParse(text.replaceAll('.', '')) ?? 0.0;
                          ref.read(serviciosFormProvider.notifier).setManualPrice(parsed);
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Payment Method Section
                    _buildSectionTitle('Método de Pago'),
                    const SizedBox(height: 8),
                    if (hasClientBalance)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.wallet_giftcard_rounded,
                              color: Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'El cliente asociado posee saldo a favor. Se forzó el cobro a Billetera Prepago.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    _buildPaymentSelector(state),
                    const SizedBox(height: 24),

                    // Summary Card
                    _buildSummaryCard(isDark, totals),
                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: state.isSubmitting ? null : () => _submitService(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Theme.of(context).colorScheme.primary
                              .withValues(alpha: 0.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: state.isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'CONFIRMAR Y REGISTRAR',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submitService() async {
    final ok = await ref.read(serviciosFormProvider.notifier).submitService();
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Servicio registrado exitosamente.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    }
  }

  // ── Skeleton ──────────────────────────────────────────────────────────────

  Widget _buildSkeletonForm() {
    return ShimmerWrapper(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ...List.generate(
              4,
              (i) => const Padding(
                padding: EdgeInsets.only(bottom: 24.0),
                child: SkeletonCard(lines: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildSelectorCard({
    required String label,
    String? value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.darkSurfaceColor
              : AppTheme.lightSurfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? AppTheme.darkBorderColor
                : AppTheme.lightBorderColor,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSelector(ServiciosFormState state) {
    final methods = [
      {'key': 'efectivo', 'label': 'Efectivo', 'icon': Icons.payments_rounded},
      {
        'key': 'tarjeta',
        'label': 'Tarjeta (+20%)',
        'icon': Icons.credit_card_rounded,
      },
      {
        'key': 'transferencia',
        'label': 'Transfer',
        'icon': Icons.account_balance_rounded,
      },
      {
        'key': 'prepago',
        'label': 'Prepago (Saldo)',
        'icon': Icons.wallet_rounded,
      },
    ];
    final hasClientBalance = state.selectedClients.any((c) => c.saldo > 0);

    return Row(
      children: methods.map((m) {
        final isSelected = state.paymentMethod == m['key'];
        final isEnabled = !hasClientBalance || m['key'] == 'prepago';

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: InkWell(
              onTap: isEnabled
                  ? () => ref.read(serviciosFormProvider.notifier)
                      .setPaymentMethod(m['key'] as String)
                  : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                      : (isEnabled
                            ? Colors.transparent
                            : Colors.grey.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : (Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.darkBorderColor
                              : AppTheme.lightBorderColor),
                  ),
                ),
                child: Opacity(
                  opacity: isEnabled ? 1.0 : 0.3,
                  child: Column(
                    children: [
                      Icon(
                        m['icon'] as IconData,
                        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        m['label'] as String,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected ? Theme.of(context).colorScheme.primary : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSummaryCard(bool isDark, Map<String, double> totals) {
    final state = ref.watch(serviciosFormProvider);
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
            'Resumen del Servicio',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const Divider(height: 24),
          _buildSummaryRow(
            label: state.hasComision
                ? 'Comisión Anfitriona x${state.selectedHostesses.length}'
                : 'Subtotal Servicio',
            value: _formatCurrency(totals['subtotal']!),
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            label: 'Precio Habitación',
            value: _formatCurrency(totals['roomPrice']!),
          ),
          if (totals['iva']! > 0) ...[
            const SizedBox(height: 8),
            _buildSummaryRow(
              label: 'IVA / Comisión Tarjeta (20%)',
              value: _formatCurrency(totals['iva']!),
              isHighlight: true,
            ),
          ],
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL COBRO',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _formatCurrency(totals['total']!),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    bool isHighlight = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isHighlight
                ? Theme.of(context).colorScheme.primary
                : (isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary),
            fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isHighlight ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
      ],
    );
  }

  // ── BottomSheet Picker for Rooms ──────────────────────────────────────────

  void _showRoomPicker() {
    final state = ref.read(serviciosFormProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(16),
          color: isDark
              ? AppTheme.darkSurfaceColor
              : AppTheme.lightSurfaceColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seleccionar Habitación',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(height: 20),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: state.rooms.length,
                  itemBuilder: (context, index) {
                    final r = state.rooms[index];
                    return ListTile(
                      title: Text(
                        r.name,
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Tiempo Base: ${r.baseTime} min • Comisión: ${_formatCurrency(r.comisionAnfitriona)}',
                      ),
                      trailing: Text(
                        _formatCurrency(r.basePrice),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      onTap: () {
                        ref.read(serviciosFormProvider.notifier).selectRoom(r);
                        Navigator.pop(context);
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
  }

  // ── BottomSheet Picker for Hostesses ──────────────────────────────────────

  void _showHostessPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final sheetState = ref.read(serviciosFormProvider);
            return Container(
              padding: const EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.6,
              color: isDark
                  ? AppTheme.darkSurfaceColor
                  : AppTheme.lightSurfaceColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      Text(
                        'Límite: ${sheetState.selectedHostesses.length}/${sheetState.maxHostessesLimit}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: sheetState.anfitrionas.length,
                      itemBuilder: (context, index) {
                        final h = sheetState.anfitrionas[index];
                        final isChecked = sheetState.selectedHostesses.any(
                          (sh) => sh.id == h.id,
                        );

                        return CheckboxListTile(
                          title: Text(
                            h.name,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          value: isChecked,
                          activeColor: Theme.of(context).colorScheme.primary,
                          onChanged: (val) {
                            ref.read(serviciosFormProvider.notifier).toggleHostess(h);
                            setModalState(() {});
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('LISTO'),
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

  // ── BottomSheet Picker for Clients ────────────────────────────────────────

  void _showClientPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final sheetState = ref.read(serviciosFormProvider);
            return Container(
              padding: const EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.6,
              color: isDark
                  ? AppTheme.darkSurfaceColor
                  : AppTheme.lightSurfaceColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Vincular Clientes',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Límite: ${sheetState.selectedClients.length}/${sheetState.maxClientsLimit}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: sheetState.clients.length,
                      itemBuilder: (context, index) {
                        final c = sheetState.clients[index];
                        final isChecked = sheetState.selectedClients.any(
                          (sc) => sc.id == c.id,
                        );

                        return CheckboxListTile(
                          title: Text(
                            c.name,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Saldo virtual: ${_formatCurrency(c.saldo)}',
                          ),
                          value: isChecked,
                          activeColor: Theme.of(context).colorScheme.primary,
                          onChanged: (val) {
                            ref.read(serviciosFormProvider.notifier).toggleClient(c);
                            setModalState(() {});
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('VINCULAR'),
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
}
