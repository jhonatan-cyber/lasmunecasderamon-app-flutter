import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../logger.dart';
import 'models.dart';
import 'offline_queue.dart';

/// Singleton that monitors connectivity and replays queued requests when the
/// device comes back online.
///
/// Mirrors the `OfflineSyncManager` class in Expo's `offlineSync.ts`.
class OfflineSyncManager {
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------
  static OfflineSyncManager? _instance;

  OfflineSyncManager._();
  factory OfflineSyncManager() {
    _instance ??= OfflineSyncManager._();
    return _instance!;
  }

  /// Resets the singleton (used in tests).
  @visibleForTesting
  static void reset() => _instance = null;

  // ---------------------------------------------------------------------------
  // Dependencies (injected after construction)
  // ---------------------------------------------------------------------------
  late final Dio _dio;
  final OfflineQueue _queue = OfflineQueue();
  final Connectivity _connectivity = Connectivity();

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------
  bool _isOnline = true;
  bool _syncInProgress = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  final Set<void Function()> _listeners = {};

  bool _initialised = false;

  /// Initialise the manager with a [Dio] instance used to replay queued
  /// requests, and start listening for connectivity changes.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  void init({required Dio dio}) {
    if (_initialised) return;
    _initialised = true;
    _dio = dio;
    _initConnectivityListener();
  }

  /// Tears down the connectivity listener.
  void dispose() {
    _connectivitySub?.cancel();
    _listeners.clear();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Current connectivity state.
  bool get isConnected => _isOnline;

  /// Register a callback that fires whenever connectivity or sync state
  /// changes. Returns a tear-off function to unregister.
  VoidCallback addListener(void Function() callback) {
    _listeners.add(callback);
    return () => _listeners.remove(callback);
  }

  /// Queues a failed request from [options] for later replay.
  void queueRequestFromOptions(RequestOptions options) {
    final request = QueuedRequest(
      id: _generateId(),
      endpoint: options.path,
      method: options.method.toUpperCase(),
      body: options.data is Map<String, dynamic>
          ? options.data as Map<String, dynamic>
          : null,
    );

    _queue.add(request);
    _notifyListeners();

    Logger.warn('OfflineSync: queued $request');

    // If we happen to be back online by now, try syncing immediately.
    if (_isOnline) {
      triggerSync();
    }
  }

  /// Returns the number of requests waiting to be replayed.
  Future<int> getPendingCount() => _queue.getPendingCount();

  /// Forces a sync cycle (called externally or on reconnect).
  @visibleForTesting
  Future<void> triggerSync() async {
    if (!_isOnline || _syncInProgress) return;

    _syncInProgress = true;
    _notifyListeners();

    try {
      final queue = await _queue.getAll();
      if (queue.isEmpty) {
        return;
      }

      int successCount = 0;
      final List<QueuedRequest> failed = [];

      for (final req in queue) {
        try {
          await _replay(req);
          successCount++;
        } catch (e) {
          if (req.retries < 3) {
            req.retries++;
            failed.add(req);
          } else {
            Logger.error('OfflineSync: giving up on $req after 3 retries');
          }
        }
      }

      await _queue.replaceAll(failed);

      Logger.info(
        'OfflineSync: synced $successCount, ${failed.length} remaining',
      );
    } catch (e, st) {
      Logger.captureException(
        e,
        hint: 'OfflineSync:triggerSync',
        stackTrace: st,
      );
    } finally {
      _syncInProgress = false;
      _notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _initConnectivityListener() {
    // Check initial state
    _connectivity.checkConnectivity().then((results) {
      _isOnline = !results.contains(ConnectivityResult.none);
      _notifyListeners();
    });

    // Listen for changes
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final wasOffline = !_isOnline;
      _isOnline = !results.contains(ConnectivityResult.none);

      if (wasOffline && _isOnline) {
        Logger.info('OfflineSync: connection restored — triggering sync');
        triggerSync();
      }

      _notifyListeners();
    });
  }

  Future<void> _replay(QueuedRequest request) async {
    final response = await _dio.request(
      request.endpoint,
      data: request.body,
      options: Options(method: request.method),
    );

    if (response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300) {
      return; // success
    }

    throw Exception('Replay returned ${response.statusCode}');
  }

  void _notifyListeners() {
    for (final cb in _listeners) {
      cb();
    }
  }

  String _generateId() {
    // Short random ID like Expo's Math.random().toString(36).substr(2, 9)
    return DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  }
}
