class SseEvent {
  final String type;
  final Map<String, dynamic> data;

  SseEvent({
    required this.type,
    required this.data,
  });

  factory SseEvent.fromJson(Map<String, dynamic> json) {
    return SseEvent(
      type: json['type'] ?? '',
      data: json['data'] ?? {},
    );
  }

  @override
  String toString() => 'SseEvent(type: $type, data: $data)';
}
