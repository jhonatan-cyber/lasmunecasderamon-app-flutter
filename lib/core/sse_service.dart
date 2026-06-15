import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/data/auth_notifier.dart';
import 'api_client.dart';
import 'sse_event.dart';

class SseService {
  final String _token;
  final _controller = StreamController<SseEvent>.broadcast();
  HttpClient? _client;
  HttpClientRequest? _request;
  HttpClientResponse? _response;
  bool _isClosed = false;
  Timer? _reconnectTimer;

  SseService(this._token) {
    _connect();
  }

  Stream<SseEvent> get stream => _controller.stream;

  void _connect() async {
    if (_isClosed) return;

    try {
      _client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      
      final url = Uri.parse('${ApiClient.baseUrl}/notifications/sse');
      _request = await _client!.getUrl(url);
      
      // SSE Headers
      _request!.headers.add('Authorization', 'Bearer $_token');
      _request!.headers.add('Accept', 'text/event-stream');
      _request!.headers.add('Cache-Control', 'no-cache');
      _request!.headers.add('Connection', 'keep-alive');

      _response = await _request!.close();

      if (_response!.statusCode != 200) {
        throw Exception('Error de conexión SSE: ${_response!.statusCode}');
      }

      // Conexión exitosa, emitir evento conectado
      _controller.add(SseEvent(type: 'connected', data: const {}));

      _response!
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          final trimmed = line.trim();
          if (trimmed.startsWith('data:')) {
            final dataStr = trimmed.substring(5).trim();
            if (dataStr.isNotEmpty) {
              try {
                final payload = jsonDecode(dataStr);
                _controller.add(SseEvent.fromJson(payload));
              } catch (e) {
                // Ignore parsing errors of non-JSON data
              }
            }
          }
        },
        onError: (err) {
          _scheduleReconnect();
        },
        onDone: () {
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isClosed) return;
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _closeActiveConnection();
      _connect();
    });
  }

  void _closeActiveConnection() {
    try {
      _request?.abort();
    } catch (_) {}
    try {
      _client?.close(force: true);
    } catch (_) {}
    _request = null;
    _client = null;
    _response = null;
  }

  void close() {
    _isClosed = true;
    _reconnectTimer?.cancel();
    _closeActiveConnection();
    _controller.close();
  }
}

// Riverpod Provider
final sseEventStreamProvider = StreamProvider<SseEvent>((ref) {
  final authState = ref.watch(authProvider);
  final token = authState.token;

  if (token == null || token.isEmpty) {
    return const Stream.empty();
  }

  final sseService = SseService(token);
  ref.onDispose(() {
    sseService.close();
  });

  return sseService.stream;
});
