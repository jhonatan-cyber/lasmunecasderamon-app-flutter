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

class NuevaVentaScreen extends ConsumerStatefulWidget {
  const NuevaVentaScreen({super.key});

  @override
  ConsumerState<NuevaVentaScreen> createState() => _NuevaVentaScreenState();
}

class _NuevaVentaScreenState extends ConsumerState<NuevaVentaScreen> {

  
  List<dynamic> _anfitrionas = [];
  List<dynamic> _rooms = [];
  List<dynamic> _clients = [];
  List<dynamic> _categories = [];
  List<dynamic> _products = [];

  
  dynamic _selectedAnfitriona;
  dynamic _selectedRoom;
  dynamic _selectedClient;
  dynamic _selectedCategory;

  
  final Map<int, int> _cart = {}; 
  String _paymentMethod =
      'efectivo'; 

  @override
  void initState() {
    super.initState();
    _fetchAssets();
  }

  Future<void> _fetchAssets() async {
    ref.read(refreshProvider('nueva_venta').notifier).startRefresh(isManual: false);

    try {
      final client = ref.read(apiClientProvider);

      
      final responses = await Future.wait([
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
        client.dio
            .get('/categories')
            .catchError(
              (_) => Response(
                requestOptions: RequestOptions(),
                data: {'success': false},
              ),
            ),
      ]);

      final anfitrionasRes = responses[0];
      final roomsRes = responses[1];
      final clientsRes = responses[2];
      final categoriesRes = responses[3];

      List<dynamic> anfitrionasData = [];
      if (anfitrionasRes.data != null &&
          anfitrionasRes.data['success'] == true) {
        anfitrionasData = anfitrionasRes.data['data'] ?? [];
      }

      List<dynamic> roomsData = [];
      if (roomsRes.data != null && roomsRes.data['success'] == true) {
        roomsData = roomsRes.data['data'] ?? [];
      }

      List<dynamic> clientsData = [];
      if (clientsRes.data != null && clientsRes.data['success'] == true) {
        clientsData = clientsRes.data['data'] ?? [];
      }

      List<dynamic> categoriesData = [];
      if (categoriesRes.data != null && categoriesRes.data['success'] == true) {
        categoriesData = categoriesRes.data['data'] ?? [];
      }

      if (!mounted) return;
      setState(() {
        _anfitrionas = anfitrionasData;
        _rooms = roomsData;
        _clients = clientsData;
        _categories = categoriesData;
      });
      ref.read(refreshProvider('nueva_venta').notifier).endRefresh();

      if (_categories.isNotEmpty) {
        _onCategorySelected(_categories.first);
      }
    } catch (e) {
      if (!mounted) return;
      ref.read(refreshProvider('nueva_venta').notifier).endRefresh(error: 'Error al cargar recursos de venta');
    }
  }

  Future<void> _onCategorySelected(dynamic category) async {
    setState(() {
      _selectedCategory = category;
      _products = [];
    });

    final int catId =
        int.tryParse(category['id_categoria']?.toString() ?? '') ??
        int.tryParse(category['id']?.toString() ?? '') ??
        0;

    if (catId == 0) return;

    try {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.get('/products?category_id=$catId');

      if (response.data != null && response.data['success'] == true) {
        if (!mounted) return;
        setState(() {
          _products = response.data['data'] ?? [];
        });
      }
    } catch (_) {
      
    }
  }

  void _addToCart(int productId) {
    setState(() {
      _cart[productId] = (_cart[productId] ?? 0) + 1;
    });
  }

  void _removeFromCart(int productId) {
    if (!_cart.containsKey(productId)) return;
    setState(() {
      if (_cart[productId] == 1) {
        _cart.remove(productId);
      } else {
        _cart[productId] = _cart[productId]! - 1;
      }
    });
  }

  double _calculateTotal() {
    double total = 0;
    _cart.forEach((prodId, qty) {
      final product = _findProductById(prodId);
      if (product != null) {
        final double price =
            double.tryParse(product['precio']?.toString() ?? '0') ?? 0.0;
        total += price * qty;
      }
    });
    return total;
  }

