import 'package:flutter/material.dart';

/// A single skeleton element with shimmer animation.
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
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: false);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = widget.baseColor ??
        (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.withValues(alpha: 0.15));
    final highlightColor = widget.highlightColor ??
        (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.25));

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: const Alignment(-1.0, 0.0),
              end: const Alignment(1.0, 0.0),
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A pre-built skeleton layout for card-style content.
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
    final surfaceColor = isDark
        ? const Color(0xFF18181A)
        : Colors.white;
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
            const SkeletonLoader(
              width: 48,
              height: 48,
              borderRadius: 24,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(lines, (index) {
                final isFirst = index == 0;
                final isLast = index == lines - 1;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: isLast ? 0 : 8,
                  ),
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

/// A pre-built skeleton for stat cards (like the ones in GarzonHomeScreen).
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
              children: [
                const SkeletonLoader(height: 12, width: 80, borderRadius: 6),
                const SizedBox(height: 8),
                const SkeletonLoader(height: 24, width: 120, borderRadius: 8),
                const SizedBox(height: 16),
                const SkeletonLoader(height: 12, width: 100, borderRadius: 6),
                const SizedBox(height: 8),
                const SkeletonLoader(height: 18, width: 60, borderRadius: 6),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 80,
            color: borderColor,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          const SkeletonLoader(
            width: 90,
            height: 90,
            borderRadius: 45,
          ),
        ],
      ),
    );
  }
}
