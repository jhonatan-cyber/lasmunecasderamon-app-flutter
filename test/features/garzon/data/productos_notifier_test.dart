import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:lasmunecasderamon_flutter/core/api_client.dart';
import 'package:lasmunecasderamon_flutter/features/garzon/data/cart_notifier.dart';
import 'package:lasmunecasderamon_flutter/features/garzon/data/productos_notifier.dart';
import 'package:lasmunecasderamon_flutter/features/garzon/domain/product.dart';
import 'package:shared_preferences/shared_preferences.dart';





Dio _dioWithConditionalResponse({
  required Map<String, dynamic> routeToData,
  int statusCode = 200,
}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final path = options.path;
        final matched = routeToData.entries.firstWhere(
          (e) => path.startsWith(e.key),
          orElse: () => MapEntry('', null),
        );
        if (matched.value != null) {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: statusCode,
              data: matched.value,
            ),
          );
        } else {
          handler.reject(
            DioException(requestOptions: options, error: 'No mock for $path'),
          );
        }
      },
    ),
  );
  return dio;
}

Dio _dioWithError() {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(
          DioException(requestOptions: options, error: 'Connection error'),
        );
      },
    ),
  );
  return dio;
}

ProductosNotifier _buildNotifier(Dio dio) {
  return ProductosNotifier(ApiClient(dio: dio));
}

Product _makeProduct({
  String id = 'p1',
  String name = 'Test Product',
  double price = 10000,
  String categoria = 'Bebidas',
  double commission = 0,
  int status = 1,
}) {
  return Product(
    id: id,
    code: '',
    name: name,
    categoryId: 'cat1',
    price: price,
    commission: commission,
    description: '',
    status: status,
    foto: '',
    categoria: categoria,
  );
}

CartItem _makeCartItem({
  String id = 'p1',
  String name = 'Test',
  double price = 10000,
  String categoria = 'Bebidas',
  double commission = 0,
  List<String> hostesses = const [],
}) {
  return CartItem(
    product: _makeProduct(
      id: id,
      name: name,
      price: price,
      categoria: categoria,
      commission: commission,
    ),
    quantity: 1,
    selectedHostesses: hostesses,
    selectedRoom: null,
  );
}





Map<String, dynamic> categoriesData() => {
      'success': true,
      'data': [
        {'id': 1, 'name': 'Bebidas', 'display_order': 1, 'status': 1},
        {'id': 2, 'name': 'Comidas', 'display_order': 2, 'status': 1},
      ],
    };

Map<String, dynamic> hostessesData() => {
      'success': true,
      'data': [
        {'id': 1, 'nick': 'Lu', 'name': 'Luisa'},
        {'id': 2, 'nick': 'Ma', 'name': 'María'},
      ],
    };

Map<String, dynamic> roomsData() => {
      'success': true,
      'data': [
        {'id': 1, 'name': '101'},
        {'id': 2, 'name': 'VIP'},
      ],
    };

Map<String, dynamic> clientsData() => {
      'success': true,
      'data': [
        {'id': 1, 'nombre': 'Juan', 'apellido': 'Pérez'},
        {'id': 2, 'nombre': 'Ana', 'apellido': 'López'},
      ],
    };

Map<String, dynamic> productsData() => {
      'success': true,
      'data': [
        {
          'id': 10,
          'name': 'Coca Cola',
          'price': 1500,
          'categoria': 'Bebidas',
          'status': 1,
          'commission': 0,
          'image_url': '',
        },
        {
          'id': 11,
          'name': 'Sprite',
          'price': 1500,
          'categoria': 'Bebidas',
          'status': 1,
          'commission': 0,
          'image_url': '',
        },
        {
          'id': 12,
          'name': 'Fanta',
          'price': 1500,
          'categoria': 'Bebidas',
          'status': 1,
          'commission': 0,
          'image_url': '',
        },
      ],
    };

Map<String, dynamic> emptyData() => {'success': true, 'data': []};
Map<String, dynamic> successResponse() => {'success': true};
Map<String, dynamic> failResponse() => {
      'success': false,
      'message': 'Error del servidor',
    };





