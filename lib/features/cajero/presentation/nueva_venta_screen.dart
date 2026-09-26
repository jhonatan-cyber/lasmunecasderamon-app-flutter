import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../core/caja_status.dart';
import '../../../core/hooks/refresh_provider.dart';
import '../../../core/hooks/set_state_provider.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/caja_closed_banner.dart';
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
  // Catálogo acumulado de todas las categorías abiertas: el carrito vive entre
  // categorías (antes se buscaba en la categoría activa y al cambiar se
  // perdían los ítems del total y del payload en silencio).
  final Map<String, dynamic> _catalog = {};

  // Búsqueda global de productos (paridad con `NewSaleSearch` del dashboard):
  // `GET /products?for_sale=1&term=` con debounce de 300 ms.
  String _searchText = '';
  List<dynamic> _searchResults = [];
  bool _searchLoading = false;
  Timer? _searchTimer;
  int _searchSeq = 0;
  // TextEditingController: sin él, «Limpiar» vaciaba el estado pero el
  // campo seguía mostrando el texto (TextField sin controller es uncontrolled).
  final TextEditingController _searchController = TextEditingController();

  dynamic _selectedAnfitriona;
  dynamic _selectedRoom;
  dynamic _selectedClient;
  dynamic _selectedCategory;

  // IDs varchar(36): con claves int todos los productos colisionaban en 0.
  final Map<String, int> _cart = {};
  String _paymentMethod = 'efectivo';

  // Estado de la caja (paridad con `CajaStatusCheck` del dashboard y el check
  // de Expo): null = desconocido (no bloquea), false = caja cerrada.
  bool? _cajaAbierta;

  @override
  void initState() {
    super.initState();
    // Diferido: escribir el provider dentro de initState rompe el primer
    // build (mismo patrón que el administrativo con `Future.microtask`).
    Future.microtask(_fetchAssets);
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAssets() async {
    ref
        .read(refreshProvider('nueva_venta').notifier)
        .startRefresh(isManual: false);

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
        client.dio
            .get('/categories')
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
      final categoriesRes = responses[4];

      // Caja abierta: solo bloquea cuando el backend lo confirma; si la
      // petición falla queda en null y no impide vender (mismo criterio que
      // el estado de verificación del dashboard).
      final bool? cajaAbierta = _parseCajaStatus(cajaRes);

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
        _cajaAbierta = cajaAbierta;
        _anfitrionas = anfitrionasData;
        _rooms = roomsData;
        _clients = clientsData;
        _categories = _filterSaleCategories(categoriesData);
      });
      ref.read(refreshProvider('nueva_venta').notifier).endRefresh();

      if (_categories.isNotEmpty) {
        _onCategorySelected(_categories.first);
      }
    } catch (e) {
      if (!mounted) return;
      ref
          .read(refreshProvider('nueva_venta').notifier)
          .endRefresh(error: 'Error al cargar recursos de venta');
    }
  }

  /// Parsea `GET /cashregister/status`: `true`/`false` cuando el backend lo
  /// confirma y `null` cuando no se pudo determinar (no pisa el estado).
  bool? _parseCajaStatus(Response response) => parseCajaAbierta(response);

  /// Tras volver de la pantalla de Caja se refresca **solo** el estado de la
  /// caja: el catálogo, el carrito y los selectores no se recargan.
  Future<void> _refreshCajaStatus() async {
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.get('/cashregister/status');
      final bool? abierta = _parseCajaStatus(response);
      if (!mounted || abierta == null) return;
      setState(() => _cajaAbierta = abierta);
    } catch (_) {
      // Sin conexión se conserva el último estado conocido.
    }
  }

  Future<void> _onCategorySelected(dynamic category) async {
    setState(() {
      _selectedCategory = category;
      _products = [];
      // Elegir una categoría sale del modo búsqueda y vuelve al grid.
      _searchTimer?.cancel();
      _searchSeq++;
      _searchText = '';
      _searchResults = [];
      _searchLoading = false;
      _searchController.clear();
    });

    final String catId = (category['id_categoria'] ?? category['id'] ?? '')
        .toString();

    if (catId.isEmpty || catId == 'null') return;

    try {
      final client = ref.read(apiClientProvider);
      // Catálogo de venta (mismo endpoint que el dashboard): presentaciones
      // con stock real en el bar, no el catálogo admin de productos.
      final response = await client.dio.get(
        '/products?for_sale=1&category_id=$catId',
      );

      if (response.data != null && response.data['success'] == true) {
        if (!mounted) return;
        final List<dynamic> rows = response.data['data'] ?? [];
        final normalized = rows.map(_mapForSaleItem).toList();
        setState(() {
          _products = normalized;
          for (final item in normalized) {
            _catalog[_itemKey(item)] = item;
          }
        });
      }
    } catch (_) {}
  }

  /// Búsqueda con debounce (espejo de `useSaleValidation` del dashboard:
  /// 300 ms de espera antes de pedir `GET /products?for_sale=1&term=`).
  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchSeq++; // invalida la respuesta en vuelo del término anterior
    final String term = value.trim();
    if (term.isEmpty) {
      setState(() {
        _searchText = value;
        _searchResults = [];
        _searchLoading = false;
      });
      return;
    }
    setState(() {
      _searchText = value;
      _searchLoading = true;
    });
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      _runSearch(term);
    });
  }

  Future<void> _runSearch(String term) async {
    final int seq = ++_searchSeq;
    try {
      final client = ref.read(apiClientProvider);
      // Mismo endpoint del dashboard: solo presentaciones en venta (for_sale).
      final response = await client.dio.get(
        '/products?for_sale=1&term=${Uri.encodeComponent(term)}',
      );
      if (!mounted || seq != _searchSeq) return;
      if (response.data != null && response.data['success'] == true) {
        final List<dynamic> rows = response.data['data'] ?? [];
        setState(() {
          _searchResults = rows.map(_mapForSaleItem).toList();
          _searchLoading = false;
          // El carrito resuelve precio/comisión desde el catálogo acumulado.
          for (final item in _searchResults) {
            _catalog[_itemKey(item)] = item;
          }
        });
      } else {
        setState(() => _searchLoading = false);
      }
    } catch (_) {
      if (!mounted || seq != _searchSeq) return;
      setState(() => _searchLoading = false);
    }
  }

  void _clearSearch() {
    _searchTimer?.cancel();
    _searchSeq++;
    _searchController.clear();
    setState(() {
      _searchText = '';
      _searchResults = [];
      _searchLoading = false;
    });
  }

  /// Categorías vendibles (paridad con el filtro del dashboard:
  /// `estado === 1 && productCount > 0`).
  List<dynamic> _filterSaleCategories(List<dynamic> categories) {
    return categories.where((c) {
      final status =
          int.tryParse((c['status'] ?? c['estado'] ?? '').toString()) ?? 0;
      final total =
          int.tryParse(
            (c['total_products'] ?? c['productCount'] ?? '').toString(),
          ) ??
          0;
      return status == 1 && total > 0;
    }).toList();
  }

  /// Normaliza una fila de `GET /products?for_sale=1` al shape del carro
  /// (espejo de `mapForSaleToCartItem` del dashboard): id = presentación,
  /// nombre = producto + presentación, precio = `precio_venta` y comisión 0
  /// para venta simple (≤ tope `umbral_simple_hasta`, default 10000).
  Map<String, dynamic> _mapForSaleItem(dynamic raw) {
    final Map<String, dynamic> item = Map<String, dynamic>.from(raw as Map);
    final String presentacionId = (item['presentacion_id'] ?? '').toString();
    final String productoId = (item['producto_id'] ?? item['id_producto'] ?? '')
        .toString();
    final String nombre = [
      (item['producto_nombre'] ?? '').toString(),
      (item['presentacion_nombre'] ?? '').toString(),
    ].where((part) => part.isNotEmpty).join(' ');
    final double precio =
        double.tryParse(item['precio_venta']?.toString() ?? '0') ?? 0.0;
    final double comisionBruta =
        double.tryParse(item['comision']?.toString() ?? '0') ?? 0.0;
    return {
      ...item,
      'id': presentacionId,
      'presentacion_id': presentacionId,
      'producto_id': productoId,
      'id_producto': productoId,
      'nombre': nombre,
      'precio': precio,
      // Venta simple (precio ≤ tope): sin comisión, igual que el dashboard.
      'comision': precio <= 10000 ? 0.0 : comisionBruta,
      'stock_bar': int.tryParse(item['stock_bar']?.toString() ?? '') ?? 0,
    };
  }

  /// Clave de línea del carrito: la presentación vendida (dos presentaciones
  /// del mismo producto son líneas distintas, como en el dashboard).
  String _itemKey(dynamic product) =>
      (product['presentacion_id'] ??
              product['id_producto'] ??
              product['id'] ??
              '')
          .toString();

  void _addToCart(String productId) {
    setState(() {
      _cart[productId] = (_cart[productId] ?? 0) + 1;
    });
  }

  void _removeFromCart(String productId) {
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

  /// Busca en el catálogo acumulado: el carrito no depende de la categoría
  /// que esté activa.
  dynamic _findProductById(String id) {
    return _catalog[id];
  }

  Future<void> _submitVenta() async {
    // Red de seguridad: el botón ya viene deshabilitado con la caja cerrada.
    if (_cajaAbierta == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe abrir la caja antes de registrar la venta'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
      // El prepago NO se cobra desde aquí: `POST /clients/prepago` exige
      // tipo='CARGA' (es una recarga de saldo) y la venta fallaba siempre.
      // El backend descuenta el saldo al crear la venta con metodo_pago prepago.
      if (_paymentMethod == 'prepago' && _selectedClient == null) {
        notifier.endSubmit();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debe seleccionar un cliente para pago prepago'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      double comisionTotal = 0;
      final List<Map<String, dynamic>> detallesPayload = [];
      _cart.forEach((prodId, qty) {
        final product = _findProductById(prodId);
        if (product != null) {
          final double price =
              double.tryParse(product['precio']?.toString() ?? '0') ?? 0.0;
          final double comision =
              (double.tryParse(product['comision']?.toString() ?? '0') ?? 0.0) *
              qty;
          comisionTotal += comision;
          detallesPayload.add({
            // FK real del producto + presentación vendida (paridad con el
            // payload del dashboard: consume stock en el bar) y venta por
            // botella por defecto, igual que `mapForSaleToCartItem`.
            'producto_id':
                (product['producto_id'] ?? product['id_producto'] ?? prodId)
                    .toString(),
            'presentacion_id': product['presentacion_id']?.toString(),
            'tipo_venta': 'botella',
            'cantidad': qty,
            'precio': price,
            'sub_total': price * qty,
            'comision': comision,
          });
        }
      });

      final String? clienteId = _selectedClient != null
          ? (_selectedClient['id_cliente'] ?? _selectedClient['id'] ?? '')
                .toString()
          : null;

      final String? anfitrionaId = _selectedAnfitriona != null
          ? (_selectedAnfitriona['id_anfitriona'] ??
                    _selectedAnfitriona['id'] ??
                    '')
                .toString()
          : null;

      final String? habitacionId = _selectedRoom != null
          ? (_selectedRoom['id_room'] ?? _selectedRoom['id'] ?? '').toString()
          : null;

      final int tiempo =
          int.tryParse(_selectedRoom?['tiempo']?.toString() ?? '') ?? 0;

      // Contrato real de POST /sales (SaleCreateSchema): `total` y `detalles`
      // (producto_id/precio/cantidad/sub_total/comision) son obligatorios; el
      // payload anterior (`items` + `room_id`) fallaba la validación.
      final response = await client.dio.post(
        '/sales',
        data: {
          'cliente_id': clienteId,
          'habitacion_id': (habitacionId?.isEmpty ?? true)
              ? null
              : habitacionId,
          'metodo_pago': _paymentMethod,
          'sub_total': total,
          'total': total,
          'total_comision': comisionTotal,
          'tiempo': tiempo,
          'detalles': detallesPayload,
          'usuarios': (anfitrionaId?.isNotEmpty ?? false)
              ? [anfitrionaId]
              : <String>[],
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
                      if (_cajaAbierta == false) ...[
                        CajaClosedBanner(
                          onReturnedFromCaja: _refreshCajaStatus,
                        ),
                        const SizedBox(height: 16),
                      ],
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
                      _buildSearchBar(isDark),
                      const SizedBox(height: 12),
                      _buildCategoriesBar(isDark),
                      const SizedBox(height: 12),

                      // Con texto de búsqueda se muestran los resultados
                      // (como NewSaleSearch); sin él, el grid por categoría.
                      Expanded(
                        child: _searchText.trim().isNotEmpty
                            ? _buildSearchResults(isDark)
                            : _buildProductsGrid(isDark),
                      ),
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
                          c['name'] ?? c['nombre'] ?? 'Cliente',
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
                    a['nick'] ?? a['name'] ?? a['nombre'] ?? 'Anfitriona',
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
                cat['name'] ?? cat['nombre'] ?? 'Categoría',
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

  /// Campo «Buscar Producto» + botón «Limpiar» (paridad con `NewSaleSearch`).
  Widget _buildSearchBar(bool isDark) {
    final Color borderColor = isDark
        ? AppTheme.darkBorderColor
        : AppTheme.lightBorderColor;
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const Key('nueva_venta_search_input'),
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: GoogleFonts.inter(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Buscar Producto',
              hintStyle: GoogleFonts.inter(
                fontSize: 13,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              filled: true,
              fillColor: isDark
                  ? AppTheme.darkSurfaceColor
                  : AppTheme.lightSurfaceColor,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
        if (_searchText.isNotEmpty) ...[
          const SizedBox(width: 8),
          OutlinedButton.icon(
            key: const Key('nueva_venta_search_clear'),
            onPressed: _clearSearch,
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Limpiar'),
          ),
        ],
      ],
    );
  }

  /// Resultados de la búsqueda (mismos estados que `NewSaleSearch` del
  /// dashboard: «Buscando...» y «No hay resultados»).
  Widget _buildSearchResults(bool isDark) {
    final Color secondaryColor = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;
    final Color surfaceColor = isDark
        ? AppTheme.darkSurfaceColor
        : AppTheme.lightSurfaceColor;
    final Color borderColor = isDark
        ? AppTheme.darkBorderColor
        : AppTheme.lightBorderColor;

    if (_searchLoading) {
      return Center(
        child: Text(
          'Buscando...',
          style: GoogleFonts.inter(fontSize: 13, color: secondaryColor),
        ),
      );
    }
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'No hay resultados',
          style: GoogleFonts.inter(fontSize: 13, color: secondaryColor),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final product = _searchResults[index];
        final String id = _itemKey(product);
        final double price =
            double.tryParse(product['precio']?.toString() ?? '0') ?? 0.0;
        final double comision =
            double.tryParse(product['comision']?.toString() ?? '0') ?? 0.0;
        final int cartQty = _cart[id] ?? 0;
        // Tope de stock en el bar (igual que en el grid de categoría).
        final int stockBar =
            int.tryParse(product['stock_bar']?.toString() ?? '') ?? 999999;
        final bool canAdd = cartQty < stockBar;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cartQty > 0
                  ? Theme.of(context).colorScheme.primary
                  : borderColor,
              width: cartQty > 0 ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
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
                      [
                        (product['categoria_nombre'] ?? '').toString(),
                        'Comisión ${_formatCurrency(comision)}',
                      ].join(' · '),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatCurrency(price),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
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
                      color: canAdd
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: canAdd ? () => _addToCart(id) : null,
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
        final String id = _itemKey(product);
        final double price =
            double.tryParse(product['precio']?.toString() ?? '0') ?? 0.0;
        final int cartQty = _cart[id] ?? 0;
        // Tope de stock en el bar (máximo que acepta el dashboard): con
        // `presentacion_id` el backend consume unidades y revierte la venta
        // entera si no alcanza (INSUFFICIENT_BAR_STOCK).
        final int stockBar =
            int.tryParse(product['stock_bar']?.toString() ?? '') ?? 999999;
        final bool canAdd = cartQty < stockBar;

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
                      color: canAdd
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: canAdd ? () => _addToCart(id) : null,
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
            onPressed:
                ref.watch(setStateProvider('nueva_venta')).isSubmitting ||
                    _cajaAbierta == false
                ? null
                : _submitVenta,
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
                    onPressed:
                        ref
                                .watch(setStateProvider('nueva_venta'))
                                .isSubmitting ||
                            _cajaAbierta == false
                        ? null
                        : () async {
                            final navigator = Navigator.of(context);
                            await _submitVenta();
                            if (mounted &&
                                !ref
                                    .read(setStateProvider('nueva_venta'))
                                    .isSubmitting) {
                              navigator.pop();
                            }
                          },
                    child:
                        ref.watch(setStateProvider('nueva_venta')).isSubmitting
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
