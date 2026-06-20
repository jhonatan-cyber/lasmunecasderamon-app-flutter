import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SseConnectionStatus { connected, disconnected, reconnecting }

final sseConnectionStatusProvider = StateProvider<SseConnectionStatus>((ref) {
  return SseConnectionStatus.connected;
});
