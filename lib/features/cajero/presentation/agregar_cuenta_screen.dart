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

class AgregarCuentaScreen extends ConsumerStatefulWidget {
  final String id;
  const AgregarCuentaScreen({super.key, required this.id});

  @override
  ConsumerState<AgregarCuentaScreen> createState() => _AgregarCuentaScreenState();
}

class _AgregarCuentaScreenState extends ConsumerState<AgregarCuentaScreen> {

  // Original Cuenta details
  Map<String, dynamic>? _cuentaOriginal;

  // Catalog assets
  List<dynamic> _categories = [];
  List<dynamic> _products = [];
  dynamic _selectedCategory;

  // Added items state
  final Map<int, int> _addedCart = {};

  @override
  void initState() {
    super.initState();
    _fetchDetailsAndAssets();
  }

  Future<void> _fetchDetailsAndAssets() async {
    ref.read(refreshProvider('agregar_cuenta').notifier).startRefresh(isManual: false);

    final int? cuentaId = int.tryParse(widget.id);
    if (cuentaId == null) {
      ref.read(refreshProvider('agregar_cuenta').notifier).endRefresh(error: 'ID de cuenta no válido');
      return;
    }

    try {
      final client = ref.read(apiClientProvider);

      final responses = await Future.wait([
        client.dio.get('/cuentas/$cuentaId').catchError((_) => Response(requestOptions: RequestOptions(), data: {'success': false})),
        client.dio.get('/categories').catchError((_) => Response(requestOptions: RequestOptions(), data: {'success': false})),
      ]);

      final cuentaRes = responses[0];
      final categoriesRes = responses[1];

      Map<String, dynamic>? cuentaMap;
      if (cuentaRes.data != null && cuentaRes.data['success'] == true) {
        cuentaMap = cuentaRes.data['data'];
      }

      List<dynamic> categoriesData = [];
      if (categoriesRes.data != null && categoriesRes.data['success'] == true) {
        categoriesData = categoriesRes.data['data'] ?? [];
      }

      if (!mounted) return;
      setState(() {
        _cuentaOriginal = cuentaMap;
        _categories = categoriesData;
      });
      ref.read(refreshProvider('agregar_cuenta').notifier).endRefresh();

      if (_categories.isNotEmpty) {
        _onCategorySelected(_categories.first);
      }
    } catch (e) {
      if (!mounted) return;
      ref.read(refreshProvider('agregar_cuenta').notifier).endRefresh(error: 'Error al cargar detalles de la comanda');
    }
  }

