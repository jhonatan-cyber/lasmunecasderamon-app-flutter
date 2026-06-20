import 'package:flutter/material.dart';



class AnimatedButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double scaleDown;
  final Duration duration;
  final Color? backgroundColor;
  final Gradient? gradient;
  final BorderRadius? borderRadius;
  final BorderSide? border;
  final EdgeInsetsGeometry? padding;
  final bool isLoading;
  final bool isExpanded;
  final double? width;
  final double? height;

  const AnimatedButton({
    super.key,
    this.onPressed,
    required this.child,
    this.scaleDown = 0.95,
    this.duration = const Duration(milliseconds: 120),
    this.backgroundColor,
    this.gradient,
    this.borderRadius,
    this.border,
    this.padding,
    this.isLoading = false,
    this.isExpanded = false,
    this.width,
    this.height,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleDown,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(12);
    final bgColor = widget.backgroundColor ?? Theme.of(context).colorScheme.primary;

    Widget button = GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.isLoading ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          width: widget.width,
          height: widget.height ?? 48,
          decoration: BoxDecoration(
            color: widget.gradient == null ? bgColor : null,
            gradient: widget.gradient,
            borderRadius: radius,
            border: widget.border != null ? Border.fromBorderSide(widget.border!) : null,
            boxShadow: widget.onPressed != null && !widget.isLoading
                ? [
                    BoxShadow(
                      color: bgColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          padding: widget.padding ??
              const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : widget.child,
          ),
        ),
      ),
    );

    if (widget.isExpanded) {
      return Expanded(child: button);
    }
    return button;
  }
}


class PrimaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;
  final bool isExpanded;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const PrimaryButton({
    super.key,
    this.onPressed,
    required this.child,
    this.isLoading = false,
    this.isExpanded = false,
    this.height,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedButton(
      onPressed: onPressed,
      isLoading: isLoading,
      isExpanded: isExpanded,
      height: height,
      padding: padding,
      gradient: LinearGradient(
        colors: [Theme.of(context).colorScheme.primary, Color(0xFF881337)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        child: child,
      ),
    );
  }
}


class OutlinedAnimatedButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color? borderColor;
  final Color? textColor;
  final bool isLoading;
  final bool isExpanded;

  const OutlinedAnimatedButton({
    super.key,
    this.onPressed,
    required this.child,
    this.borderColor,
    this.textColor,
    this.isLoading = false,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = borderColor ?? Theme.of(context).colorScheme.primary;
    return AnimatedButton(
      onPressed: onPressed,
      isLoading: isLoading,
      isExpanded: isExpanded,
      backgroundColor: Colors.transparent,
      border: BorderSide(color: color.withValues(alpha: 0.5)),
      child: DefaultTextStyle(
        style: TextStyle(
          color: textColor ?? color,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        child: child,
      ),
    );
  }
}
