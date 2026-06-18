import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// Persistent queue of failed API requests stored in SharedPreferences.
///
/// Mirrors the AsyncStorage queue pattern in Expo's `offlineSync.ts`.
class OfflineQueue {
  static const _queueKey = 'offline_request_queue';

  /// Loads all queued requests from persistent storage.
  Future<List<QueuedRequest>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_queueKey);
    if (data == null || data.isEmpty) return [];

    final List<dynamic> jsonList = jsonDecode(data) as List<dynamic>;
    return jsonList
        .map((e) => QueuedRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Adds a request to the end of the queue.
  Future<void> add(QueuedRequest request) async {
    final queue = await getAll();
    queue.add(request);
    await _persist(queue);
  }

  /// Removes a single request by [id].
  Future<void> remove(String id) async {
    final queue = await getAll();
    queue.removeWhere((r) => r.id == id);
    await _persist(queue);
  }

  /// Replaces the entire queue with [requests] (used after a sync cycle).
  Future<void> replaceAll(List<QueuedRequest> requests) async {
    await _persist(requests);
  }

  /// Clears every queued request.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
  }

  /// Returns the number of pending requests.
  Future<int> getPendingCount() async {
    final queue = await getAll();
    return queue.length;
  }

  Future<void> _persist(List<QueuedRequest> queue) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(queue.map((r) => r.toJson()).toList());
    await prefs.setString(_queueKey, encoded);
  }
}
