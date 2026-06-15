import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lasmunecasderamon_flutter/core/theme.dart';
import 'package:dio/dio.dart';
import 'package:lasmunecasderamon_flutter/features/auth/data/auth_notifier.dart';
import '../data/cart_notifier.dart';
import '../domain/category.dart';
import '../domain/product.dart';

// Helper models for local dropdowns/modales
class LocalHostess {
  final String id;
  final String nick;
  final String name;

  LocalHostess({required this.id, required this.nick, required this.name});

  factory LocalHostess.fromMap(Map<String, dynamic> map) {
    return LocalHostess(
      id: map['id']?.toString() ?? '',
      nick: map['nick'] ?? map['name'] ?? 'Anfitriona',
      name: map['name'] ?? '',
    );
  }
}

class LocalRoom {
  final String id;
  final String name;

  LocalRoom({required this.id, required this.name});

  factory LocalRoom.fromMap(Map<String, dynamic> map) {
    return LocalRoom(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? 'Habitación',
    );
  }
}

class LocalClient {
  final String id;
  final String name;
  final String lastName;

  LocalClient({required this.id, required this.name, required this.lastName});

  factory LocalClient.fromMap(Map<String, dynamic> map) {
    return LocalClient(
      id: map['id']?.toString() ?? map['id_cliente']?.toString() ?? '',
      name: map['name'] ?? map['nombre'] ?? '',
      lastName: map['lastName'] ?? map['apellido'] ?? '',
    );
  }

  String get fullName => '$name $lastName'.trim();
}

class ProductosScreen extends ConsumerStatefulWidget {
  const ProductosScreen({super.key});

  @override
  ConsumerState<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends ConsumerState<ProductosScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Catalogs
  List<Category> _categories = [];
  List<Product> _products = [];
  List<LocalHostess> _anfitrionas = [];
  List<LocalRoom> _rooms = [];
  List<LocalClient> _clients = [];

