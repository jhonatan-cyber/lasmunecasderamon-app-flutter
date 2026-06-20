import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';




class OfflineQueue {
  static const _queueKey = 'offline_request_queue';

  
  Future<List<QueuedRequest>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_queueKey);
    if (data == null || data.isEmpty) return [];

    final List<dynamic> jsonList = jsonDecode(data) as List<dynamic>;
    return jsonList
        .map((e) => QueuedRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  
  Future<void> add(QueuedRequest request) async {
    final queue = await getAll();
    queue.add(request);
    await _persist(queue);
  }

  
  Future<void> remove(String id) async {
    final queue = await getAll();
    queue.removeWhere((r) => r.id == id);
    await _persist(queue);
  }

  
  Future<void> replaceAll(List<QueuedRequest> requests) async {
    await _persist(requests);
  }

  
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
  }

  
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
