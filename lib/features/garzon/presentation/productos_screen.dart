import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lasmunecasderamon_flutter/core/theme.dart';
import 'package:lasmunecasderamon_flutter/core/widgets/currency_text.dart';
import 'package:lasmunecasderamon_flutter/core/widgets/premium_header.dart';
import 'package:lasmunecasderamon_flutter/features/auth/data/auth_notifier.dart';
import '../data/cart_notifier.dart';
import '../data/productos_notifier.dart';
import '../domain/category.dart';
import '../domain/product.dart';

class ProductosScreen extends ConsumerStatefulWidget {
  const ProductosScreen({super.key});

  @override
  ConsumerState<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends ConsumerState<ProductosScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(productosProvider.notifier).fetchInitialData(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref.read(productosProvider.notifier).setSearchQuery(query);
  }

  
  
  

  Future<void> _submitOrder() async {
    final cartState = ref.read(cartProvider);
    final user = ref.read(authProvider).user;
    if (cartState.items.isEmpty || user == null) return;

    final notifier = ref.read(productosProvider.notifier);

    
    final validationError = notifier.validateOrder(cartState.items);
    if (validationError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.errorColor,
          content: Text(
            validationError,
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    try {
      final code = notifier.generateCode();
      final payload = ref
          .read(cartProvider.notifier)
          .buildOrderPayload(meseroId: user.id, codigo: code);

      final ok = await notifier.submitOrder(
        meseroId: user.id,
        codigo: code,
        orderPayload: payload,
      );

      if (!mounted) return;

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.successColor,
            content: Text(
              'Pedido enviado correctamente. Código: $code',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        );
        ref.read(cartProvider.notifier).clearCart();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.errorColor,
            content: Text(
              'Error al enviar el pedido',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.errorColor,
          content: Text(
            e.toString().replaceAll('Exception:', ''),
            style: GoogleFonts.inter(color: Colors.white),
          ),
        ),
      );
    }
  }

  
  
  

  void _showClientSelection() {
    final cartState = ref.watch(cartProvider);
    final state = ref.read(productosProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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
                      title: Text(
                        'Sin Cliente',
                        style: GoogleFonts.inter(color: Colors.white),
                      ),
                      trailing: cartState.selectedClientId == null
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        ref
                            .read(cartProvider.notifier)
                            .setSelectedClient(null);
                        Navigator.pop(context);
                      },
                    ),
                    const Divider(color: Color(0xFF262629)),
                    ...state.clients.map((c) {
                      final isSelected = cartState.selectedClientId == c.id;
                      return ListTile(
                        title: Text(
                          c.fullName,
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check,
                                color:
                                    Theme.of(context).colorScheme.primary,
                              )
                            : null,
                        onTap: () {
                          ref
                              .read(cartProvider.notifier)
                              .setSelectedClient(c.id);
                          Navigator.pop(context);
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
    final notifier = ref.read(productosProvider.notifier);
    final maxHostesses = notifier.getMaxHostesses(item);
    final state = ref.read(productosProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentItem = ref
                .watch(cartProvider)
                .items
                .firstWhere((i) => i.product.id == item.product.id);
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
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
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
                      itemCount: state.hostesses.length,
                      itemBuilder: (context, index) {
                        final a = state.hostesses[index];
                        final isSelected = currentItem.selectedHostesses
                            .contains(a.id);
                        return ListTile(
                          title: Text(
                            a.nick,
                            style: GoogleFonts.inter(color: Colors.white),
                          ),
                          subtitle: Text(
                            a.name,
                            style: GoogleFonts.inter(
                              color: AppTheme.darkTextSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                )
                              : null,
                          onTap: () {
                            final currentList = List<String>.from(
                              currentItem.selectedHostesses,
                            );
                            if (isSelected) {
                              currentList.remove(a.id);
                              ref
                                  .read(cartProvider.notifier)
                                  .updateItemHostesses(
                                    item.product.id,
                                    currentList,
                                  );
                              setModalState(() {});
                            } else if (currentList.length < maxHostesses) {
                              currentList.add(a.id);
                              ref
                                  .read(cartProvider.notifier)
                                  .updateItemHostesses(
                                    item.product.id,
                                    currentList,
                                  );
                              setModalState(() {});
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppTheme.errorColor,
                                  content: Text(
                                    'Límite alcanzado: Máximo $maxHostesses anfitriona(s) para este producto.',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Listo',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
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
    final state = ref.read(productosProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final currentItem = ref
            .watch(cartProvider)
            .items
            .firstWhere((i) => i.product.id == item.product.id);
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
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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
                      title: Text(
                        'Sin Habitación',
                        style: GoogleFonts.inter(color: Colors.white),
                      ),
                      trailing: currentItem.selectedRoom == null
                          ? Icon(
                              Icons.check,
                              color:
                                  Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        ref
                            .read(cartProvider.notifier)
                            .updateItemRoom(item.product.id, null);
                        Navigator.pop(context);
                      },
                    ),
                    const Divider(color: Color(0xFF262629)),
                    ...state.rooms.map((r) {
                      final isSelected = currentItem.selectedRoom == r.id;
                      return ListTile(
                        title: Text(
                          r.name,
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check,
                                color:
                                    Theme.of(context).colorScheme.primary,
                              )
                            : null,
                        onTap: () {
                          ref
                              .read(cartProvider.notifier)
                              .updateItemRoom(item.product.id, r.id);
                          Navigator.pop(context);
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
    final state = ref.watch(productosProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBgColor,
      body: Column(
        children: [
          PremiumHeader(
            title: '',
            leadingWidget: state.isCategorySelected
                ? IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(productosProvider.notifier).clearCategorySelection();
                    },
                  )
                : const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.restaurant_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
            centerTitle: state.isCategorySelected
                ? state.selectedCategory?.name ?? 'Categoría'
                : 'Categorías',
            rightWidget: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (cartState.items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.shopping_cart_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${cartState.items.length}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 4.0),
                  child: Text(
                    authState.user?.nombre ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFEF4444),
                  ),
                  tooltip: 'Cerrar Sesión',
                  onPressed: () {
                    ref.read(authProvider.notifier).logout();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                if (state.isLoading)
                  state.isCategorySelected
                      ? Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        )
                      : _buildSkeletonGrid()
                else if (state.error != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: Color(0xFFEF4444),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            state.error!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(
                              Icons.refresh_rounded,
                              size: 18,
                            ),
                            label: Text(
                              'Reintentar',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () {
                              if (state.isCategorySelected) {
                                ref
                                    .read(productosProvider.notifier)
                                    .fetchProducts(
                                      state.selectedCategoryId!,
                                    );
                              } else {
                                ref
                                    .read(productosProvider.notifier)
                                    .fetchInitialData(isManual: true);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                else if (!state.isCategorySelected)
                  _buildCategoriesGrid(state)
                else
                  _buildProductsList(state),
              ],
            ),
          ),

          
          if (cartState.items.isNotEmpty) _buildCartSummaryBar(cartState),
        ],
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.3),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoriesGrid(ProductosState state) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: state.categories.length,
      itemBuilder: (context, index) {
        final cat = state.categories[index];
        return _buildCategoryCard(cat);
      },
    );
  }

  Widget _buildCategoryCard(Category category) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        ref.read(productosProvider.notifier).selectCategory(category);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
              Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.3),
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              category.name.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductsList(ProductosState state) {
    final filteredProducts = state.filteredProducts;

    if (filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              state.searchQuery.isNotEmpty
                  ? 'Sin resultados para "${state.searchQuery}"'
                  : 'No hay productos disponibles',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar producto...',
              hintStyle: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              suffixIcon: state.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(productosProvider.notifier).setSearchQuery('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Text(
                '${filteredProducts.length} producto${filteredProducts.length != 1 ? 's' : ''}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              return _buildProductCard(filteredProducts[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Product product) {
    final cartState = ref.watch(cartProvider);
    final isInCart = cartState.items.any(
      (item) => item.product.id == product.id,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isInCart
              ? Theme.of(context).colorScheme.primary
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          ref.read(cartProvider.notifier).addToCart(product);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    Icons.shopping_bag_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                product.name,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                formatCurrency(product.price),
                style: GoogleFonts.inter(
                  color: Colors.greenAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartSummaryBar(CartState cartState) {
    final double total = cartState.items.fold(
      0.0,
      (sum, item) => sum + (item.product.price * item.quantity),
    );
    final state = ref.read(productosProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.darkSurfaceColor,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${cartState.items.length} producto${cartState.items.length != 1 ? 's' : ''}',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        formatCurrency(total),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    label: Text(
                      'Ver Pedido',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    onPressed: _submitOrder,
                  ),
                ),
              ],
            ),

            
            if (cartState.items.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: Color(0xFF262629)),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: cartState.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final item = cartState.items[index];
                    final itemTotal = item.product.price * item.quantity;
                    final hasCommission = item.product.commission > 0;
                    final hostessCount = item.selectedHostesses.length;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${item.product.name} x${item.quantity}',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatCurrency(itemTotal),
                                  style: GoogleFonts.inter(
                                    color: Colors.greenAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          
                          if (hasCommission || state.rooms.isNotEmpty) ...[
                            if (hasCommission)
                              _buildConfigBadge(
                                label: hostessCount > 0
                                    ? '$hostessCount Anfitriona${hostessCount != 1 ? 's' : ''}'
                                    : 'Anfitrionas',
                                icon: Icons.people_rounded,
                                color: hostessCount > 0
                                    ? Colors.amber
                                    : Colors.white54,
                                onTap: () => _showHostessSelection(item),
                              ),
                            if (state.rooms.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              _buildConfigBadge(
                                label: item.selectedRoom != null
                                    ? 'Habitación ✓'
                                    : 'Habitación',
                                icon: Icons.meeting_room_rounded,
                                color: item.selectedRoom != null
                                    ? Colors.amber
                                    : Colors.white54,
                                onTap: () => _showRoomSelection(item),
                              ),
                            ],
                          ],

                          
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => ref
                                .read(cartProvider.notifier)
                                .removeFromCart(item.product.id),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFFEF4444),
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],

            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: Color(0xFF262629)),
            ),
            Row(
              children: [
                Expanded(
                  child: _buildConfigBadge(
                    label: cartState.selectedClientId != null
                        ? 'Cliente ✓'
                        : 'Seleccionar Cliente',
                    icon: Icons.person_rounded,
                    color: cartState.selectedClientId != null
                        ? Colors.amber
                        : Colors.white54,
                    onTap: _showClientSelection,
                  ),
                ),
                const SizedBox(width: 8),
                _buildConfigBadge(
                  label: cartState.tipEnabled ? 'Propina ✓' : 'Propina',
                  icon: Icons.volunteer_activism_rounded,
                  color: cartState.tipEnabled ? Colors.amber : Colors.white54,
                  onTap: () {
                    ref
                        .read(cartProvider.notifier)
                        .setTipEnabled(!cartState.tipEnabled);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigBadge({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
