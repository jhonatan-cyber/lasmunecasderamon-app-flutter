import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../offline/providers.dart';

/// An animated banner that appears at the top of the screen when the device
/// loses connectivity and disappears when connectivity is restored.
///
/// Usage — wrap any screen or layout that should show the banner:
/// ```dart
/// Column(
///   children: [
///     const OfflineBanner(),
///     Expanded(child: yourContent),
///   ],
/// )
/// ```
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider).valueOrNull ?? true;

    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 300),
      crossFadeState:
          isOnline ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      firstChild: _buildBanner(context),
      secondChild: const SizedBox.shrink(),
    );
  }

  Widget _buildBanner(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 2,
      color: theme.colorScheme.error,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.wifi_off_rounded,
                color: theme.colorScheme.onError,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sin conexión',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onError,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'Los cambios se sincronizarán automáticamente',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onError.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