  Future<void> _onCategorySelected(dynamic category) async {
    setState(() {
      _selectedCategory = category;
      _products = [];
    });

    final int catId = int.tryParse(category['id_categoria']?.toString() ?? '') ??
        int.tryParse(category['id']?.toString() ?? '') ?? 0;

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
    } catch (_) {}
  }

  void _addToCart(int productId) {
    setState(() {
      _addedCart[productId] = (_addedCart[productId] ?? 0) + 1;
    });
  }

  void _removeFromCart(int productId) {
    if (!_addedCart.containsKey(productId)) return;
    setState(() {
      if (_addedCart[productId] == 1) {
        _addedCart.remove(productId);
      } else {
        _addedCart[productId] = _addedCart[productId]! - 1;
      }
    });
  }

  double _calculateAddedTotal() {
    double total = 0;
    _addedCart.forEach((prodId, qty) {
      final product = _findProductById(prodId);
      if (product != null) {
        final double price = double.tryParse(product['precio']?.toString() ?? '0') ?? 0.0;
        total += price * qty;
      }
    });
    return total;
  }

  dynamic _findProductById(int id) {
    try {
      return _products.firstWhere((p) =>
          (int.tryParse(p['id_producto']?.toString() ?? '') ??
           int.tryParse(p['id']?.toString() ?? '') ?? 0) == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _submitAdicion() async {
    if (_addedCart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto'), backgroundColor: Colors.orange),
      );
      return;
    }

    final int? idCuenta = int.tryParse(widget.id);
    if (idCuenta == null) return;

    final client = ref.read(apiClientProvider);
    final notifier = ref.read(setStateProvider('agregar_cuenta').notifier);
    notifier.startSubmit();

    try {
      final List<Map<String, dynamic>> itemsPayload = [];
      _addedCart.forEach((prodId, qty) {
        final product = _findProductById(prodId);
        if (product != null) {
          final double price = double.tryParse(product['precio']?.toString() ?? '0') ?? 0.0;
          itemsPayload.add({
            'producto_id': prodId,
            'cantidad': qty,
            'precio': price,
          });
        }
      });

      final response = await client.dio.put(
        '/cuentas/$idCuenta',
        data: {
          'items': itemsPayload,
        },
      );

      if (response.data != null && response.data['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Productos agregados a la cuenta con éxito'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      } else {
        final msg = response.data?['message'] ?? 'Error al agregar productos';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $msg'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión al agregar productos'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) notifier.endSubmit();
    }
  }

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);
    return format.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final refreshState = ref.watch(refreshProvider('agregar_cuenta'));

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor,
      body: Column(
        children: [
          PremiumHeader(
            title: 'Agregar a Cuenta',
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
                  children: [                      if (refreshState.error.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  refreshState.error,
                                  style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    // Account context info card
                    _buildAccountHeader(isDark),
                    const SizedBox(height: 16),

                    // Product Catalog
                    Text(
                      'Productos a Añadir',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildCategoriesBar(isDark),
                    const SizedBox(height: 12),

                    // Products Grid
                    Expanded(
                      child: _buildProductsGrid(isDark),
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
                      VerticalDivider(width: 1, color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
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
                crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.3,
              ),
              itemCount: 6,
              itemBuilder: (context, i) => const SkeletonCard(lines: 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountHeader(bool isDark) {
    if (_cuentaOriginal == null) return const SizedBox();
    return Container(
      width: double.infinity,
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
            'Mesa / Habitación: ${_cuentaOriginal!['room_name'] ?? 'Comanda'}',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 4),
          Text(
            'Cliente: ${_cuentaOriginal!['cliente_nombre'] ?? 'Cliente General'} • Anfitriona: ${_cuentaOriginal!['anfitriona_nombre'] ?? 'Ninguna'}',
            style: GoogleFonts.inter(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
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
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) _onCategorySelected(cat);
              },
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87)),
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
            'No hay productos',
            style: GoogleFonts.inter(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
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
        final int id = int.tryParse(product['id_producto']?.toString() ?? '') ??
            int.tryParse(product['id']?.toString() ?? '') ?? 0;
        final double price = double.tryParse(product['precio']?.toString() ?? '0') ?? 0.0;
        final int cartQty = _addedCart[id] ?? 0;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cartQty > 0
                  ? Theme.of(context).colorScheme.primary
                  : (isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
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
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatCurrency(price),
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (cartQty > 0) ...[
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 22, color: Colors.redAccent),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _removeFromCart(id),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Text(
                        '$cartQty',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  IconButton(
                    icon: Icon(Icons.add_circle, size: 24, color: Theme.of(context).colorScheme.primary),
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
    final double addedTotal = _calculateAddedTotal();
    final double originalTotal = double.tryParse(_cuentaOriginal?['total']?.toString() ?? '0') ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Productos a Agregar',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _buildCartItemsList(isDark),
        ),
        const Divider(height: 24, thickness: 1),
        _buildCheckoutSummaryRow('Total Cuenta Original', _formatCurrency(originalTotal)),
        _buildCheckoutSummaryRow('Monto Adicional', _formatCurrency(addedTotal), color: Colors.green),
        const Divider(height: 12),
        _buildCheckoutSummaryRow('Total Consumo Final', _formatCurrency(originalTotal + addedTotal), isTotal: true),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: AppTheme.getPrimaryButtonStyle(context),
            onPressed: ref.watch(setStateProvider('agregar_cuenta')).isSubmitting ? null : _submitAdicion,
            child: ref.watch(setStateProvider('agregar_cuenta')).isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    'Añadir Productos',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCartItemsList(bool isDark) {
    if (_addedCart.isEmpty) {
      return Center(
        child: Text(
          'Selecciona productos en el catálogo para agregar',
          style: GoogleFonts.inter(fontSize: 13, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }

    final cartList = _addedCart.entries.toList();

    return ListView.builder(
      itemCount: cartList.length,
      itemBuilder: (context, index) {
        final entry = cartList[index];
        final product = _findProductById(entry.key);
        if (product == null) return const SizedBox();

        final double price = double.tryParse(product['precio']?.toString() ?? '0') ?? 0.0;
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
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '$qty x ${_formatCurrency(price)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(
                    _formatCurrency(price * qty),
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    onPressed: () {
                      setState(() {
                        _addedCart.remove(entry.key);
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

  Widget _buildCheckoutSummaryRow(String label, String value, {bool isTotal = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isTotal ? 14 : 12,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isTotal ? 16 : 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartBottomBar(bool isDark) {
    final double addedTotal = _calculateAddedTotal();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
        border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor)),
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
                  'VALOR ADICIONAL',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
                Text(
                  _formatCurrency(addedTotal),
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.green),
                ),
              ],
            ),
            ElevatedButton(
              style: AppTheme.getPrimaryButtonStyle(context).copyWith(
                padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
              ),
              onPressed: () {
                _showCartModalSheet(isDark);
              },
              child: Text(
                'Confirmar (${_addedCart.values.fold(0, (a, b) => a + b)})',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
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
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Revisar Adiciones',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
                  child: _buildCartItemsList(isDark),
                ),
                const Divider(height: 24, thickness: 1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total comanda adicional', style: GoogleFonts.inter(fontSize: 14)),
                    Text(_formatCurrency(_calculateAddedTotal()), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: AppTheme.getPrimaryButtonStyle(context),
                    onPressed: ref.watch(setStateProvider('agregar_cuenta')).isSubmitting
                        ? null
                        : () async {
                            final navigator = Navigator.of(context);
                            await _submitAdicion();
                            if (mounted && !ref.read(setStateProvider('agregar_cuenta')).isSubmitting) {
                              navigator.pop();
                            }
                          },
                    child: ref.watch(setStateProvider('agregar_cuenta')).isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Agregar a Comanda',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
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
