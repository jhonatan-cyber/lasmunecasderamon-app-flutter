import 'package:flutter/material.dart';













class StaggeredFadeIn extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final Curve curve;

  const StaggeredFadeIn({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeOut,
  });

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    final delay = widget.index * 80;
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _controller.forward();
    });

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}