  bool _isLoading = true;
  String? _error;
  bool _submitting = false;
  Category? _selectedCategory;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchInitialData());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      
      // Fetch categories, hostess, rooms and clients concurrently
      final responses = await Future.wait<Response<dynamic>>([
        client.dio.get('/categories'),
        client.dio.get('/anfitrionas'),
        client.dio.get('/rooms?status=1'),
        client.dio.get('/clients'),
      ]);

      final catRes = responses[0];
      final anfRes = responses[1];
      final roomRes = responses[2];
      final clientRes = responses[3];

      List<Category> categories = [];
      if (catRes.data?['success'] == true && catRes.data?['data'] is List) {
        categories = (catRes.data['data'] as List).map((x) => Category.fromJson(x)).toList();
      }

      List<LocalHostess> anfitrionas = [];
      final anfData = anfRes.data;
      if (anfData != null) {
        final rawList = anfData['data'] ?? (anfData is List ? anfData : null);
        if (rawList is List) {
          anfitrionas = rawList.map((x) => LocalHostess.fromMap(Map<String, dynamic>.from(x))).toList();
        }
      }

      List<LocalRoom> rooms = [];
      if (roomRes.data?['success'] == true && roomRes.data?['data'] is List) {
        rooms = (roomRes.data['data'] as List).map((x) => LocalRoom.fromMap(Map<String, dynamic>.from(x))).toList();
      }

      List<LocalClient> clients = [];
      final cData = clientRes.data;
      if (cData != null) {
        final rawList = cData['data'] ?? (cData is List ? cData : null);
        if (rawList is List) {
          clients = rawList.map((x) => LocalClient.fromMap(Map<String, dynamic>.from(x))).toList();
        }
      }

      setState(() {
        _categories = categories;
        _anfitrionas = anfitrionas;
        _rooms = rooms;
        _clients = clients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error de conexión al cargar datos de catálogo';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchProducts(String categoryId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final res = await client.dio.get('/products?category_id=$categoryId');
      
      if (res.data?['success'] == true && res.data?['data'] is List) {
        final allProducts = (res.data['data'] as List).map((x) => Product.fromJson(x)).toList();
        // Filtrar activos (status = 1)
        setState(() {
          _products = allProducts.where((p) => p.status == 1).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Error al cargar productos';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de conexión al cargar productos';
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  bool _isChampagne(Product product) {
    final cat = (product.categoria).toLowerCase();
    return cat.contains('champaña') || cat.contains('shampaña') || cat.contains('champagne');
  }

  int _getMaxHostesses(CartItem item) {
    if (_isChampagne(item.product)) {
      final p = item.product.price;
      if (p >= 240000) return 5;
      if (p >= 200000) return 4;
      if (p >= 140000) return 3;
      if (p >= 120000) return 2;
      return 1;
    }
    return item.quantity;
  }

  String _formatCurrency(double value) {
    final formatter = NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);
    return formatter.format(value);
  }

  // Submit Order logic
  Future<void> _submitOrder() async {
    final cartState = ref.read(cartProvider);
    final user = ref.read(authProvider).user;
    if (cartState.items.isEmpty || user == null) return;

    // Validation: All items with commission must have at least 1 hostess
    for (final item in cartState.items) {
      final hasCommission = item.product.commission > 0;
      if (hasCommission && item.selectedHostesses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text(
              'Asignación requerida: Debes asignar al menos una anfitriona a "${item.product.name}"',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        );
        return;
      }
    }

    String generateCode() {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final random = DateTime.now().microsecondsSinceEpoch;
      String result = '';
      for (int i = 0; i < 8; i++) {
        result += chars[(random + i) % chars.length];
      }
      return result;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final code = generateCode();
      final payload = ref.read(cartProvider.notifier).buildOrderPayload(
            meseroId: user.id,
            codigo: code,
          );

      final client = ref.read(apiClientProvider);
      final res = await client.dio.post('/orders', data: payload);

      if (res.data?['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text('Pedido enviado correctamente. Código: $code',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        );
        ref.read(cartProvider.notifier).clearCart();
        if (!mounted) return;
        Navigator.pop(context);
      } else {
        final msg = res.data?['message'] ?? 'Error al enviar el pedido';
        throw Exception(msg);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text(e.toString().replaceAll('Exception:', ''), style: GoogleFonts.inter(color: Colors.white)),
        ),
      );
    } finally {
      setState(() {
        _submitting = false;
      });
    }
  }

  // Modals for Selection
  void _showClientSelection() {
    final cartState = ref.watch(cartProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Seleccionar Cliente',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      title: Text('Sin Cliente', style: GoogleFonts.inter(color: Colors.white)),
                      trailing: cartState.selectedClientId == null ? const Icon(Icons.check, color: AppTheme.primaryColor) : null,
                      onTap: () {
                        ref.read(cartProvider.notifier).setSelectedClient(null);
                        Navigator.pop(context);
                        setState(() {});
                      },
                    ),
                    const Divider(color: Color(0xFF262629)),
                    ..._clients.map((c) {
                      final isSelected = cartState.selectedClientId == c.id;
                      return ListTile(
                        title: Text(c.fullName, style: GoogleFonts.inter(color: Colors.white)),
                        trailing: isSelected ? const Icon(Icons.check, color: AppTheme.primaryColor) : null,
                        onTap: () {
                          ref.read(cartProvider.notifier).setSelectedClient(c.id);
                          Navigator.pop(context);
                          setState(() {});
                        },
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHostessSelection(CartItem item) {
    final maxHostesses = _getMaxHostesses(item);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentItem = ref.watch(cartProvider).items.firstWhere((i) => i.product.id == item.product.id);
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Asignar Anfitrionas (Máx $maxHostesses)',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _anfitrionas.length,
                      itemBuilder: (context, index) {
                        final a = _anfitrionas[index];
                        final isSelected = currentItem.selectedHostesses.contains(a.id);
                        return ListTile(
                          title: Text(a.nick, style: GoogleFonts.inter(color: Colors.white)),
                          subtitle: Text(a.name, style: GoogleFonts.inter(color: const Color(0xFF9CA3AF), fontSize: 12)),
                          trailing: isSelected ? const Icon(Icons.check, color: AppTheme.primaryColor) : null,
                          onTap: () {
                            final currentList = List<String>.from(currentItem.selectedHostesses);
                            if (isSelected) {
                              currentList.remove(a.id);
                              ref.read(cartProvider.notifier).updateItemHostesses(item.product.id, currentList);
                              setModalState(() {});
                            } else if (currentList.length < maxHostesses) {
                              currentList.add(a.id);
                              ref.read(cartProvider.notifier).updateItemHostesses(item.product.id, currentList);
                              setModalState(() {});
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFFEF4444),
                                  content: Text('Límite alcanzado: Máximo $maxHostesses anfitriona(s) para este producto.',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {});
                      },
                      child: Text('Listo', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
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

  void _showRoomSelection(CartItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        final currentItem = ref.watch(cartProvider).items.firstWhere((i) => i.product.id == item.product.id);
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Seleccionar Habitación',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      title: Text('Sin Habitación', style: GoogleFonts.inter(color: Colors.white)),
                      trailing: currentItem.selectedRoom == null ? const Icon(Icons.check, color: AppTheme.primaryColor) : null,
                      onTap: () {
                        ref.read(cartProvider.notifier).updateItemRoom(item.product.id, null);
                        Navigator.pop(context);
                        setState(() {});
                      },
                    ),
                    const Divider(color: Color(0xFF262629)),
                    ..._rooms.map((r) {
                      final isSelected = currentItem.selectedRoom == r.id;
                      return ListTile(
                        title: Text(r.name, style: GoogleFonts.inter(color: Colors.white)),
                        trailing: isSelected ? const Icon(Icons.check, color: AppTheme.primaryColor) : null,
                        onTap: () {
                          ref.read(cartProvider.notifier).updateItemRoom(item.product.id, r.id);
                          Navigator.pop(context);
                          setState(() {});
                        },
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final authState = ref.watch(authProvider);

    final isCategorySelected = _selectedCategory != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF18181A),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: isCategorySelected
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedCategory = null;
                  });
                },
              )
            : const Icon(Icons.restaurant_rounded, color: AppTheme.primaryColor),
        title: Text(
          isCategorySelected ? _selectedCategory!.name : 'Categorías',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Text(
              authState.user?.nombre ?? '',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF9CA3AF),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
            tooltip: 'Cerrar Sesión',
            onPressed: () {
              ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            )
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        if (isCategorySelected) {
                          _fetchProducts(_selectedCategory!.id);
                        } else {
                          _fetchInitialData();
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                      child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            )
          else if (!isCategorySelected)
            _buildCategoriesGrid()
          else
            _buildProductsView(cartState),

          // Bottom Cart Bar
          if (cartState.items.isNotEmpty) _buildBottomCartBar(cartState),
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    if (_categories.isEmpty) {
      return Center(
        child: Text(
          'No hay categorías activas',
          style: GoogleFonts.inter(color: const Color(0xFF9CA3AF), fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchInitialData(),
      color: AppTheme.primaryColor,
      backgroundColor: const Color(0xFF18181A),
      child: GridView.builder(
        padding: const EdgeInsets.all(20.0),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.1,
        ),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          return InkWell(
            onTap: () {
              setState(() {
                _selectedCategory = category;
              });
              _fetchProducts(category.id);
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF18181A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF262629), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIconForCategory(category.name),
                      size: 32,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      category.name,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductsView(CartState cartState) {
    final filteredProducts = _products.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(_searchQuery) ||
          p.code.toLowerCase().contains(_searchQuery);
      return matchesSearch;
    }).toList();

    return Column(
      children: [
        // Selector de Cliente y Limpieza de Carrito (Si corresponde)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _showClientSelection,
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF262629)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              color: cartState.selectedClientId != null ? AppTheme.primaryColor : const Color(0xFF9CA3AF),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              cartState.selectedClientId != null
                                  ? _clients.firstWhere((cl) => cl.id == cartState.selectedClientId, orElse: () => LocalClient(id: '', name: 'Cliente', lastName: '')).fullName
                                  : 'Seleccionar cliente (opcional)',
                              style: GoogleFonts.inter(
                                color: cartState.selectedClientId != null ? Colors.white : const Color(0xFF9CA3AF),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF9CA3AF)),
                      ],
                    ),
                  ),
                ),
              ),
              if (cartState.items.isNotEmpty) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF18181A),
                        title: Text('Vaciar Carrito', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                        content: Text('¿Deseas eliminar todos los productos del pedido?', style: GoogleFonts.inter(color: const Color(0xFF9CA3AF))),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Cancelar', style: GoogleFonts.inter(color: Colors.white)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                            onPressed: () {
                              ref.read(cartProvider.notifier).clearCart();
                              Navigator.pop(context);
                              setState(() {});
                            },
                            child: Text('Sí, vaciar', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF262629)),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar producto...',
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: Color(0xFF9CA3AF)),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
            ),
          ),
        ),

        // Products List
        Expanded(
          child: filteredProducts.isEmpty
              ? Center(
                  child: Text(
                    'No se encontraron productos',
                    style: GoogleFonts.inter(color: const Color(0xFF9CA3AF), fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 140.0),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    final cartItem = cartState.items.firstWhere(
                      (i) => i.product.id == product.id,
                      orElse: () => CartItem(product: product, quantity: 0),
                    );
                    final qty = cartItem.quantity;
                    final hasCommission = product.commission > 0;
                    final canSelectRoom = product.price >= 30000 && hasCommission;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF18181A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: qty > 0 ? AppTheme.primaryColor.withValues(alpha: 0.3) : const Color(0xFF262629),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Image Placeholder
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F0F10),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF262629)),
                                ),
                                child: product.foto.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          product.foto,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, err, st) => const Icon(
                                            Icons.image_not_supported_rounded,
                                            color: Color(0xFF4B5563),
                                            size: 28,
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.fastfood_rounded,
                                        color: AppTheme.primaryColor,
                                        size: 28,
                                      ),
                              ),
                              const SizedBox(width: 16),

                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Cód: ${product.code}',
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatCurrency(product.price),
                                      style: GoogleFonts.outfit(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFFFB300), // Amber
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Controls
                              Row(
                                children: [
                                  if (qty > 0) ...[
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFEF4444), size: 28),
                                      onPressed: () {
                                        ref.read(cartProvider.notifier).removeFromCart(product.id);
                                        setState(() {});
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$qty',
                                      style: GoogleFonts.outfit(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_rounded, color: AppTheme.primaryColor, size: 30),
                                    onPressed: () {
                                      ref.read(cartProvider.notifier).addToCart(product);
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Commission Configuration Panel
                          if (qty > 0 && hasCommission) ...[
                            const SizedBox(height: 12),
                            const Divider(color: Color(0xFF262629)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF262629),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    icon: const Icon(Icons.person_outline_rounded, size: 16),
                                    label: Text(
                                      cartItem.selectedHostesses.isNotEmpty
                                          ? '${cartItem.selectedHostesses.length} Asignada(s)'
                                          : 'Asignar Anfitriona',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onPressed: () => _showHostessSelection(cartItem),
                                  ),
                                ),
                                if (canSelectRoom) ...[
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF262629),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                      icon: const Icon(Icons.bed_rounded, size: 16),
                                      label: Text(
                                        cartItem.selectedRoom != null
                                            ? _rooms.firstWhere((r) => r.id == cartItem.selectedRoom, orElse: () => LocalRoom(id: '', name: 'Hab')).name
                                            : 'Habitación',
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onPressed: () => _showRoomSelection(cartItem),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (cartItem.selectedHostesses.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.stars_rounded, color: Color(0xFF10B981), size: 14),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      cartItem.selectedHostesses
                                          .map((id) => _anfitrionas.firstWhere((a) => a.id == id, orElse: () => LocalHostess(id: '', nick: '', name: '')).nick)
                                          .where((n) => n.isNotEmpty)
                                          .join(', '),
                                      style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBottomCartBar(CartState cartState) {
    final tipAmount = ref.read(cartProvider.notifier).getTipAmount();
    final total = ref.read(cartProvider.notifier).getTotal();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: const Color(0xFF18181A),
          border: Border(top: BorderSide(color: const Color(0xFF262629), width: 1.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: Tip Switch
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Propina (10%)',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF9CA3AF),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: cartState.tipEnabled,
                      activeThumbColor: AppTheme.primaryColor,
                      onChanged: (val) {
                        ref.read(cartProvider.notifier).setTipEnabled(val);
                        setState(() {});
                      },
                    ),
                  ],
                ),
                if (cartState.tipEnabled)
                  Text(
                    '+${_formatCurrency(tipAmount)}',
                    style: GoogleFonts.outfit(
                      color: AppTheme.primaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Row 2: Totals & Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Pedido',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF9CA3AF),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatCurrency(total),
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                    ),
                    onPressed: _submitting ? null : _submitOrder,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'ENVIAR PEDIDO',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
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

  IconData _getIconForCategory(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('comida') || lowerName.contains('plato') || lowerName.contains('fondo')) {
      return Icons.restaurant_menu_rounded;
    }
    if (lowerName.contains('bebestible') || lowerName.contains('trago') || lowerName.contains('bebida') || lowerName.contains('cerveza')) {
      return Icons.local_bar_rounded;
    }
    if (lowerName.contains('postre') || lowerName.contains('dulce')) {
      return Icons.cake_rounded;
    }
    if (lowerName.contains('entrada') || lowerName.contains('picoteo')) {
      return Icons.tapas_rounded;
    }
    return Icons.restaurant_rounded;
  }
}
