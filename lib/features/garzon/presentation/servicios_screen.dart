import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../auth/data/auth_notifier.dart';

// Helper models for form selection
class Room {
  final String id;
  final String name;
  final double basePrice;
  final double comisionAnfitriona;
  final int baseTime;

  Room({
    required this.id,
    required this.name,
    required this.basePrice,
    required this.comisionAnfitriona,
    required this.baseTime,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id']?.toString() ?? '',
      name: json['nombre'] ?? json['name'] ?? '',
      basePrice: double.tryParse(json['precio']?.toString() ?? '0') ?? 0.0,
      comisionAnfitriona: double.tryParse(json['comision_anfitriona']?.toString() ?? '0') ?? 0.0,
      baseTime: int.tryParse(json['tiempo']?.toString() ?? '30') ?? 30,
    );
  }
}

class Anfitriona {
  final String id;
  final String name;
  final String? photo;

  Anfitriona({required this.id, required this.name, this.photo});

  factory Anfitriona.fromJson(Map<String, dynamic> json) {
    return Anfitriona(
      id: json['id']?.toString() ?? '',
      name: json['nombre'] ?? json['name'] ?? '',
      photo: json['avatar'] ?? json['photo'],
    );
  }
}

class Client {
  final String id;
  final String name;
  final double saldo;

