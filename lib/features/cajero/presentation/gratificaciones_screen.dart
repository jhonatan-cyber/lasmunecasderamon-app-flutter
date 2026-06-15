import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../auth/data/auth_notifier.dart';

class GratificacionItem {
  final String id;
  final String usuario;
  final String usuarioId;
  final double monto;
  final String descripcion;
  final int estado;
  final String? estadoTexto;
  final DateTime fechaCrea;
  final DateTime? fechaMod;

  GratificacionItem({
    required this.id,
    required this.usuario,
    required this.usuarioId,
    required this.monto,
    required this.descripcion,
    required this.estado,
    this.estadoTexto,
    required this.fechaCrea,
    this.fechaMod,
  });

  factory GratificacionItem.fromJson(Map<String, dynamic> json) {
    return GratificacionItem(
      id: (json['id'] ?? '').toString(),
      usuario: json['usuario'] ?? '',
      usuarioId: (json['id_usuario'] ?? json['usuario_id'] ?? '').toString(),
      monto: double.tryParse(json['monto']?.toString() ?? '0') ?? 0.0,
      descripcion: json['descripcion'] ?? '',
      estado: int.tryParse(json['estado']?.toString() ?? '0') ?? 0,
      estadoTexto: json['estado_texto'],
      fechaCrea: DateTime.tryParse(json['fecha_crea'] ?? json['fecha_hora'] ?? '') ?? DateTime.now(),
      fechaMod: json['fecha_mod'] != null ? DateTime.tryParse(json['fecha_mod']) : null,
    );
  }
}

class GratificacionEmployee {
  final String id;
  final String name;
  final String lastName;
  final String nick;
  final String role;
  final int status;

  GratificacionEmployee({
    required this.id,
    required this.name,
    required this.lastName,
    required this.nick,
    required this.role,
    required this.status,
  });

  factory GratificacionEmployee.fromJson(Map<String, dynamic> json) {
    String roleName = '';
    final roleValue = json['role'] ?? json['rol'];
    if (roleValue is String) {
      roleName = roleValue;
    } else if (roleValue is Map && roleValue['name'] is String) {
      roleName = roleValue['name'] as String;
    }
    
    return GratificacionEmployee(
      id: (json['id'] ?? json['id_usuario'] ?? '').toString(),
      name: json['name'] ?? json['nombre'] ?? '',
      lastName: json['lastName'] ?? json['apellido'] ?? '',
      nick: json['nick'] ?? '',
      role: roleName,
      status: int.tryParse((json['status'] ?? json['estado'] ?? '1').toString()) ?? 1,
    );
  }
}

class CajeroGratificacionesScreen extends ConsumerStatefulWidget {
  const CajeroGratificacionesScreen({super.key});

  @override
  ConsumerState<CajeroGratificacionesScreen> createState() => _CajeroGratificacionesScreenState();
}

class _CajeroGratificacionesScreenState extends ConsumerState<CajeroGratificacionesScreen> {
  bool _loading = true;
  bool _submitting = false;
  List<GratificacionItem> _gratificaciones = [];
  List<GratificacionEmployee> _employees = [];
  String _error = '';
  String _filter = 'todos'; // todos, pendiente, por_pagar, pagado, rechazada

