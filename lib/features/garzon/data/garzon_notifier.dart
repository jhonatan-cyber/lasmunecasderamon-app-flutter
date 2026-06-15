import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../auth/data/auth_notifier.dart';
import '../domain/category.dart';
import '../domain/product.dart';

class GarzonState {
  final List<Category> categories;
  final List<Product> products;
  final Category? selectedCategory;
  final bool isLoading;
  final String? error;

  GarzonState({
    this.categories = const [],
    this.products = const [],
    this.selectedCategory,
    this.isLoading = false,
    this.error,
  });

  GarzonState copyWith({
    List<Category>? categories,
    List<Product>? products,
    Category? selectedCategory,
    bool? isLoading,
    String? error,
    bool clearSelectedCategory = false,
    bool clearError = false,
  }) {
    return GarzonState(
      categories: categories ?? this.categories,
      products: products ?? this.products,
      selectedCategory: clearSelectedCategory ? null : (selectedCategory ?? this.selectedCategory),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class GarzonNotifier extends StateNotifier<GarzonState> {
  final ApiClient _apiClient;

  GarzonNotifier(this._apiClient) : super(GarzonState()) {
    fetchCategories();
  }

  Future<void> fetchCategories() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiClient.dio.get('/categories');
      final data = response.data;

      if (data['success'] == true) {
        final List<dynamic> list = data['data'] ?? [];
        final categories = list
            .map((c) => Category.fromJson(c))
            .where((c) => c.status == 1)
            .toList();
            
        // Sort by display order
        categories.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

        state = state.copyWith(
          categories: categories,
          isLoading: false,
        );
      } else {
        final message = data['message'] ?? 'Error al cargar categorías';
        state = state.copyWith(isLoading: false, error: message);
      }
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message ?? 'Error de conexión';
      state = state.copyWith(isLoading: false, error: message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void selectCategory(Category? category) {
    if (category == null) {
      state = state.copyWith(
        clearSelectedCategory: true,
        products: const [],
      );
    } else {
      state = state.copyWith(selectedCategory: category);
      fetchProducts(category.id);
    }
  }

  Future<void> fetchProducts(String categoryId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiClient.dio.get(
        '/products',
        queryParameters: {'category_id': categoryId},
      );
      final data = response.data;

      if (data['success'] == true) {
        final List<dynamic> list = data['data'] ?? [];
        final products = list
            .map((p) => Product.fromJson(p))
            .where((p) => p.status == 1)
            .toList();

        state = state.copyWith(
          products: products,
          isLoading: false,
        );
      } else {
        final message = data['message'] ?? 'Error al cargar productos';
        state = state.copyWith(isLoading: false, error: message);
      }
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message ?? 'Error de conexión';
      state = state.copyWith(isLoading: false, error: message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

// Providers definition
final garzonProvider = StateNotifierProvider<GarzonNotifier, GarzonState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return GarzonNotifier(apiClient);
});
