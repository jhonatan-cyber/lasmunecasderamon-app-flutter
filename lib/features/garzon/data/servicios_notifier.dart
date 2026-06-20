import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../../auth/data/auth_notifier.dart';





class Room {
  final String id;
  final String name;
  final double basePrice;
  final double comisionAnfitriona;
  final int baseTime;

  Room({
    required this.id,
    required this.name,
    required this.basePrice,
    required this.comisionAnfitriona,
    required this.baseTime,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id']?.toString() ?? '',
      name: json['nombre'] ?? json['name'] ?? '',
      basePrice: double.tryParse(json['precio']?.toString() ?? '0') ?? 0.0,
      comisionAnfitriona:
          double.tryParse(json['comision_anfitriona']?.toString() ?? '0') ??
          0.0,
      baseTime: int.tryParse(json['tiempo']?.toString() ?? '30') ?? 30,
    );
  }
}

class Anfitriona {
  final String id;
  final String name;
  final String? photo;

  Anfitriona({required this.id, required this.name, this.photo});

  factory Anfitriona.fromJson(Map<String, dynamic> json) {
    return Anfitriona(
      id: json['id']?.toString() ?? '',
      name: json['nombre'] ?? json['name'] ?? '',
      photo: json['avatar'] ?? json['photo'],
    );
  }
}

class Client {
  final String id;
  final String name;
  final double saldo;

  Client({required this.id, required this.name, required this.saldo});

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id']?.toString() ?? json['id_cliente']?.toString() ?? '',
      name: json['nombre'] ?? json['name'] ?? '',
      saldo: double.tryParse(json['saldo']?.toString() ?? '0') ?? 0.0,
    );
  }
}





class ServiciosFormState {
  final bool isLoading;
  final bool isSubmitting;
  final String? error;
  final List<Room> rooms;
  final List<Anfitriona> anfitrionas;
  final List<Client> clients;
  final Room? selectedRoom;
  final List<Anfitriona> selectedHostesses;
  final List<Client> selectedClients;
  final String paymentMethod; 
  final double manualPrice;
  final bool? submitSuccess;

  ServiciosFormState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
    this.rooms = const [],
    this.anfitrionas = const [],
    this.clients = const [],
    this.selectedRoom,
    this.selectedHostesses = const [],
    this.selectedClients = const [],
    this.paymentMethod = '',
    this.manualPrice = 0,
    this.submitSuccess,
  });

  ServiciosFormState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    List<Room>? rooms,
    List<Anfitriona>? anfitrionas,
    List<Client>? clients,
    Room? selectedRoom,
    List<Anfitriona>? selectedHostesses,
    List<Client>? selectedClients,
    String? paymentMethod,
    double? manualPrice,
    bool? submitSuccess,
    bool clearError = false,
    bool clearSubmitSuccess = false,
  }) {
    return ServiciosFormState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      rooms: rooms ?? this.rooms,
      anfitrionas: anfitrionas ?? this.anfitrionas,
      clients: clients ?? this.clients,
      selectedRoom: selectedRoom ?? this.selectedRoom,
      selectedHostesses: selectedHostesses ?? this.selectedHostesses,
      selectedClients: selectedClients ?? this.selectedClients,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      manualPrice: manualPrice ?? this.manualPrice,
      submitSuccess: clearSubmitSuccess ? null : (submitSuccess ?? this.submitSuccess),
    );
  }

  

  bool get hasComision =>
      selectedRoom != null && selectedRoom!.comisionAnfitriona > 0;

  int get maxHostessesLimit {
    if (selectedRoom == null) return 100;
    if (hasComision) {
      final clientCount = selectedClients.length;
      return min(3, max(1, 4 - clientCount));
    }
    return 100;
  }

  int get maxClientsLimit {
    if (selectedRoom == null) return 100;
    if (hasComision) {
      final hostessCount = selectedHostesses.length;
      return max(1, 4 - hostessCount);
    }
    return 100;
  }

  Map<String, double> get totals => _calculateTotals();

  Map<String, double> _calculateTotals() {
    if (selectedRoom == null) {
      return {
        'subtotal': 0,
        'roomPrice': 0,
        'comision': 0,
        'iva': 0,
        'total': 0,
      };
    }

    final baseRoomPrice = selectedRoom!.basePrice;
    final comisionUnit = selectedRoom!.comisionAnfitriona;
    final hostessesCount = selectedHostesses.length;
    final clientsCount = selectedClients.length;

    double subtotal = 0;
    double total = 0;
    double iva = 0;

    if (hasComision) {
      subtotal = comisionUnit * hostessesCount;
      total = baseRoomPrice + subtotal;
    } else {
      final multiplier = max(hostessesCount, clientsCount);
      subtotal = manualPrice * max(1, multiplier);
      total = subtotal + baseRoomPrice;
    }

    if (paymentMethod == 'tarjeta') {
      iva = subtotal * 0.20;
      total += iva;

      if (!hasComision) {
        final roundedTotal = (total / 5000).ceil() * 5000.0;
        final diff = roundedTotal - total;
        iva += diff;
        total = roundedTotal;
      }
    }

    return {
      'subtotal': subtotal,
      'roomPrice': baseRoomPrice,
      'comision': comisionUnit * hostessesCount,
      'iva': iva,
      'total': total,
    };
  }
}