  // Form states for dialog
  String _employeeSearch = '';
  GratificacionEmployee? _selectedEmployee;
  final TextEditingController _montoController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _montoController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _fetchData({bool isManual = false}) async {
    if (!isManual) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }
    try {
      final client = ref.read(apiClientProvider);
      
      final responses = await Future.wait([
        client.dio.get('/gratificaciones'),
        client.dio.get('/users?status=active'),
      ]);

      final gratsResponse = responses[0];
      final usersResponse = responses[1];

      List<GratificacionItem> gratsList = [];
      if (gratsResponse.data != null) {
        final List<dynamic> list = gratsResponse.data is List ? gratsResponse.data : gratsResponse.data['data'] ?? [];
        gratsList = list.map((json) => GratificacionItem.fromJson(json)).toList();
      }

      List<GratificacionEmployee> empsList = [];
      if (usersResponse.data != null && usersResponse.data['success'] == true) {
        final List<dynamic> list = usersResponse.data['data'] ?? [];
        empsList = list
            .map((json) => GratificacionEmployee.fromJson(json))
            .where((u) {
              final r = u.role.toLowerCase();
              return !r.contains('admin') && !r.contains('administrador');
            })
            .toList();
      }

      setState(() {
        _gratificaciones = gratsList;
        _employees = empsList;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);
    return format.format(amount);
  }

  List<GratificacionItem> get _filteredData {
    if (_filter == 'todos') return _gratificaciones;
    return _gratificaciones.where((item) {
      if (_filter == 'pendiente') return item.estado == 2;
      if (_filter == 'por_pagar') return item.estado == 1;
      if (_filter == 'pagado') return item.estado == 0;
      if (_filter == 'rechazada') return item.estado == 3;
      return true;
    }).toList();
  }

  Map<String, double> get _totals {
    double pendiente = 0;
    double porPagar = 0;
    double pagado = 0;
    for (var item in _gratificaciones) {
      if (item.estado == 2) pendiente += item.monto;
      if (item.estado == 1) porPagar += item.monto;
      if (item.estado == 0) pagado += item.monto;
    }
    return {
      'pendiente': pendiente,
      'porPagar': porPagar,
      'pagado': pagado,
    };
  }

  Map<int, Map<String, dynamic>> get _estadoConfig {
    return {
      0: {'label': 'Pagado', 'color': Colors.green, 'bg': Colors.green.withValues(alpha: 0.15)},
      1: {'label': 'Por pagar', 'color': Colors.blue, 'bg': Colors.blue.withValues(alpha: 0.15)},
      2: {'label': 'Pendiente', 'color': Colors.orange, 'bg': Colors.orange.withValues(alpha: 0.15)},
      3: {'label': 'Rechazada', 'color': Colors.red, 'bg': Colors.red.withValues(alpha: 0.15)},
    };
  }

  void _resetForm() {
    setState(() {
      _selectedEmployee = null;
      _employeeSearch = '';
      _montoController.clear();
      _descController.clear();
    });
  }

  Future<void> _handleSubmit() async {
    final cleanMonto = _montoController.text.replaceAll(RegExp(r'\D'), '');
    final amount = double.tryParse(cleanMonto) ?? 0.0;
    if (_selectedEmployee == null || amount <= 0) return;

    setState(() => _submitting = true);
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.post(
        '/gratificaciones',
        data: {
          'usuario_id': _selectedEmployee!.id,
          'monto': amount,
          'descripcion': _descController.text.trim(),
        },
      );

      if (response.data != null && response.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response.data['pendingApproval'] == true
                    ? 'Se envió al administrador por WhatsApp para aprobación'
                    : 'Gratificación registrada correctamente',
              ),
            ),
          );
          Navigator.pop(context);
        }
        _resetForm();
        _fetchData();
      } else {
        throw Exception(response.data?['message'] ?? 'No se pudo crear la gratificación');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showNewGratificacionModal() {
    _resetForm();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkBgColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredEmps = _employees.where((employee) {
              final term = _employeeSearch.trim().toLowerCase();
              if (term.isEmpty) return true;
              return '${employee.name} ${employee.lastName} ${employee.nick}'
                  .toLowerCase()
                  .contains(term);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.6,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[600],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Nueva Gratificación',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.grey[850],
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 20),
                              ),
                            )
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white10),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
                          children: [
                            // Search Employee Input
                            TextField(
                              style: GoogleFonts.inter(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Buscar empleado...',
                                prefixIcon: Icon(Icons.search, color: AppTheme.darkTextSecondary),
                              ),
                              onChanged: (val) {
                                setModalState(() {
                                  _employeeSearch = val;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            // Employees List Selector
                            Container(
                              height: 180,
                              decoration: BoxDecoration(
                                color: AppTheme.darkSurfaceColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: ListView.builder(
                                  itemCount: filteredEmps.length,
                                  itemBuilder: (context, idx) {
                                    final employee = filteredEmps[idx];
                                    final isSelected = _selectedEmployee?.id == employee.id;

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primaryColor.withValues(alpha: 0.15)
                                            : Colors.transparent,
                                      ),
                                      child: ListTile(
                                        onTap: () {
                                          setModalState(() {
                                            _selectedEmployee = employee;
                                          });
                                        },
                                        title: Text(
                                          '${employee.name} ${employee.lastName}',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '@${employee.nick.isNotEmpty ? employee.nick : 'sin-nick'} · ${employee.role}',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: AppTheme.darkTextSecondary,
                                          ),
                                        ),
                                        trailing: isSelected
                                            ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor)
                                            : null,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Monto Input
                            TextField(
                              controller: _montoController,
                              style: GoogleFonts.inter(color: Colors.white),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'Monto',
                                prefixIcon: Icon(Icons.payments_rounded, color: AppTheme.darkTextSecondary),
                              ),
                              onChanged: (val) {
                                setModalState(() {});
                              },
                            ),
                            const SizedBox(height: 16),
                            // Descripion Input
                            TextField(
                              controller: _descController,
                              style: GoogleFonts.inter(color: Colors.white),
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: 'Descripción (opcional)',
                                prefixIcon: Icon(Icons.description_rounded, color: AppTheme.darkTextSecondary),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Submit Button
                            ElevatedButton(
                              style: AppTheme.getPrimaryButtonStyle(context).copyWith(
                                padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 16)),
                              ),
                              onPressed: _submitting || _selectedEmployee == null || _montoController.text.isEmpty
                                  ? null
                                  : () async {
                                      setModalState(() => _submitting = true);
                                      await _handleSubmit();
                                      setModalState(() => _submitting = false);
                                    },
                              child: _submitting
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : Text(
                                      'Enviar solicitud por WhatsApp',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                                    ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalsData = _totals;

    return Scaffold(
      backgroundColor: AppTheme.darkBgColor,
      body: _loading
          ? _buildSkeletonGrid()
          : RefreshIndicator(
              onRefresh: () => _fetchData(isManual: true),
              color: AppTheme.primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: AppTheme.darkSurfaceColor,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(32),
                          bottomRight: Radius.circular(32),
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                              Column(
                                children: [
                                  Text(
                                    'Gratificaciones',
                                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  Text(
                                    'Solicitudes y seguimiento',
                                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.darkTextSecondary),
                                  )
                                ],
                              ),
                              const SizedBox(width: 40),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Summary Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurfaceColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'TOTAL PENDIENTE DE APROBACIÓN',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkTextSecondary,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatCurrency(totalsData['pendiente']!),
                              style: GoogleFonts.inter(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: Colors.orange,
                              ),
                            ),
                            const Divider(color: Colors.white10, height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Text(
                                  'Por pagar: ${_formatCurrency(totalsData['porPagar']!)}',
                                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.darkTextSecondary, fontWeight: FontWeight.bold),
                                ),
                                Container(width: 1, height: 12, color: Colors.white10),
                                Text(
                                  'Pagado: ${_formatCurrency(totalsData['pagado']!)}',
                                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.darkTextSecondary, fontWeight: FontWeight.bold),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Filter row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('Todos', 'todos'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Pendiente', 'pendiente'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Por pagar', 'por_pagar'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Pagado', 'pagado'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Rechazada', 'rechazada'),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Main list
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _error.isNotEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40.0),
                                child: Text('Error: $_error', style: GoogleFonts.inter(color: Colors.red)),
                              ),
                            )
                          : _filteredData.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 60.0),
                                    child: Column(
                                      children: [
                                        Icon(Icons.card_giftcard_rounded, size: 48, color: AppTheme.darkTextSecondary),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No hay gratificaciones para este filtro',
                                          style: GoogleFonts.inter(color: AppTheme.darkTextSecondary, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _filteredData.length,
                                  itemBuilder: (context, index) {
                                    final item = _filteredData[index];
                                    final config = _estadoConfig[item.estado] ?? _estadoConfig[2]!;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppTheme.darkSurfaceColor,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.05),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    (index + 1).toString(),
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: config['bg'] as Color,
                                                  borderRadius: BorderRadius.circular(9999),
                                                ),
                                                child: Text(
                                                  config['label'] as String,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 10,
                                                    color: config['color'] as Color,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              )
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            item.usuario,
                                            style: GoogleFonts.inter(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatCurrency(item.monto),
                                            style: GoogleFonts.inter(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w900,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item.descripcion.isNotEmpty ? item.descripcion : 'Sin descripción',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: AppTheme.darkTextSecondary,
                                            ),
                                          ),
                                          const Divider(color: Colors.white10, height: 20),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                DateFormat('dd/MM/yyyy').format(item.fechaCrea),
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  color: AppTheme.darkTextSecondary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                item.estadoTexto?.replaceAll('_', ' ').toUpperCase() ??
                                                    (config['label'] as String).toUpperCase(),
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  color: AppTheme.darkTextSecondary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              )
                                            ],
                                          )
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
      floatingActionButton: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
          elevation: 8,
          shadowColor: Colors.black45,
        ),
        onPressed: _showNewGratificacionModal,
        icon: const Icon(Icons.add, size: 20),
        label: Text('Nueva gratificación', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _buildFilterChip(String text, String value) {
    final isSelected = _filter == value;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? AppTheme.primaryColor : AppTheme.darkSurfaceColor,
        foregroundColor: isSelected ? Colors.white : AppTheme.darkTextSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9999),
          side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.white10),
        ),
      ),
      onPressed: () => setState(() => _filter = value),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const SizedBox(height: 100),
          const SkeletonCard(lines: 3),
          const SizedBox(height: 16),
          ...List.generate(4, (i) => const SkeletonCard(lines: 4)),
        ],
      ),
    );
  }
}
