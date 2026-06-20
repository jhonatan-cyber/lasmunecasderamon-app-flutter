import 'package:flutter/material.dart';





class PremiumFAB extends StatefulWidget {
  const PremiumFAB({
    super.key,
    required this.onPressed,
    required this.icon,
    this.label,
    this.gradientColors,
    this.elevation = 6.0,
    this.size = 56.0,
    this.isLoading = false,
    this.backgroundColor,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String? label;
  final List<Color>? gradientColors;
  final double elevation;
  final double size;
  final bool isLoading;
  final Color? backgroundColor;

  @override
  State<PremiumFAB> createState() => _PremiumFABState();
}

class _PremiumFABState extends State<PremiumFAB> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
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
    final theme = Theme.of(context);
    final gradientColors = widget.gradientColors ?? [
      theme.colorScheme.primary,
      theme.colorScheme.primary.withValues(alpha: 0.8),
    ];

    final fab = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: widget.onPressed != null
            ? (_) => _controller.forward()
            : null,
        onTapUp: widget.onPressed != null
            ? (_) {
                _controller.reverse();
                widget.onPressed?.call();
              }
            : null,
        onTapCancel: () => _controller.reverse(),
        child: Container(
          width: widget.label != null ? null : widget.size,
          height: widget.size,
          padding: widget.label != null
              ? const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
              : null,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(widget.size / 2),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withValues(alpha: 0.4),
                blurRadius: widget.elevation * 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: widget.isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : widget.label != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        widget.icon,
                        const SizedBox(width: 8),
                        Text(
                          widget.label!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    )
                  : widget.icon,
        ),
      ),
    );

    return widget.label != null ? fab : fab;
  }
}