class ServiciosFormNotifier extends StateNotifier<ServiciosFormState> {
  final ApiClient _apiClient;

  ServiciosFormNotifier(this._apiClient) : super(ServiciosFormState());

  

  Future<void> fetchFormData() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final responses = await Future.wait([
        _apiClient.dio.get('/rooms'),
        _apiClient.dio.get('/users?anfitrionas=1'),
        _apiClient.dio.get('/clients'),
      ]);

      final roomsData = responses[0].data;
      final hostessesData = responses[1].data;
      final clientsData = responses[2].data;

      final List<Room> loadedRooms = [];
      if (roomsData is List) {
        for (var item in roomsData) {
          final r = Room.fromJson(item);
          if (r.basePrice > 0 && r.baseTime > 0) loadedRooms.add(r);
        }
      }

      final List<Anfitriona> loadedHostesses = [];
      if (hostessesData is List) {
        for (var item in hostessesData) {
          loadedHostesses.add(Anfitriona.fromJson(item));
        }
      }

      final List<Client> loadedClients = [];
      if (clientsData is List) {
        for (var item in clientsData) {
          loadedClients.add(Client.fromJson(item));
        }
      }

      state = state.copyWith(
        isLoading: false,
        rooms: loadedRooms,
        anfitrionas: loadedHostesses,
        clients: loadedClients,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cargar los datos del formulario: $e',
      );
    }
  }

  

  void selectRoom(Room? room) {
    state = state.copyWith(
      selectedRoom: room,
      selectedHostesses: [],
      selectedClients: [],
      paymentMethod: '',
    );
  }

  void toggleHostess(Anfitriona hostess) {
    final current = [...state.selectedHostesses];
    final exists = current.any((h) => h.id == hostess.id);

    if (exists) {
      current.removeWhere((h) => h.id == hostess.id);
    } else {
      if (current.length >= state.maxHostessesLimit) {
        current.removeAt(0);
      }
      current.add(hostess);
    }

    state = state.copyWith(selectedHostesses: current);
  }

  void toggleClient(Client client) {
    final current = [...state.selectedClients];
    final exists = current.any((c) => c.id == client.id);

    if (exists) {
      current.removeWhere((c) => c.id == client.id);
    } else {
      if (current.length >= state.maxClientsLimit) {
        current.removeAt(0);
      }
      current.add(client);
    }

    
    final hasBalance = current.any((c) => c.saldo > 0);
    final newPaymentMethod = hasBalance
        ? 'prepago'
        : state.paymentMethod == 'prepago'
            ? ''
            : state.paymentMethod;

    state = state.copyWith(
      selectedClients: current,
      paymentMethod: newPaymentMethod,
    );
  }

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setManualPrice(double price) {
    state = state.copyWith(manualPrice: price);
  }

  

  String? validate() {
    if (state.selectedRoom == null) return 'Por favor, selecciona una habitación.';
    if (state.selectedHostesses.isEmpty) return 'Por favor, asocia al menos una anfitriona.';
    if (state.paymentMethod.isEmpty) return 'Por favor, selecciona un método de pago.';
    return null;
  }

  Future<bool> submitService() async {
    final validationError = validate();
    if (validationError != null) {
      state = state.copyWith(error: validationError);
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    final totals = state.totals;

    final payload = {
      'codigo': _generateRandomCode(),
      'cliente_id': state.selectedClients.isNotEmpty
          ? state.selectedClients.first.id
          : null,
      'clientes': state.selectedClients.map((c) => c.id).toList(),
      'habitacion_id': state.selectedRoom!.id,
      'precio_servicio': state.hasComision ? 0 : state.manualPrice,
      'precio_habitacion': state.selectedRoom!.basePrice,
      'comision_anfitriona': state.selectedRoom!.comisionAnfitriona,
      'usuarios': state.selectedHostesses.map((h) => h.id).toList(),
      'anfitrionas_ids': state.selectedHostesses.map((h) => h.id).toList(),
      'metodo_pago': state.paymentMethod,
      'tiempo': state.selectedRoom!.baseTime,
      'total': totals['total'],
      'iva': totals['iva'],
      'num_clientes': state.selectedClients.length,
    };

    try {
      await _apiClient.dio.post('/solicitudes-servicios', data: payload);
      state = state.copyWith(isSubmitting: false, submitSuccess: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'Error al registrar servicio: $e',
      );
      return false;
    }
  }

  

  String _generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  void resetForm() {
    state = ServiciosFormState();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}





final serviciosFormProvider =
    StateNotifierProvider.autoDispose<ServiciosFormNotifier, ServiciosFormState>(
  (ref) {
    final apiClient = ref.watch(apiClientProvider);
    return ServiciosFormNotifier(apiClient);
  },
);
