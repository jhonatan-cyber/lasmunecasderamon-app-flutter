/// Represents an API request queued for later replay when connectivity is restored.
///
/// Mirrors the `QueuedRequest` interface in the Expo app's `offlineSync.ts`.
class QueuedRequest {
  final String id;
  final String endpoint;
  final String method;
  final Map<String, dynamic>? body;
  final DateTime timestamp;
  int retries;

  QueuedRequest({
    required this.id,
    required this.endpoint,
    required this.method,
    this.body,
    DateTime? timestamp,
    this.retries = 0,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'endpoint': endpoint,
        'method': method,
        'body': body,
        'timestamp': timestamp.toIso8601String(),
        'retries': retries,
      };

  factory QueuedRequest.fromJson(Map<String, dynamic> json) => QueuedRequest(
        id: json['id'] as String,
        endpoint: json['endpoint'] as String,
        method: json['method'] as String,
        body: json['body'] as Map<String, dynamic>?,
        timestamp: DateTime.parse(json['timestamp'] as String),
        retries: json['retries'] as int? ?? 0,
      );

  @override
  String toString() => 'QueuedRequest($method $endpoint, retries: $retries)';
}
