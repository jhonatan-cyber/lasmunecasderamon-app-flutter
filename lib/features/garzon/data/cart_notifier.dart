import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/product.dart';

class CartItem {
  final Product product;
  final int quantity;
  final List<String> selectedHostesses;
  final String? selectedRoom;

  CartItem({
    required this.product,
    required this.quantity,
    this.selectedHostesses = const [],
    this.selectedRoom,
  });

  CartItem copyWith({
    Product? product,
    int? quantity,
    List<String>? selectedHostesses,
    String? selectedRoom,
    bool clearRoom = false,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      selectedHostesses: selectedHostesses ?? this.selectedHostesses,
      selectedRoom: clearRoom ? null : (selectedRoom ?? this.selectedRoom),
    );
  }
}

class CartState {
  final List<CartItem> items;
  final bool tipEnabled;
  final String? selectedClientId;

  CartState({
    this.items = const [],
    this.tipEnabled = false,
    this.selectedClientId,
  });

  CartState copyWith({
    List<CartItem>? items,
    bool? tipEnabled,
    String? selectedClientId,
    bool clearClient = false,
  }) {
    return CartState(
      items: items ?? this.items,
      tipEnabled: tipEnabled ?? this.tipEnabled,
      selectedClientId: clearClient ? null : (selectedClientId ?? this.selectedClientId),
    );
  }
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(CartState());

  void addToCart(Product product) {
    final idx = state.items.indexWhere((i) => i.product.id == product.id);
    if (idx >= 0) {
      final updated = [...state.items];
      updated[idx] = updated[idx].copyWith(quantity: updated[idx].quantity + 1);
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(
        items: [
          ...state.items,
          CartItem(
            product: product,
            quantity: 1,
            selectedHostesses: const [],
            selectedRoom: null,
          ),
        ],
      );
    }
  }

  void removeFromCart(String productId) {
    final idx = state.items.indexWhere((i) => i.product.id == productId);
    if (idx < 0) return;

    final updated = [...state.items];
    if (updated[idx].quantity > 1) {
      updated[idx] = updated[idx].copyWith(quantity: updated[idx].quantity - 1);
      state = state.copyWith(items: updated);
    } else {
      updated.removeAt(idx);
      state = state.copyWith(items: updated);
    }
  }

  void updateItemHostesses(String productId, List<String> hostessIds) {
    state = state.copyWith(
      items: state.items.map((i) {
        if (i.product.id == productId) {
          return i.copyWith(selectedHostesses: hostessIds);
        }
        return i;
      }).toList(),
    );
  }

  void updateItemRoom(String productId, String? roomId) {
    state = state.copyWith(
      items: state.items.map((i) {
        if (i.product.id == productId) {
          return i.copyWith(
            selectedRoom: roomId,
            clearRoom: roomId == null,
          );
        }
        return i;
      }).toList(),
    );
  }

  void setTipEnabled(bool enabled) {
    state = state.copyWith(tipEnabled: enabled);
  }

  void setSelectedClient(String? clientId) {
    if (clientId == null) {
      state = state.copyWith(clearClient: true);
    } else {
      state = state.copyWith(selectedClientId: clientId);
    }
  }

  void clearCart() {
    state = CartState();
  }

  double getSubtotal() {
    return state.items.fold(0.0, (sum, item) => sum + (item.product.price * item.quantity));
  }

  double getTipAmount() {
    final subtotal = getSubtotal();
    return state.tipEnabled ? subtotal * 0.1 : 0.0;
  }

  double getTotal() {
    return getSubtotal() + getTipAmount();
  }

  Map<String, dynamic> buildOrderPayload({
    required String meseroId,
    required String codigo,
    String? deviceDate,
  }) {
    final subtotal = getSubtotal();
    final tipAmount = getTipAmount();
    final total = getTotal();
    final totalComision = state.items.fold(
      0.0,
      (sum, item) => sum + ((item.product.commission) * item.quantity),
    );

    
    final allHostessIds = state.items
        .flatMap((i) => i.selectedHostesses)
        .toSet()
        .toList();

    return {
      'codigo': codigo,
      'meseroId': meseroId,
      'clienteId': state.selectedClientId,
      'subtotal': subtotal,
      'total': total,
      'propina': tipAmount,
      'totalComision': totalComision,
      'device_date': deviceDate ?? DateTime.now().toIso8601String(),
      'detalles': state.items.map((item) {
        return {
          'productoId': item.product.id,
          'precio': item.product.price,
          'comision': item.product.commission,
          'cantidad': item.quantity,
          'subtotal': item.product.price * item.quantity,
          'generaComision': item.product.commission > 0 ? 1 : 0,
          'hostessId': item.selectedHostesses.length == 1 ? item.selectedHostesses.first : null,
          'selectedHostesses': item.selectedHostesses,
          'roomId': item.selectedRoom,
        };
      }).toList(),
      'usuarios': allHostessIds.map((id) => {'usuarioId': id}).toList(),
    };
  }
}


extension _IterableFlatMap<T> on Iterable<T> {
  Iterable<R> flatMap<R>(Iterable<R> Function(T) transform) {
    return map(transform).expand((element) => element);
  }
}


final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});