  Client({required this.id, required this.name, required this.saldo});

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id']?.toString() ?? json['id_cliente']?.toString() ?? '',
      name: json['nombre'] ?? json['name'] ?? '',
      saldo: double.tryParse(json['saldo']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class ServiciosScreen extends ConsumerStatefulWidget {
  const ServiciosScreen({super.key});

  @override
  ConsumerState<ServiciosScreen> createState() => _ServiciosScreenState();
}

class _ServiciosScreenState extends ConsumerState<ServiciosScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  // Data lists
  List<Room> _rooms = [];
  List<Anfitriona> _anfitrionas = [];
  List<Client> _clients = [];

  // Form states
  Room? _selectedRoom;
  final List<Anfitriona> _selectedHostesses = [];
  final List<Client> _selectedClients = [];
  final TextEditingController _priceController = TextEditingController(text: '0');
  String _paymentMethod = ''; // 'efectivo' | 'tarjeta' | 'transferencia' | 'prepago'

  @override
  void initState() {
    super.initState();
    _fetchFormData();
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  // Generate random 8 character code
  String _generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  // Fetch rooms, hostesses, and clients from API in parallel
  Future<void> _fetchFormData() async {
    final client = ref.read(apiClientProvider);
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final responses = await Future.wait([
        client.dio.get('/rooms'),
        client.dio.get('/users?anfitrionas=1'),
        client.dio.get('/clients'),
      ]);

      final roomsData = responses[0].data;
      final hostessesData = responses[1].data;
      final clientsData = responses[2].data;

      // Map rooms (filter active rooms with price & time > 0)
      final List<Room> loadedRooms = [];
      if (roomsData is List) {
        for (var item in roomsData) {
          final r = Room.fromJson(item);
          if (r.basePrice > 0 && r.baseTime > 0) {
            loadedRooms.add(r);
          }
        }
      }

      // Map hostesses
      final List<Anfitriona> loadedHostesses = [];
      if (hostessesData is List) {
        for (var item in hostessesData) {
          loadedHostesses.add(Anfitriona.fromJson(item));
        }
      }

      // Map clients
      final List<Client> loadedClients = [];
      if (clientsData is List) {
        for (var item in clientsData) {
          loadedClients.add(Client.fromJson(item));
        }
      }

      setState(() {
        _rooms = loadedRooms;
        _anfitrionas = loadedHostesses;
        _clients = loadedClients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error al cargar los datos del formulario: $e';
      });
    }
  }

  // Formatting currency helper
  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);
    return format.format(amount);
  }

  // Check if room has commission
  bool get _hasComision => _selectedRoom != null && _selectedRoom!.comisionAnfitriona > 0;

  // Max hostesses limit calculations based on room commission and selected clients
  int get _maxHostessesLimit {
    if (_selectedRoom == null) return 100;
    if (_hasComision) {
      // commission room: max 3 hostesses and max 4 people total in room
      final int clientCount = _selectedClients.length;
      return min(3, max(1, 4 - clientCount));
    }
    return 100; // No limit if no commission
  }

  int get _maxClientsLimit {
    if (_selectedRoom == null) return 100;
    if (_hasComision) {
      final int hostessCount = _selectedHostesses.length;
      return max(1, 4 - hostessCount);
    }
    return 100;
  }

  // Dynamic calculations for preview and submission
  Map<String, double> _calculateTotals() {
    if (_selectedRoom == null) {
      return {'subtotal': 0, 'roomPrice': 0, 'comision': 0, 'iva': 0, 'total': 0};
    }

    final double baseRoomPrice = _selectedRoom!.basePrice;
    final double comisionUnit = _selectedRoom!.comisionAnfitriona;
    final int hostessesCount = _selectedHostesses.length;
    final int clientsCount = _selectedClients.length;

    double subtotal = 0;
    double total = 0;
    double iva = 0;

    if (_hasComision) {
      // Room has commission: service price input is hidden.
      // Subtotal of service is: comision_anfitriona * hostess count
      subtotal = comisionUnit * hostessesCount;
      total = baseRoomPrice + subtotal;
    } else {
      // Room has NO commission: service price input is manual.
      final double servicePrice = double.tryParse(_priceController.text.replaceAll('.', '')) ?? 0.0;
      final int multiplier = max(hostessesCount, clientsCount);
      subtotal = servicePrice * max(1, multiplier);
      total = subtotal + baseRoomPrice;
    }

    // Card tax / VAT adjustments
    if (_paymentMethod == 'tarjeta') {
      iva = subtotal * 0.20;
      total += iva;

      if (!_hasComision) {
        // Round total up to nearest $5,000 CLP
        final double roundedTotal = (total / 5000).ceil() * 5000.0;
        final double diff = roundedTotal - total;
        iva += diff; // Excess is added to VAT
        total = roundedTotal;
      }
    }

    return {
      'subtotal': subtotal,
      'roomPrice': baseRoomPrice,
      'comision': comisionUnit * hostessesCount,
      'iva': iva,
      'total': total,
    };
  }

  // Handle Client selection changes (auto-force 'prepago' if client has balance > 0)
  void _onClientSelected(Client client, bool isSelected) {
    setState(() {
      if (isSelected) {
        // Respect dynamic limits
        if (_selectedClients.length >= _maxClientsLimit) {
          _selectedClients.removeAt(0); // Pop first to make space
        }
        _selectedClients.add(client);
      } else {
        _selectedClients.removeWhere((c) => c.id == client.id);
      }

      // Check if any selected client has balance > 0
      final hasBalance = _selectedClients.any((c) => c.saldo > 0);
      if (hasBalance) {
        _paymentMethod = 'prepago';
      } else {
        if (_paymentMethod == 'prepago') {
          _paymentMethod = '';
        }
      }
    });
  }

  void _onHostessSelected(Anfitriona hostess, bool isSelected) {
    setState(() {
      if (isSelected) {
        if (_selectedHostesses.length >= _maxHostessesLimit) {
          _selectedHostesses.removeAt(0); // Pop first
        }
        _selectedHostesses.add(hostess);
      } else {
        _selectedHostesses.removeWhere((h) => h.id == hostess.id);
      }
    });
  }

  // Submit the new Room Service to the box
  Future<void> _submitService() async {
    if (_selectedRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona una habitación.')),
      );
      return;
    }
    if (_selectedHostesses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, asocia al menos una anfitriona.')),
      );
      return;
    }
    if (_paymentMethod.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona un método de pago.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final client = ref.read(apiClientProvider);
    final totals = _calculateTotals();
    final servicePriceVal = double.tryParse(_priceController.text.replaceAll('.', '')) ?? 0.0;

    final payload = {
      'codigo': _generateRandomCode(),
      'cliente_id': _selectedClients.isNotEmpty ? _selectedClients.first.id : null,
      'clientes': _selectedClients.map((c) => c.id).toList(),
      'habitacion_id': _selectedRoom!.id,
      'precio_servicio': _hasComision ? 0 : servicePriceVal,
      'precio_habitacion': _selectedRoom!.basePrice,
      'comision_anfitriona': _selectedRoom!.comisionAnfitriona,
      'usuarios': _selectedHostesses.map((h) => h.id).toList(),
      'anfitrionas_ids': _selectedHostesses.map((h) => h.id).toList(),
      'metodo_pago': _paymentMethod,
      'tiempo': _selectedRoom!.baseTime,
      'total': totals['total'],
      'iva': totals['iva'],
      'num_clientes': _selectedClients.length,
    };

    try {
      await client.dio.post('/solicitudes-servicios', data: payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Servicio registrado exitosamente.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _error = 'Error al registrar servicio: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totals = _calculateTotals();
    final hasClientBalance = _selectedClients.any((c) => c.saldo > 0);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
        appBar: AppBar(title: const Text('Nuevo Servicio')),
        body: _buildSkeletonForm(),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
      appBar: AppBar(
        title: Text(
          'Nuevo Servicio',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Text(
                    _error!,
                    style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13),
                  ),
                ),

              // Room Selector Card
              _buildSectionTitle('Habitación'),
              const SizedBox(height: 8),
              _buildSelectorCard(
                label: _selectedRoom != null ? _selectedRoom!.name : 'Selecciona una habitación',
                value: _selectedRoom != null ? _formatCurrency(_selectedRoom!.basePrice) : null,
                icon: Icons.hotel_rounded,
                onTap: () => _showRoomPicker(),
              ),
              const SizedBox(height: 16),

              // Hostess Selector Card
              _buildSectionTitle('Anfitrionas (${_selectedHostesses.length})'),
              const SizedBox(height: 8),
              _buildSelectorCard(
                label: _selectedHostesses.isNotEmpty
                    ? _selectedHostesses.map((h) => h.name).join(', ')
                    : 'Selecciona las anfitrionas',
                value: _hasComision ? 'Tarifa Comisión' : null,
                icon: Icons.people_alt_rounded,
                onTap: () {
                  if (_selectedRoom == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Por favor, selecciona primero una habitación.')),
                    );
                    return;
                  }
                  _showHostessPicker();
                },
              ),
              const SizedBox(height: 16),

              // Client Selector Card
              _buildSectionTitle('Clientes (${_selectedClients.length})'),
              const SizedBox(height: 8),
              _buildSelectorCard(
                label: _selectedClients.isNotEmpty
                    ? _selectedClients.map((c) => c.name).join(', ')
                    : 'Asociar clientes (Opcional)',
                icon: Icons.person_add_rounded,
                onTap: () {
                  if (_selectedRoom == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Por favor, selecciona primero una habitación.')),
                    );
                    return;
                  }
                  _showClientPicker();
                },
              ),
              const SizedBox(height: 16),

              // Dynamic Commission Banner Alert
              if (_hasComision)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Habitación con comisión integrada. Se limita a máx. 3 chicas y el precio del servicio es fijo.',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.primaryColor),
                        ),
                      ),
                    ],
                  ),
                ),

              // Service Price Input (Hide if room has commission)
              if (!_hasComision && _selectedRoom != null) ...[
                _buildSectionTitle('Precio del Servicio'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      if (newValue.text.isEmpty) return newValue.copyWith(text: '0');
                      final value = int.tryParse(newValue.text) ?? 0;
                      final newText = NumberFormat.decimalPattern('es_CL').format(value);
                      return newValue.copyWith(
                        text: newText,
                        selection: TextSelection.collapsed(offset: newText.length),
                      );
                    }),
                  ],
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.monetization_on_rounded, color: AppTheme.primaryColor),
                    filled: true,
                    fillColor: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                    ),
                  ),
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                  onChanged: (_) => setState(() {}),
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
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wallet_giftcard_rounded, color: Colors.green, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'El cliente asociado posee saldo a favor. Se forzó el cobro a Billetera Prepago.',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
              _buildPaymentSelector(hasClientBalance),
              const SizedBox(height: 24),

              // Summary Card
              _buildSummaryCard(isDark, totals),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitService,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'CONFIRMAR Y REGISTRAR',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonForm() {
    return ShimmerWrapper(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ...List.generate(4, (i) => const Padding(
              padding: EdgeInsets.only(bottom: 24.0),
              child: SkeletonCard(lines: 2),
            )),
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

  Widget _buildSelectorCard({required String label, String? value, required IconData icon, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              Text(
                value,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSelector(bool forcePrepago) {
    final methods = [
      {'key': 'efectivo', 'label': 'Efectivo', 'icon': Icons.payments_rounded},
      {'key': 'tarjeta', 'label': 'Tarjeta (+20%)', 'icon': Icons.credit_card_rounded},
      {'key': 'transferencia', 'label': 'Transfer', 'icon': Icons.account_balance_rounded},
      {'key': 'prepago', 'label': 'Prepago (Saldo)', 'icon': Icons.wallet_rounded},
    ];

    return Row(
      children: methods.map((m) {
        final isSelected = _paymentMethod == m['key'];
        final isEnabled = !forcePrepago || m['key'] == 'prepago';

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: InkWell(
              onTap: isEnabled
                  ? () => setState(() => _paymentMethod = m['key'] as String)
                  : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withValues(alpha: 0.15)
                      : (isEnabled ? Colors.transparent : Colors.grey.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
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
                        color: isSelected ? AppTheme.primaryColor : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        m['label'] as String,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppTheme.primaryColor : null,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen del Servicio',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
          ),
          const Divider(height: 24),
          _buildSummaryRow(
            label: _hasComision ? 'Comisión Anfitriona x${_selectedHostesses.length}' : 'Subtotal Servicio',
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
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                _formatCurrency(totals['total']!),
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({required String label, required String value, bool isHighlight = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isHighlight
                ? AppTheme.primaryColor
                : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
            fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isHighlight ? AppTheme.primaryColor : null,
          ),
        ),
      ],
    );
  }

  // BottomSheet Picker for Rooms
  void _showRoomPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(16),
          color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Seleccionar Habitación', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
              const Divider(height: 20),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _rooms.length,
                  itemBuilder: (context, index) {
                    final r = _rooms[index];
                    return ListTile(
                      title: Text(r.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      subtitle: Text('Tiempo Base: ${r.baseTime} min • Comisión: ${_formatCurrency(r.comisionAnfitriona)}'),
                      trailing: Text(_formatCurrency(r.basePrice), style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                      onTap: () {
                        setState(() {
                          _selectedRoom = r;
                          _selectedHostesses.clear(); // Reset depending selections
                          _selectedClients.clear();
                          _paymentMethod = '';
                        });
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

  // BottomSheet Picker for Hostesses
  void _showHostessPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.6,
              color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Seleccionar Anfitrionas', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Límite: ${_selectedHostesses.length}/$_maxHostessesLimit', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.primaryColor)),
                    ],
                  ),
                  const Divider(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _anfitrionas.length,
                      itemBuilder: (context, index) {
                        final h = _anfitrionas[index];
                        final isChecked = _selectedHostesses.any((sh) => sh.id == h.id);

                        return CheckboxListTile(
                          title: Text(h.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          value: isChecked,
                          activeColor: AppTheme.primaryColor,
                          onChanged: (val) {
                            _onHostessSelected(h, val ?? false);
                            setModalState(() {}); // Refresh local modal state
                            setState(() {}); // Refresh parent state
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
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
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

  // BottomSheet Picker for Clients
  void _showClientPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.6,
              color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Vincular Clientes', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Límite: ${_selectedClients.length}/$_maxClientsLimit', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.primaryColor)),
                    ],
                  ),
                  const Divider(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _clients.length,
                      itemBuilder: (context, index) {
                        final c = _clients[index];
                        final isChecked = _selectedClients.any((sc) => sc.id == c.id);

                        return CheckboxListTile(
                          title: Text(c.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          subtitle: Text('Saldo virtual: ${_formatCurrency(c.saldo)}'),
                          value: isChecked,
                          activeColor: AppTheme.primaryColor,
                          onChanged: (val) {
                            _onClientSelected(c, val ?? false);
                            setModalState(() {});
                            setState(() {});
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
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
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