  dynamic _findProductById(int id) {
    try {
      return _products.firstWhere(
        (p) =>
            (int.tryParse(p['id_producto']?.toString() ?? '') ??
                int.tryParse(p['id']?.toString() ?? '') ??
                0) ==
            id,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _submitVenta() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos un producto al carrito'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final double total = _calculateTotal();
    final client = ref.read(apiClientProvider);
    final notifier = ref.read(setStateProvider('nueva_venta').notifier);

    notifier.startSubmit();

    try {
      
      if (_paymentMethod == 'prepago') {
        if (_selectedClient == null) {
          notifier.endSubmit();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debe seleccionar un cliente para pago prepago'),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }

        final int clienteId =
            int.tryParse(_selectedClient['id_cliente']?.toString() ?? '') ??
            int.tryParse(_selectedClient['id']?.toString() ?? '') ??
            0;

        final prepagoRes = await client.dio.post(
          '/clients/prepago',
          data: {'cliente_id': clienteId, 'monto': total},
        );

        if (prepagoRes.data == null || prepagoRes.data['success'] != true) {
          final msg =
              prepagoRes.data?['message'] ?? 'Saldo prepago insuficiente';
          if (!mounted) return;
          notifier.endSubmit();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $msg'),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }
      }

      
      final List<Map<String, dynamic>> itemsPayload = [];
      _cart.forEach((prodId, qty) {
        final product = _findProductById(prodId);
        if (product != null) {
          final double price =
              double.tryParse(product['precio']?.toString() ?? '0') ?? 0.0;
          itemsPayload.add({
            'producto_id': prodId,
            'cantidad': qty,
            'precio': price,
          });
        }
      });

      final int? clienteId = _selectedClient != null
          ? (int.tryParse(_selectedClient['id_cliente']?.toString() ?? '') ??
                int.tryParse(_selectedClient['id']?.toString() ?? ''))
          : null;

      final int? anfitrionaId = _selectedAnfitriona != null
          ? (int.tryParse(
                  _selectedAnfitriona['id_anfitriona']?.toString() ?? '',
                ) ??
                int.tryParse(_selectedAnfitriona['id']?.toString() ?? ''))
          : null;

      final int? roomId = _selectedRoom != null
          ? (int.tryParse(_selectedRoom['id_room']?.toString() ?? '') ??
                int.tryParse(_selectedRoom['id']?.toString() ?? ''))
          : null;

      final response = await client.dio.post(
        '/sales',
        data: {
          'cliente_id': clienteId,
          'anfitriona_id': anfitrionaId,
          'room_id': roomId,
          'metodo_pago': _paymentMethod,
          'items': itemsPayload,
        },
      );

      if (response.data != null && response.data['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Venta completada con éxito'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      } else {
        final msg = response.data?['message'] ?? 'Error al procesar la venta';
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
          content: Text('Error de conexión al guardar la venta'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) notifier.endSubmit();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final refreshState = ref.watch(refreshProvider('nueva_venta'));

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
      body: Column(
        children: [
          PremiumHeader(
            title: 'Nueva Venta Directa',
            showBackButton: true,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: FadeLoadingSwitcher(
              isLoading: refreshState.isLoading,
              skeleton: _buildSkeletonGrid(),
              content: LayoutBuilder(
                builder: (context, constraints) {
                  
                  final isWide = constraints.maxWidth > 800;

                  final mainContent = Column(
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
                      
                      _buildAssetsPickers(isDark),
                      const SizedBox(height: 16),

                      
                      Text(
                        'Catálogo de Productos',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildCategoriesBar(isDark),
                      const SizedBox(height: 12),

                      
                      Expanded(child: _buildProductsGrid(isDark)),
                    ],
                  );

                  final sidePanel = _buildCartSidePanel(isDark);

                  if (isWide) {
                    return Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: mainContent,
                          ),
                        ),
                        VerticalDivider(
                          width: 1,
                          color: isDark
                              ? AppTheme.darkBorderColor
                              : AppTheme.lightBorderColor,
                        ),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: sidePanel,
                          ),
                        ),
                      ],
                    );
                  }

                  
                  return Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: mainContent,
                        ),
                      ),
                      _buildCartBottomBar(isDark),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return ShimmerWrapper(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SkeletonCard(lines: 2),
            const SizedBox(height: 16),
            SkeletonCard(lines: 1),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.3,
              ),
              itemCount: 6,
              itemBuilder: (context, i) => const SkeletonCard(lines: 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetsPickers(bool isDark) {
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
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<dynamic>(
                  initialValue: _selectedClient,
                  hint: Text(
                    'Cliente (Opcional)',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                  items: [
                    const DropdownMenuItem<dynamic>(
                      value: null,
                      child: Text(
                        'Cliente General',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    ..._clients.map((c) {
                      return DropdownMenuItem<dynamic>(
                        value: c,
                        child: Text(
                          c['nombre'] ?? 'Cliente',
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedClient = val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<dynamic>(
                  initialValue: _selectedRoom,
                  hint: Text(
                    'Habitación (Opcional)',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                  items: [
                    const DropdownMenuItem<dynamic>(
                      value: null,
                      child: Text('Ninguna', style: TextStyle(fontSize: 13)),
                    ),
                    ..._rooms.map((r) {
                      return DropdownMenuItem<dynamic>(
                        value: r,
                        child: Text(
                          r['name'] ?? r['numero']?.toString() ?? 'Habitación',
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedRoom = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<dynamic>(
            initialValue: _selectedAnfitriona,
            hint: Text(
              'Asociar a Anfitriona (Opcional)',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            items: [
              const DropdownMenuItem<dynamic>(
                value: null,
                child: Text(
                  'Ninguna Anfitriona',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              ..._anfitrionas.map((a) {
                return DropdownMenuItem<dynamic>(
                  value: a,
                  child: Text(
                    a['nombre'] ?? 'Anfitriona',
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }),
            ],
            onChanged: (val) {
              setState(() => _selectedAnfitriona = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesBar(bool isDark) {
    if (_categories.isEmpty) return const SizedBox();
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                cat['nombre'] ?? 'Categoría',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) _onCategorySelected(cat);
              },
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductsGrid(bool isDark) {
    if (_products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'No hay productos en esta categoría',
            style: GoogleFonts.inter(
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.3,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        final int id =
            int.tryParse(product['id_producto']?.toString() ?? '') ??
            int.tryParse(product['id']?.toString() ?? '') ??
            0;
        final double price =
            double.tryParse(product['precio']?.toString() ?? '0') ?? 0.0;
        final int cartQty = _cart[id] ?? 0;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.darkSurfaceColor
                : AppTheme.lightSurfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cartQty > 0
                  ? Theme.of(context).colorScheme.primary
                  : (isDark
                        ? AppTheme.darkBorderColor
                        : AppTheme.lightBorderColor),
              width: cartQty > 0 ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['nombre'] ?? 'Producto',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatCurrency(price),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (cartQty > 0) ...[
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        size: 22,
                        color: Colors.redAccent,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _removeFromCart(id),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Text(
                        '$cartQty',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  IconButton(
                    icon: Icon(
                      Icons.add_circle,
                      size: 24,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _addToCart(id),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCartSidePanel(bool isDark) {
    final double total = _calculateTotal();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Carrito de Compras',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildCartItemsList(isDark)),
        const Divider(height: 24, thickness: 1),
        _buildPaymentMethodSelector(isDark),
        const SizedBox(height: 16),
        _buildCheckoutSummaryRow(
          'Total a Pagar',
          _formatCurrency(total),
          isTotal: true,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: AppTheme.getPrimaryButtonStyle(context),
            onPressed: ref.watch(setStateProvider('nueva_venta')).isSubmitting ? null : _submitVenta,
            child: ref.watch(setStateProvider('nueva_venta')).isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Registrar Venta',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCartItemsList(bool isDark) {
    if (_cart.isEmpty) {
      return Center(
        child: Text(
          'El carrito está vacío',
          style: GoogleFonts.inter(
            color: isDark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
          ),
        ),
      );
    }

    final cartList = _cart.entries.toList();

    return ListView.builder(
      itemCount: cartList.length,
      itemBuilder: (context, index) {
        final entry = cartList[index];
        final product = _findProductById(entry.key);
        if (product == null) return const SizedBox();

        final double price =
            double.tryParse(product['precio']?.toString() ?? '0') ?? 0.0;
        final int qty = entry.value;

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
                      product['nombre'] ?? 'Producto',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$qty x ${_formatCurrency(price)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(
                    _formatCurrency(price * qty),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                    onPressed: () {
                      setState(() {
                        _cart.remove(entry.key);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentMethodSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Método de Pago',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _paymentMethod,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: const [
            DropdownMenuItem(
              value: 'efectivo',
              child: Text('Efectivo', style: TextStyle(fontSize: 13)),
            ),
            DropdownMenuItem(
              value: 'tarjeta',
              child: Text('Tarjeta', style: TextStyle(fontSize: 13)),
            ),
            DropdownMenuItem(
              value: 'transferencia',
              child: Text('Transferencia', style: TextStyle(fontSize: 13)),
            ),
            DropdownMenuItem(
              value: 'prepago',
              child: Text('Prepago (Cliente)', style: TextStyle(fontSize: 13)),
            ),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _paymentMethod = val);
            }
          },
        ),
      ],
    );
  }

  Widget _buildCheckoutSummaryRow(
    String label,
    String value, {
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: isTotal ? 18 : 14,
            fontWeight: FontWeight.bold,
            color: isTotal ? Colors.green : null,
          ),
        ),
      ],
    );
  }

  Widget _buildCartBottomBar(bool isDark) {
    final double total = _calculateTotal();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppTheme.darkBorderColor
                : AppTheme.lightBorderColor,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TOTAL ESTIMADO',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
                Text(
                  _formatCurrency(total),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            ElevatedButton(
              style: AppTheme.getPrimaryButtonStyle(context).copyWith(
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              onPressed: () {
                _showCartModalSheet(isDark);
              },
              child: Text(
                'Revisar Carrito (${_cart.values.fold(0, (a, b) => a + b)})',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCartModalSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkSurfaceColor
                  : AppTheme.lightSurfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(
                color: isDark
                    ? AppTheme.darkBorderColor
                    : AppTheme.lightBorderColor,
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Revisar Venta',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.3,
                  ),
                  child: _buildCartItemsList(isDark),
                ),
                const Divider(height: 24, thickness: 1),
                _buildPaymentMethodSelector(isDark),
                const SizedBox(height: 20),
                _buildCheckoutSummaryRow(
                  'Total',
                  _formatCurrency(_calculateTotal()),
                  isTotal: true,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: AppTheme.getPrimaryButtonStyle(context),
                    onPressed: ref.watch(setStateProvider('nueva_venta')).isSubmitting
                        ? null
                        : () async {
                            final navigator = Navigator.of(context);
                            await _submitVenta();
                            if (mounted && !ref.read(setStateProvider('nueva_venta')).isSubmitting) {
                              navigator.pop();
                            }
                          },
                    child: ref.watch(setStateProvider('nueva_venta')).isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Completar Venta',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
