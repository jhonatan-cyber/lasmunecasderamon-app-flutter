import 'package:flutter/material.dart';







class _ShimmerProvider extends InheritedNotifier<AnimationController> {
  const _ShimmerProvider({
    required AnimationController notifier,
    required super.child,
  }) : super(notifier: notifier);

  static AnimationController of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<_ShimmerProvider>();
    assert(provider != null, 'No _ShimmerProvider found in context');
    return provider!.notifier!;
  }
}







class ShimmerWrapper extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const ShimmerWrapper({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1800),
  });

  @override
  State<ShimmerWrapper> createState() => _ShimmerWrapperState();
}

class _ShimmerWrapperState extends State<ShimmerWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerProvider(notifier: _controller, child: widget.child);
  }
}









class SkeletonLoader extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const SkeletonLoader({
    super.key,
    this.width,
    this.height = 20,
    this.borderRadius = 8,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  AnimationController? _fallbackController;

  AnimationController _resolveController(BuildContext context) {
    
    try {
      return _ShimmerProvider.of(context);
    } catch (_) {
      
      
      _fallbackController ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800),
      )..repeat();
      return _fallbackController!;
    }
  }

  @override
  void dispose() {
    _fallbackController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _resolveController(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final base =
        widget.baseColor ??
        (isDark
            ? primaryColor.withValues(alpha: 0.25)
            : primaryColor.withValues(alpha: 0.15));
    final highlight =
        widget.highlightColor ??
        (isDark
            ? primaryColor.withValues(alpha: 0.35)
            : primaryColor.withValues(alpha: 0.25));

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        
        final t = controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              colors: [base, highlight, base],
              stops: [
                (t - 0.4).clamp(0.0, 1.0),
                t.clamp(0.0, 1.0),
                (t + 0.4).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}






class SkeletonCard extends StatelessWidget {
  final bool showAvatar;
  final int lines;
  final double? width;

  const SkeletonCard({
    super.key,
    this.showAvatar = false,
    this.lines = 3,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF18181A) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);

    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showAvatar) ...[
            const SkeletonLoader(width: 48, height: 48, borderRadius: 24),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(lines, (index) {
                final isFirst = index == 0;
                final isLast = index == lines - 1;
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                  child: SkeletonLoader(
                    width: isFirst
                        ? (width ?? 200) * 0.6
                        : (width ?? 200) * (0.8 - index * 0.15),
                    height: isFirst ? 16 : 12,
                    borderRadius: 6,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

















class FadeLoadingSwitcher extends StatelessWidget {
  final bool isLoading;
  final Widget skeleton;
  final Widget content;
  final Duration duration;

  const FadeLoadingSwitcher({
    super.key,
    required this.isLoading,
    required this.skeleton,
    required this.content,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.90, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
      child: isLoading
          ? KeyedSubtree(key: const ValueKey('skeleton'), child: skeleton)
          : KeyedSubtree(key: const ValueKey('content'), child: content),
    );
  }
}






























class StaggeredFadeIn extends StatefulWidget {
  final List<Widget> children;
  final Duration staggerDelay;
  final Duration animationDuration;
  final double slideOffset;

  const StaggeredFadeIn({
    super.key,
    required this.children,
    this.staggerDelay = const Duration(milliseconds: 60),
    this.animationDuration = const Duration(milliseconds: 400),
    this.slideOffset = 16.0,
  });

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Animation<double>> _fadeAnimations;
  late final List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();

    final int count = widget.children.length;
    final int totalStaggerMs = (count - 1) * widget.staggerDelay.inMilliseconds;
    final int totalDurationMs =
        totalStaggerMs + widget.animationDuration.inMilliseconds;

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalDurationMs),
    );

    _fadeAnimations = List.generate(count, (index) {
      final startMs = index * widget.staggerDelay.inMilliseconds;
      final endMs = startMs + widget.animationDuration.inMilliseconds;
      final start = startMs / totalDurationMs;
      final end = (endMs / totalDurationMs).clamp(0.0, 1.0);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      );
    });

    _slideAnimations = List.generate(count, (index) {
      final startMs = index * widget.staggerDelay.inMilliseconds;
      final endMs = startMs + widget.animationDuration.inMilliseconds;
      final start = startMs / totalDurationMs;
      final end = (endMs / totalDurationMs).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: Offset(0, widget.slideOffset),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: Curves.easeOutBack),
        ),
      );
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Column(
          children: List.generate(widget.children.length, (index) {
            return Opacity(
              opacity: _fadeAnimations[index].value,
              child: Transform.translate(
                offset: _slideAnimations[index].value,
                child: widget.children[index],
              ),
            );
          }),
        );
      },
    );
  }
}






class SkeletonStatCard extends StatelessWidget {
  const SkeletonStatCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF18181A) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonLoader(height: 12, width: 80, borderRadius: 6),
                SizedBox(height: 8),
                SkeletonLoader(height: 24, width: 120, borderRadius: 8),
                SizedBox(height: 16),
                SkeletonLoader(height: 12, width: 100, borderRadius: 6),
                SizedBox(height: 8),
                SkeletonLoader(height: 18, width: 60, borderRadius: 6),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 80,
            color: borderColor,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          const SkeletonLoader(width: 90, height: 90, borderRadius: 45),
        ],
      ),
    );
  }
}
