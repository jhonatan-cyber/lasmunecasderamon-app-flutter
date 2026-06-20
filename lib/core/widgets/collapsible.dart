import 'package:flutter/material.dart';





class Collapsible extends StatefulWidget {
  const Collapsible({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
    this.titleStyle,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderRadius = 12,
    this.trailing,
    this.onToggle,
  });

  final Widget title;
  final Widget child;
  final bool initiallyExpanded;
  final TextStyle? titleStyle;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double borderRadius;
  final Widget? trailing;
  final ValueChanged<bool>? onToggle;

  @override
  State<Collapsible> createState() => _CollapsibleState();
}

class _CollapsibleState extends State<Collapsible>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
      widget.onToggle?.call(_isExpanded);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: widget.margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(widget.borderRadius),
            ),
            child: Padding(
              padding: widget.padding ?? const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: DefaultTextStyle(
                    style: widget.titleStyle ??
                        TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                    child: widget.title,
                  )),
                  if (widget.trailing != null) ...[
                    widget.trailing!,
                    const SizedBox(width: 8),
                  ],
                  RotationTransition(
                    turns: _expandAnimation,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          
          SizeTransition(
            sizeFactor: _expandAnimation,
            alignment: const Alignment(-1.0, 0.0),
            child: Padding(
              padding: widget.padding ?? const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
