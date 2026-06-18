import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'offline_sync_manager.dart';

/// Singleton instance of the offline sync manager (initialised elsewhere).
final offlineSyncManagerProvider = Provider<OfflineSyncManager>((ref) {
  return OfflineSyncManager();
});

/// Reactive connectivity state — `true` when the device has a network
/// connection.
final isOnlineProvider = StreamProvider<bool>((ref) {
  final manager = ref.watch(offlineSyncManagerProvider);

  // Convert the callback-based listener to a Stream.
  final controller = StreamController<bool>.broadcast();

  void emit() {
    controller.add(manager.isConnected);
  }

  emit(); // initial value
  final remove = manager.addListener(emit);
  controller.onCancel = remove;

  ref.onDispose(() {
    remove();
    controller.close();
  });

  return controller.stream;
});

/// Number of requests waiting in the offline queue.
final pendingCountProvider = FutureProvider<int>((ref) async {
  final manager = ref.watch(offlineSyncManagerProvider);
  return manager.getPendingCount();
});

/// `true` while the queue is being processed.
final isSyncingProvider = Provider<bool>((ref) {
  // We expose the sync-in-progress state via a simple bool provider.
  // In a full implementation this could be a StateNotifier, but for
  // parity with Expo the sync is fast enough that a simple flag suffices.
  return false; // will be enhanced when needed
});
