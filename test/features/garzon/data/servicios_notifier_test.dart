import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

import 'package:lasmunecasderamon_flutter/core/api_client.dart';
import 'package:lasmunecasderamon_flutter/features/garzon/data/servicios_notifier.dart';



Dio _dioWithResponse({
  List<dynamic>? roomsData,
  List<dynamic>? hostessesData,
  List<dynamic>? clientsData,
  Map<String, dynamic>? postResponse,
  DioException? postError,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        
        if (options.path.contains('/rooms')) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: roomsData ?? [],
          ));
          return;
        }
        
        if (options.path.contains('/users')) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: hostessesData ?? [],
          ));
          return;
        }
        
        if (options.path.contains('/clients')) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: clientsData ?? [],
          ));
          return;
        }
        
        if (options.method == 'POST') {
          if (postError != null) {
            handler.reject(postError);
          } else {
            handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: postResponse ?? {'success': true},
            ));
          }
          return;
        }
        handler.reject(DioException(
          requestOptions: options,
          message: 'Unexpected request: ${options.path}',
        ));
      },
    ),
  );
  return dio;
}

ServiciosFormNotifier _createNotifier({
  List<dynamic>? roomsData,
  List<dynamic>? hostessesData,
  List<dynamic>? clientsData,
  Map<String, dynamic>? postResponse,
  DioException? postError,
}) {
  return ServiciosFormNotifier(ApiClient(dio: _dioWithResponse(
    roomsData: roomsData,
    hostessesData: hostessesData,
    clientsData: clientsData,
    postResponse: postResponse,
    postError: postError,
  )));
}



const _roomJson = {
  'id': 'r1',
  'nombre': 'Habitación 1',
  'precio': '5000',
  'comision_anfitriona': '0',
  'tiempo': '60',
};

const _roomWithComisionJson = {
  'id': 'r2',
  'nombre': 'VIP',
  'precio': '15000',
  'comision_anfitriona': '2000',
  'tiempo': '60',
};

const _inactiveRoomJson = {
  'id': 'r3',
  'nombre': 'Mantenimiento',
  'precio': '0',
  'comision_anfitriona': '0',
  'tiempo': '60',
};

const _hostessJson = {
  'id': 'h1',
  'nombre': 'María',
  'avatar': null,
};

const _clientJson = {
  'id': 'c1',
  'nombre': 'Juan Pérez',
  'saldo': '0',
};

