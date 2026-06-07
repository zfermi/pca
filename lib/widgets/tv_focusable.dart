import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TvFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool autofocus;
  final BorderRadius borderRadius;
  final Color focusColor;
  final double focusBorderWidth;
  final FocusNode? focusNode;

  const TvFocusable({
    super.key,
    required this.child,
    this.onPressed,
    this.autofocus = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.focusColor = const Color(0xFFFF6D00),
    this.focusBorderWidth = 3.0,
    this.focusNode,
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  late FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
      widget.onPressed?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: _handleKey,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            border: _focused
                ? Border.all(
                    color: widget.focusColor,
                    width: widget.focusBorderWidth,
                  )
                : Border.all(color: Colors.transparent, width: widget.focusBorderWidth),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: widget.focusColor.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class TvFocusableCircle extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool autofocus;
  final Color focusColor;
  final double focusBorderWidth;

  const TvFocusableCircle({
    super.key,
    required this.child,
    this.onPressed,
    this.autofocus = false,
    this.focusColor = const Color(0xFFFF6D00),
    this.focusBorderWidth = 3.0,
  });

  @override
  State<TvFocusableCircle> createState() => _TvFocusableCircleState();
}

class _TvFocusableCircleState extends State<TvFocusableCircle> {
  bool _focused = false;

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
      widget.onPressed?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: _handleKey,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: _focused
                ? Border.all(
                    color: widget.focusColor,
                    width: widget.focusBorderWidth,
                  )
                : Border.all(color: Colors.transparent, width: widget.focusBorderWidth),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: widget.focusColor.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
