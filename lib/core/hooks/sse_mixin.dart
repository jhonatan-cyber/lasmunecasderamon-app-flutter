import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../sse_event.dart';
import '../sse_service.dart';

export '../sse_event.dart';

mixin SseEventMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  void onSseEvent(SseEvent event);

  ProviderSubscription<AsyncValue<SseEvent>>? _sseSubscription;

  @override
  void initState() {
    super.initState();
    _sseSubscription = ref.listenManual(sseEventStreamProvider, (
      previous,
      next,
    ) {
      next.whenData((event) {
        if (mounted) {
          onSseEvent(event);
        }
      });
    });
  }

  @override
  void dispose() {
    _sseSubscription?.close();
    super.dispose();
  }
}