const _clientWithBalanceJson = {
  'id': 'c2',
  'nombre': 'Pedro García',
  'saldo': '25000',
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStoragePlatform.instance = FakeSecureStorage();
  });

  group('ServiciosFormNotifier', () {
    
    
    

    test('initial state has defaults', () {
      final notifier = _createNotifier();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.isSubmitting, isFalse);
      expect(notifier.state.error, isNull);
      expect(notifier.state.rooms, isEmpty);
      expect(notifier.state.selectedRoom, isNull);
      expect(notifier.state.selectedHostesses, isEmpty);
      expect(notifier.state.paymentMethod, isEmpty);
      expect(notifier.state.submitSuccess, isNull);
    });

    
    
    

    test('fetchFormData loads rooms, hostesses and clients', () async {
      final notifier = _createNotifier(
        roomsData: [_roomJson, _roomWithComisionJson, _inactiveRoomJson],
        hostessesData: [_hostessJson],
        clientsData: [_clientJson],
      );

      expect(notifier.state.isLoading, isFalse);

      await notifier.fetchFormData();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);

      
      expect(notifier.state.rooms.length, 2);
      expect(notifier.state.rooms[0].name, 'Habitación 1');
      expect(notifier.state.rooms[1].name, 'VIP');

      expect(notifier.state.anfitrionas.length, 1);
      expect(notifier.state.anfitrionas[0].name, 'María');

      expect(notifier.state.clients.length, 1);
      expect(notifier.state.clients[0].name, 'Juan Pérez');
    });

    test('fetchFormData sets error on failure', () async {
      final failingDio = Dio(BaseOptions(baseUrl: 'http://test'));
      failingDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(DioException(
              requestOptions: options,
              message: 'Network error',
            ));
          },
        ),
      );
      final notifier = ServiciosFormNotifier(ApiClient(dio: failingDio));

      await notifier.fetchFormData();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, contains('Error al cargar'));
    });

    
    
    

    test('selectRoom resets hostesses, clients and payment method', () async {
      final notifier = _createNotifier(
        roomsData: [_roomJson],
        hostessesData: [_hostessJson],
        clientsData: [_clientJson, _clientWithBalanceJson],
      );
      await notifier.fetchFormData();

      
      notifier.toggleClient(notifier.state.clients[0]);
      expect(notifier.state.selectedClients, isNotEmpty);

      
      notifier.toggleHostess(notifier.state.anfitrionas[0]);
      expect(notifier.state.selectedHostesses, isNotEmpty);

      
      notifier.setPaymentMethod('efectivo');

      
      notifier.selectRoom(notifier.state.rooms[0]);

      expect(notifier.state.selectedRoom, isNotNull);
      expect(notifier.state.selectedRoom!.name, 'Habitación 1');
      
      expect(notifier.state.selectedHostesses, isEmpty);
      expect(notifier.state.selectedClients, isEmpty);
      expect(notifier.state.paymentMethod, isEmpty);
    });

    
    
    

    test('hasComision returns true for rooms with commission', () async {
      final notifier = _createNotifier(
        roomsData: [_roomWithComisionJson],
        hostessesData: [_hostessJson],
        clientsData: [_clientJson],
      );
      await notifier.fetchFormData();

      expect(notifier.state.hasComision, isFalse);

      notifier.selectRoom(notifier.state.rooms[0]); 
      expect(notifier.state.hasComision, isTrue);
      expect(notifier.state.selectedRoom!.comisionAnfitriona, 2000);
    });

    
    
    

    test('toggleHostess enforces max limit for commission rooms', () async {
      final notifier = _createNotifier(
        roomsData: [_roomWithComisionJson],
        hostessesData: [
          {'id': 'h1', 'nombre': 'A'},
          {'id': 'h2', 'nombre': 'B'},
          {'id': 'h3', 'nombre': 'C'},
          {'id': 'h4', 'nombre': 'D'},
        ],
        clientsData: [_clientJson],
      );
      await notifier.fetchFormData();
      notifier.selectRoom(notifier.state.rooms[0]); 

      
      notifier.toggleHostess(notifier.state.anfitrionas[0]); 
      notifier.toggleHostess(notifier.state.anfitrionas[1]); 
      notifier.toggleHostess(notifier.state.anfitrionas[2]); 
      expect(notifier.state.selectedHostesses.length, 3);

      
      notifier.toggleHostess(notifier.state.anfitrionas[3]); 
      expect(notifier.state.selectedHostesses.length, 3);
      expect(notifier.state.selectedHostesses[0].name, 'B'); 
      expect(notifier.state.selectedHostesses[2].name, 'D');
    });

    test('toggleHostess removes when already selected', () async {
      final notifier = _createNotifier(
        roomsData: [_roomJson],
        hostessesData: [_hostessJson],
        clientsData: [_clientJson],
      );
      await notifier.fetchFormData();
      notifier.selectRoom(notifier.state.rooms[0]);

      notifier.toggleHostess(notifier.state.anfitrionas[0]);
      expect(notifier.state.selectedHostesses.length, 1);

      notifier.toggleHostess(notifier.state.anfitrionas[0]);
      expect(notifier.state.selectedHostesses, isEmpty);
    });

    
    
    

    test('toggleClient auto-forces prepago when client has balance', () async {
      final notifier = _createNotifier(
        roomsData: [_roomJson],
        hostessesData: [_hostessJson],
        clientsData: [_clientJson, _clientWithBalanceJson],
      );
      await notifier.fetchFormData();
      notifier.selectRoom(notifier.state.rooms[0]);

      notifier.toggleClient(notifier.state.clients[0]); 
      expect(notifier.state.paymentMethod, isEmpty);

      notifier.toggleClient(notifier.state.clients[1]); 
      expect(notifier.state.paymentMethod, 'prepago');

      
      notifier.toggleClient(notifier.state.clients[1]);
      expect(notifier.state.selectedClients.length, 1);
      expect(notifier.state.paymentMethod, isEmpty); 
    });

    
    
    

    test('totals returns zeros when no room selected', () {
      final notifier = _createNotifier();
      final totals = notifier.state.totals;

      expect(totals['total'], 0);
      expect(totals['subtotal'], 0);
      expect(totals['roomPrice'], 0);
    });

    test('totals calculates commission-based pricing', () async {
      final notifier = _createNotifier(
        roomsData: [_roomWithComisionJson],
        hostessesData: [_hostessJson,
          {'id': 'h2', 'nombre': 'B'},
        ],
        clientsData: [_clientJson],
      );
      await notifier.fetchFormData();
      notifier.selectRoom(notifier.state.rooms[0]); 
      notifier.toggleHostess(notifier.state.anfitrionas[0]); 
      notifier.toggleHostess(notifier.state.anfitrionas[1]); 

      final totals = notifier.state.totals;
      
      
      expect(totals['subtotal'], 4000);
      expect(totals['roomPrice'], 15000);
      expect(totals['comision'], 4000);
      expect(totals['total'], 19000);
    });

    test('totals calculates manual pricing with card payment', () async {
      final notifier = _createNotifier(
        roomsData: [_roomJson],
        hostessesData: [_hostessJson, {'id': 'h2', 'nombre': 'B'}],
        clientsData: [_clientJson, _clientWithBalanceJson],
      );
      await notifier.fetchFormData();
      notifier.selectRoom(notifier.state.rooms[0]); 
      notifier.toggleHostess(notifier.state.anfitrionas[0]);
      notifier.toggleHostess(notifier.state.anfitrionas[1]);
      notifier.toggleClient(notifier.state.clients[0]);
      notifier.setManualPrice(10000);
      notifier.setPaymentMethod('tarjeta');

      final totals = notifier.state.totals;
      
      
      
      
      expect(totals['subtotal'], 20000);
      expect(totals['roomPrice'], 5000);
      expect(totals['iva'], 5000); 
      expect(totals['total'], 30000);
    });

    
    
    

    test('validate returns null when form is complete', () async {
      final notifier = _createNotifier(
        roomsData: [_roomJson],
        hostessesData: [_hostessJson],
        clientsData: [_clientJson],
      );
      await notifier.fetchFormData();
      notifier.selectRoom(notifier.state.rooms[0]);
      notifier.toggleHostess(notifier.state.anfitrionas[0]);
      notifier.setPaymentMethod('efectivo');

      expect(notifier.validate(), isNull);
    });

    test('validate returns error when room is missing', () {
      final notifier = _createNotifier();

      expect(notifier.validate(), contains('habitación'));
    });

    test('validate returns error when no hostesses', () async {
      final notifier = _createNotifier(
        roomsData: [_roomJson],
        hostessesData: [_hostessJson],
        clientsData: [_clientJson],
      );
      await notifier.fetchFormData();
      notifier.selectRoom(notifier.state.rooms[0]);

      expect(notifier.validate(), contains('anfitriona'));
    });

    test('validate returns error when no payment method', () async {
      final notifier = _createNotifier(
        roomsData: [_roomJson],
        hostessesData: [_hostessJson],
        clientsData: [_clientJson],
      );
      await notifier.fetchFormData();
      notifier.selectRoom(notifier.state.rooms[0]);
      notifier.toggleHostess(notifier.state.anfitrionas[0]);

      expect(notifier.validate(), contains('método de pago'));
    });

    
    
    

    test('submitService calls API and returns success', () async {
      final notifier = _createNotifier(
        roomsData: [_roomJson],
        hostessesData: [_hostessJson],
        clientsData: [_clientJson],
        postResponse: {'success': true},
      );
      await notifier.fetchFormData();
      notifier.selectRoom(notifier.state.rooms[0]);
      notifier.toggleHostess(notifier.state.anfitrionas[0]);
      notifier.setPaymentMethod('efectivo');

      final result = await notifier.submitService();

      expect(result, isTrue);
      expect(notifier.state.isSubmitting, isFalse);
      expect(notifier.state.submitSuccess, isTrue);
    });

    test('submitService returns false when validation fails', () async {
      final notifier = _createNotifier();

      final result = await notifier.submitService();

      expect(result, isFalse);
      expect(notifier.state.error, isNotNull);
    });

    test('submitService returns false on API error', () async {
      final notifier = _createNotifier(
        roomsData: [_roomJson],
        hostessesData: [_hostessJson],
        clientsData: [_clientJson],
        postError: DioException(
          requestOptions: RequestOptions(path: '/solicitudes-servicios'),
          message: 'Server error',
        ),
      );
      await notifier.fetchFormData();
      notifier.selectRoom(notifier.state.rooms[0]);
      notifier.toggleHostess(notifier.state.anfitrionas[0]);
      notifier.setPaymentMethod('efectivo');

      final result = await notifier.submitService();

      expect(result, isFalse);
      expect(notifier.state.error, contains('Error al registrar'));
    });

    
    
    

    test('resetForm clears all state', () async {
      final notifier = _createNotifier(
        roomsData: [_roomJson],
        hostessesData: [_hostessJson],
        clientsData: [_clientJson],
      );
      await notifier.fetchFormData();
      notifier.selectRoom(notifier.state.rooms[0]);
      notifier.toggleHostess(notifier.state.anfitrionas[0]);

      notifier.resetForm();

      expect(notifier.state.rooms, isEmpty);
      expect(notifier.state.selectedHostesses, isEmpty);
      expect(notifier.state.selectedRoom, isNull);
    });

    test('clearError clears error without affecting other state', () {
      final notifier = _createNotifier();
      
      notifier.submitService(); 

      expect(notifier.state.error, isNotNull);

      notifier.clearError();
      expect(notifier.state.error, isNull);
    });
  });
}


class FakeSecureStorage extends FlutterSecureStoragePlatform {
  final _store = <String, String>{};

  @override
  Future<String?> read({required String key, Map<String, String>? options}) async => _store[key];

  @override
  Future<void> write({required String key, required String value, Map<String, String>? options}) async => _store[key] = value;

  @override
  Future<void> delete({required String key, Map<String, String>? options}) async => _store.remove(key);

  @override
  Future<Map<String, String>> readAll({Map<String, String>? options}) async => Map.from(_store);

  @override
  Future<bool> containsKey({required String key, Map<String, String>? options}) async => _store.containsKey(key);

  @override
  Future<void> deleteAll({Map<String, String>? options}) async => _store.clear();
}
