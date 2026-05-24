import 'package:flutter/material.dart';

/// A widget that delays rendering its heavy child until the page transition animation
/// has completed (typically 300ms). This ensures 60fps/120fps smooth screen slide-ins.
class TransitionDelay extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Widget? placeholder;

  const TransitionDelay({
    super.key,
    required this.child,
    this.delay = const Duration(milliseconds: 320),
    this.placeholder,
  });

  @override
  State<TransitionDelay> createState() => _TransitionDelayState();
}

class _TransitionDelayState extends State<TransitionDelay> {
  bool _isTransitionFinished = false;

  @override
  void initState() {
    super.initState();
    // Wait for the next frame and delay activation until the route transition settles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Future.delayed(widget.delay, () {
          if (mounted) {
            setState(() {
              _isTransitionFinished = true;
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isTransitionFinished) {
      return widget.placeholder ?? const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 3.0,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE57A2B)),
          ),
        ),
      );
    }
    return widget.child;
  }
}
