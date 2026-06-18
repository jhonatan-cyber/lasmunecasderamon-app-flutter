import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../auth/data/auth_notifier.dart';
import '../domain/category.dart';
import '../domain/product.dart';
import 'productos_models.dart';
import 'cart_notifier.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class ProductosState {
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final List<Category> categories;
  final List<Product> products;
  final List<LocalHostess> hostesses;
  final List<LocalRoom> rooms;
  final List<LocalClient> clients;
  final String dataHash;
  final String searchQuery;
  final String? selectedCategoryId;

  ProductosState({
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.categories = const [],
    this.products = const [],
    this.hostesses = const [],
    this.rooms = const [],
    this.clients = const [],
    this.dataHash = '',
    this.searchQuery = '',
    this.selectedCategoryId,
  });

  ProductosState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    List<Category>? categories,
    List<Product>? products,
    List<LocalHostess>? hostesses,
    List<LocalRoom>? rooms,
    List<LocalClient>? clients,
    String? dataHash,
    String? searchQuery,
    String? selectedCategoryId,
    bool clearError = false,
    bool clearSelectedCategory = false,
  }) {
    return ProductosState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? null : (error ?? this.error),
      categories: categories ?? this.categories,
      products: products ?? this.products,
      hostesses: hostesses ?? this.hostesses,
      rooms: rooms ?? this.rooms,
      clients: clients ?? this.clients,
      dataHash: dataHash ?? this.dataHash,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategoryId:
          clearSelectedCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
    );
  }

  /// Filtered products based on search query.
  List<Product> get filteredProducts {
    if (searchQuery.isEmpty) return products;
    final query = searchQuery.toLowerCase();
    return products.where((p) => p.name.toLowerCase().contains(query)).toList();
  }

  /// Whether a category is currently selected.
  bool get isCategorySelected => selectedCategoryId != null;

  /// The currently selected category object, if any.
  Category? get selectedCategory {
    if (selectedCategoryId == null) return null;
    try {
      return categories.firstWhere((c) => c.id == selectedCategoryId);
    } catch (_) {
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class ProductosNotifier extends StateNotifier<ProductosState> {
  final ApiClient _apiClient;

  ProductosNotifier(this._apiClient) : super(ProductosState());

  // ── Data fetching ───────────────────────────────────────────────────────

  /// Fetch initial catalog data: categories, hostesses, rooms, clients.
  Future<void> fetchInitialData({bool isManual = false}) async {
    if (!mounted) return;
    state = state.copyWith(
      isLoading: !isManual,
      isRefreshing: isManual,
      clearError: true,
    );

    try {
      final responses = await Future.wait<Response<dynamic>>([
        _apiClient.dio.get('/categories'),
        _apiClient.dio.get('/anfitrionas'),
        _apiClient.dio.get('/rooms?status=1'),
        _apiClient.dio.get('/clients'),
      ]);

      if (!mounted) return;

      final catRes = responses[0];
      final anfRes = responses[1];
      final roomRes = responses[2];
      final clientRes = responses[3];

      // Parse categories
      List<Category> categories = [];
      if (catRes.data?['success'] == true && catRes.data?['data'] is List) {
        categories = (catRes.data['data'] as List)
            .map((x) => Category.fromJson(x))
            .toList();
      }
      categories.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

      // Parse hostesses
      List<LocalHostess> hostesses = [];
      final anfData = anfRes.data;
      if (anfData != null) {
        final rawList = anfData['data'] ?? (anfData is List ? anfData : null);
        if (rawList is List) {
          hostesses = rawList
              .map((x) => LocalHostess.fromMap(Map<String, dynamic>.from(x)))
              .toList();
        }
      }

      // Parse rooms
      List<LocalRoom> rooms = [];
      if (roomRes.data?['success'] == true &&
          roomRes.data?['data'] is List) {
        rooms = (roomRes.data['data'] as List)
            .map((x) => LocalRoom.fromMap(Map<String, dynamic>.from(x)))
            .toList();
      }

      // Parse clients
      List<LocalClient> clients = [];
      final cData = clientRes.data;
      if (cData != null) {
        final rawList = cData['data'] ?? (cData is List ? cData : null);
        if (rawList is List) {
          clients = rawList
              .map((x) => LocalClient.fromMap(Map<String, dynamic>.from(x)))
              .toList();
        }
      }

      state = state.copyWith(
        categories: categories,
        products: [],
        hostesses: hostesses,
        rooms: rooms,
        clients: clients,
        isLoading: false,
        isRefreshing: false,
        clearSelectedCategory: true,
        searchQuery: '',
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: 'Error de conexión al cargar datos de catálogo',
      );
    }
  }

  /// Fetch products for a specific category.
  Future<void> fetchProducts(String categoryId) async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, clearError: true, searchQuery: '');

    try {
      final res = await _apiClient.dio.get(
        '/products?category_id=$categoryId',
      );

      if (!mounted) return;

      if (res.data?['success'] == true && res.data?['data'] is List) {
        final allProducts = (res.data['data'] as List)
            .map((x) => Product.fromJson(x))
            .toList();
        state = state.copyWith(
          products: allProducts.where((p) => p.status == 1).toList(),
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Error al cargar productos',
        );
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Error de conexión al cargar productos',
      );
    }
  }

  // ── Search & selection ─────────────────────────────────────────────────

  /// Update search query (called from search field onChange).
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Select a category and fetch its products.
  void selectCategory(Category category) {
    state = state.copyWith(
      selectedCategoryId: category.id,
      searchQuery: '',
    );
    fetchProducts(category.id);
  }

  /// Clear category selection and go back to category grid.
  void clearCategorySelection() {
    state = state.copyWith(
      clearSelectedCategory: true,
      products: [],
      searchQuery: '',
    );
  }

  // ── Order submission ───────────────────────────────────────────────────

  /// Validates the cart before submitting.
  /// Returns null if valid, or an error message string if invalid.
  String? validateOrder(List<CartItem> items) {
    if (items.isEmpty) return 'El carrito está vacío';

    for (final item in items) {
      final hasCommission = item.product.commission > 0;
      if (hasCommission && item.selectedHostesses.isEmpty) {
        return 'Debes asignar al menos una anfitriona a "${item.product.name}"';
      }
    }
    return null;
  }

  /// Submit an order.
  Future<bool> submitOrder({
    required String meseroId,
    required String codigo,
    required Map<String, dynamic> orderPayload,
  }) async {
    try {
      final res = await _apiClient.dio.post('/orders', data: orderPayload);

      if (res.data?['success'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  /// Whether a product is a champagne category.
  bool isChampagne(Product product) {
    final cat = product.categoria.toLowerCase();
    return cat.contains('champaña') ||
        cat.contains('champagne') ||
        cat.contains('shampaña');
  }

  /// Maximum number of hostesses allowed for a cart item.
  int getMaxHostesses(CartItem item) {
    if (isChampagne(item.product)) {
      final p = item.product.price;
      if (p >= 240000) return 5;
      if (p >= 200000) return 4;
      if (p >= 140000) return 3;
      if (p >= 120000) return 2;
      return 1;
    }
    return item.quantity;
  }

  /// Generate a random 8-character order code.
  String generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random();
    return String.fromCharCodes(
      Iterable.generate(8, (_) => chars.codeUnitAt(rng.nextInt(chars.length))),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final productosProvider =
    StateNotifierProvider.autoDispose<ProductosNotifier, ProductosState>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return ProductosNotifier(apiClient);
});
