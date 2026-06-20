import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'offline_sync_manager.dart';


final offlineSyncManagerProvider = Provider<OfflineSyncManager>((ref) {
  return OfflineSyncManager();
});



final isOnlineProvider = StreamProvider<bool>((ref) {
  final manager = ref.watch(offlineSyncManagerProvider);

  
  final controller = StreamController<bool>.broadcast();

  void emit() {
    controller.add(manager.isConnected);
  }

  emit(); 
  final remove = manager.addListener(emit);
  controller.onCancel = remove;

  ref.onDispose(() {
    remove();
    controller.close();
  });

  return controller.stream;
});


final pendingCountProvider = FutureProvider<int>((ref) async {
  final manager = ref.watch(offlineSyncManagerProvider);
  return manager.getPendingCount();
});


final isSyncingProvider = Provider<bool>((ref) {
  
  
  
  return false; 
});