void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStoragePlatform.instance = FakeSecureStorage();
  });

  
  
  

  group('initial state', () {
    test('has correct defaults', () {
      final notifier = _buildNotifier(Dio());
      expect(notifier.state.isLoading, false);
      expect(notifier.state.isRefreshing, false);
      expect(notifier.state.error, isNull);
      expect(notifier.state.categories, []);
      expect(notifier.state.products, []);
      expect(notifier.state.hostesses, []);
      expect(notifier.state.rooms, []);
      expect(notifier.state.clients, []);
      expect(notifier.state.searchQuery, '');
      expect(notifier.state.selectedCategoryId, isNull);
      expect(notifier.state.isCategorySelected, false);
      expect(notifier.state.selectedCategory, isNull);
      expect(notifier.state.filteredProducts, []);
      notifier.dispose();
    });
  });

  
  
  

  group('fetchInitialData', () {
    test('populates all catalogs on success', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(routeToData: {
          '/categories': categoriesData(),
          '/anfitrionas': hostessesData(),
          '/rooms': roomsData(),
          '/clients': clientsData(),
        }),
      );

      await notifier.fetchInitialData();

      expect(notifier.state.isLoading, false);
      expect(notifier.state.categories.length, 2);
      expect(notifier.state.hostesses.length, 2);
      expect(notifier.state.rooms.length, 2);
      expect(notifier.state.clients.length, 2);
      expect(notifier.state.error, isNull);
      notifier.dispose();
    });

    test('handles empty data gracefully', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(routeToData: {
          '/categories': emptyData(),
          '/anfitrionas': emptyData(),
          '/rooms': emptyData(),
          '/clients': emptyData(),
        }),
      );

      await notifier.fetchInitialData();

      expect(notifier.state.categories, []);
      expect(notifier.state.hostesses, []);
      expect(notifier.state.rooms, []);
      expect(notifier.state.clients, []);
      notifier.dispose();
    });

    test('sets isRefreshing on manual refresh', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(routeToData: {
          '/categories': emptyData(),
          '/anfitrionas': emptyData(),
          '/rooms': emptyData(),
          '/clients': emptyData(),
        }),
      );

      final future = notifier.fetchInitialData(isManual: true);
      expect(notifier.state.isRefreshing, true);
      expect(notifier.state.isLoading, false);
      await future;
      expect(notifier.state.isRefreshing, false);
      notifier.dispose();
    });

    test('clears selected category and search on initial fetch', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(routeToData: {
          '/categories': categoriesData(),
          '/anfitrionas': emptyData(),
          '/rooms': emptyData(),
          '/clients': emptyData(),
        }),
      );

      
      notifier.setSearchQuery('test');
      await notifier.fetchInitialData();

      expect(notifier.state.searchQuery, '');
      expect(notifier.state.selectedCategoryId, isNull);
      expect(notifier.state.isCategorySelected, false);
      notifier.dispose();
    });

    test('sets error on DioException', () async {
      final notifier = _buildNotifier(_dioWithError());

      await notifier.fetchInitialData();

      expect(notifier.state.isLoading, false);
      expect(notifier.state.error, isNotEmpty);
      notifier.dispose();
    });
  });

  
  
  

  group('fetchProducts', () {
    test('populates products on success', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(routeToData: {
          '/products': productsData(),
        }),
      );

      await notifier.fetchProducts('1');

      expect(notifier.state.isLoading, false);
      expect(notifier.state.products.length, 3);
      expect(notifier.state.products.first.name, 'Coca Cola');
      notifier.dispose();
    });

    test('clears search on fetch products', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(routeToData: {
          '/products': productsData(),
        }),
      );

      notifier.setSearchQuery('old query');
      await notifier.fetchProducts('1');

      expect(notifier.state.searchQuery, '');
      notifier.dispose();
    });

    test('sets error on API failure', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(routeToData: {
          '/products': failResponse(),
        }),
      );

      await notifier.fetchProducts('1');

      expect(notifier.state.error, isNotEmpty);
      notifier.dispose();
    });

    test('sets error on DioException', () async {
      final notifier = _buildNotifier(_dioWithError());

      await notifier.fetchProducts('1');

      expect(notifier.state.error, isNotEmpty);
      notifier.dispose();
    });
  });

  
  
  

  group('search and selection', () {
    test('setSearchQuery updates searchQuery', () {
      final notifier = _buildNotifier(Dio());

      notifier.setSearchQuery('cola');
      expect(notifier.state.searchQuery, 'cola');

      notifier.setSearchQuery('');
      expect(notifier.state.searchQuery, '');
      notifier.dispose();
    });

    test('filteredProducts returns all when search is empty', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(routeToData: {
          '/products': productsData(),
          '/categories': categoriesData(),
          '/anfitrionas': emptyData(),
          '/rooms': emptyData(),
          '/clients': emptyData(),
        }),
      );
      await notifier.fetchProducts('1');

      expect(notifier.state.filteredProducts.length, 3);
      notifier.dispose();
    });

    test('filteredProducts filters by name', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(routeToData: {
          '/products': productsData(),
          '/categories': categoriesData(),
          '/anfitrionas': emptyData(),
          '/rooms': emptyData(),
          '/clients': emptyData(),
        }),
      );
      await notifier.fetchProducts('1');

      notifier.setSearchQuery('coca');
      expect(notifier.state.filteredProducts.length, 1);
      expect(notifier.state.filteredProducts.first.name, 'Coca Cola');

      notifier.setSearchQuery('sprite');
      expect(notifier.state.filteredProducts.length, 1);
      expect(notifier.state.filteredProducts.first.name, 'Sprite');

      notifier.setSearchQuery('XYZ');
      expect(notifier.state.filteredProducts, []);
      notifier.dispose();
    });

    test('selectCategory sets category and fetches products', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(routeToData: {
          '/categories': categoriesData(),
          '/products': productsData(),
          '/anfitrionas': emptyData(),
          '/rooms': emptyData(),
          '/clients': emptyData(),
        }),
      );
      await notifier.fetchInitialData();

      expect(notifier.state.categories.length, 2);
      final bebidas = notifier.state.categories[0];
      expect(bebidas.name, 'Bebidas');

      notifier.selectCategory(bebidas);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(notifier.state.selectedCategoryId, '1');
      expect(notifier.state.isCategorySelected, true);
      expect(notifier.state.selectedCategory?.name, 'Bebidas');
      expect(notifier.state.products.length, 3);
      notifier.dispose();
    });

    test('clearCategorySelection resets to grid view', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(routeToData: {
          '/categories': categoriesData(),
          '/products': productsData(),
          '/anfitrionas': emptyData(),
          '/rooms': emptyData(),
          '/clients': emptyData(),
        }),
      );
      await notifier.fetchInitialData();
      notifier.selectCategory(notifier.state.categories[0]);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(notifier.state.isCategorySelected, true);

      notifier.clearCategorySelection();

      expect(notifier.state.isCategorySelected, false);
      expect(notifier.state.selectedCategoryId, isNull);
      expect(notifier.state.products, []);
      expect(notifier.state.searchQuery, '');
      notifier.dispose();
    });

    test('selectedCategory returns null when no category selected', () {
      final notifier = _buildNotifier(Dio());

      expect(notifier.state.selectedCategory, isNull);
      notifier.dispose();
    });

    test('selectedCategory returns null for invalid category id', () {
      final notifier = _buildNotifier(Dio());

      
      notifier.state = notifier.state.copyWith(
        selectedCategoryId: 'nonexistent',
      );
      expect(notifier.state.selectedCategory, isNull);
      notifier.dispose();
    });
  });

  
  
  

  group('isChampagne', () {
    test('returns true for champagne category', () {
      final notifier = _buildNotifier(Dio());
      final p = _makeProduct(categoria: 'Champaña');

      expect(notifier.isChampagne(p), true);
      notifier.dispose();
    });

    test('returns true for champagne with alternate spelling', () {
      final notifier = _buildNotifier(Dio());
      final p1 = _makeProduct(categoria: 'Champagne');
      final p2 = _makeProduct(categoria: 'Shampaña');

      expect(notifier.isChampagne(p1), true);
      expect(notifier.isChampagne(p2), true);
      notifier.dispose();
    });

    test('returns false for non-champagne categories', () {
      final notifier = _buildNotifier(Dio());
      final p = _makeProduct(categoria: 'Bebidas');

      expect(notifier.isChampagne(p), false);
      notifier.dispose();
    });
  });

  
  
  

  group('getMaxHostesses', () {
    test('returns 5 for champagne >= 240000', () {
      final notifier = _buildNotifier(Dio());
      final item = _makeCartItem(
        categoria: 'Champaña',
        price: 240000,
      );

      expect(notifier.getMaxHostesses(item), 5);
      notifier.dispose();
    });

    test('returns 4 for champagne >= 200000', () {
      final notifier = _buildNotifier(Dio());
      final item = _makeCartItem(
        categoria: 'Champaña',
        price: 200000,
      );

      expect(notifier.getMaxHostesses(item), 4);
      notifier.dispose();
    });

    test('returns 3 for champagne >= 140000', () {
      final notifier = _buildNotifier(Dio());
      final item = _makeCartItem(
        categoria: 'Champaña',
        price: 140000,
      );

      expect(notifier.getMaxHostesses(item), 3);
      notifier.dispose();
    });

    test('returns 2 for champagne >= 120000', () {
      final notifier = _buildNotifier(Dio());
      final item = _makeCartItem(
        categoria: 'Champaña',
        price: 120000,
      );

      expect(notifier.getMaxHostesses(item), 2);
      notifier.dispose();
    });

    test('returns 1 for champagne < 120000', () {
      final notifier = _buildNotifier(Dio());
      final item = _makeCartItem(
        categoria: 'Champaña',
        price: 119999,
      );

      expect(notifier.getMaxHostesses(item), 1);
      notifier.dispose();
    });

    test('returns quantity for non-champagne items', () {
      final notifier = _buildNotifier(Dio());
      final item = _makeCartItem(categoria: 'Bebidas');

      expect(notifier.getMaxHostesses(item), 1); 
      notifier.dispose();
    });
  });

  
  
  

  group('generateCode', () {
    test('returns 8-character code', () {
      final notifier = _buildNotifier(Dio());

      final code = notifier.generateCode();

      expect(code.length, 8);
      
      expect(code, matches(RegExp(r'^[A-Z0-9]{8}$')));
      notifier.dispose();
    });

    test('generates different codes on successive calls', () {
      final notifier = _buildNotifier(Dio());

      final code1 = notifier.generateCode();
      final code2 = notifier.generateCode();

      
      expect(code1, isNot(code2));
      notifier.dispose();
    });
  });

  
  
  

  group('validateOrder', () {
    test('returns error for empty cart', () {
      final notifier = _buildNotifier(Dio());

      final error = notifier.validateOrder([]);

      expect(error, isNotNull);
      expect(error, contains('vacío'));
      notifier.dispose();
    });

    test('returns null when all items have hostesses assigned', () {
      final notifier = _buildNotifier(Dio());
      final items = [
        _makeCartItem(
          id: 'p1',
          name: 'VIP Service',
          commission: 5000,
          hostesses: ['h1', 'h2'],
        ),
      ];

      expect(notifier.validateOrder(items), isNull);
      notifier.dispose();
    });

    test('returns error when commission item has no hostesses', () {
      final notifier = _buildNotifier(Dio());
      final items = [
        _makeCartItem(
          id: 'p1',
          name: 'VIP Service',
          commission: 5000,
          hostesses: [],
        ),
      ];

      final error = notifier.validateOrder(items);
      expect(error, isNotNull);
      expect(error, contains('VIP Service'));
      expect(error, contains('anfitriona'));
      notifier.dispose();
    });

    test('passes items without commission but no hostesses', () {
      final notifier = _buildNotifier(Dio());
      final items = [
        _makeCartItem(
          id: 'p1',
          name: 'Coca Cola',
          commission: 0,
          hostesses: [],
        ),
      ];

      expect(notifier.validateOrder(items), isNull);
      notifier.dispose();
    });

    test('validates all items, returning first error', () {
      final notifier = _buildNotifier(Dio());
      final items = [
        _makeCartItem(id: 'p1', name: 'Item OK', commission: 0, hostesses: []),
        _makeCartItem(
          id: 'p2',
          name: 'Bad Item',
          commission: 3000,
          hostesses: [],
        ),
        _makeCartItem(
          id: 'p3',
          name: 'Another Bad',
          commission: 2000,
          hostesses: [],
        ),
      ];

      final error = notifier.validateOrder(items);
      expect(error, isNotNull);
      expect(error, contains('Bad Item')); 
      notifier.dispose();
    });
  });

  
  
  

  group('submitOrder', () {
    test('returns true on success', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(routeToData: {
          '/orders': successResponse(),
        }),
      );

      final result = await notifier.submitOrder(
        meseroId: '1',
        codigo: 'TEST001',
        orderPayload: {'test': true},
      );

      expect(result, true);
      notifier.dispose();
    });

    test('returns false on API failure', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(routeToData: {
          '/orders': failResponse(),
        }),
      );

      final result = await notifier.submitOrder(
        meseroId: '1',
        codigo: 'TEST001',
        orderPayload: {'test': true},
      );

      expect(result, false);
      notifier.dispose();
    });

    test('returns false on DioException', () async {
      final notifier = _buildNotifier(_dioWithError());

      final result = await notifier.submitOrder(
        meseroId: '1',
        codigo: 'TEST001',
        orderPayload: {'test': true},
      );

      expect(result, false);
      notifier.dispose();
    });
  });
}


class FakeSecureStorage extends FlutterSecureStoragePlatform {
  final _store = <String, String>{};

  @override
  Future<String?> read(
      {required String key, Map<String, String>? options}) async {
    return _store[key];
  }

  @override
  Future<void> write(
      {required String key,
      required String value,
      Map<String, String>? options}) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(
      {required String key, Map<String, String>? options}) async {
    _store.remove(key);
  }

  @override
  Future<Map<String, String>> readAll(
      {Map<String, String>? options}) async {
    return Map.from(_store);
  }

  @override
  Future<bool> containsKey(
      {required String key, Map<String, String>? options}) async {
    return _store.containsKey(key);
  }

  @override
  Future<void> deleteAll({Map<String, String>? options}) async {
    _store.clear();
  }
}
