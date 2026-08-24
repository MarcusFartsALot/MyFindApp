import 'package:flutter/material.dart';

/// Adds a reliable rightward swipe-to-pop gesture at the screen's left edge.
///
/// The narrow hit area avoids interfering with maps, horizontal tabs, and
/// ordinary page scrolling. The system/app-bar back actions remain available.
class EdgeSwipeBack extends StatefulWidget {
  final Widget child;

  const EdgeSwipeBack({super.key, required this.child});

  @override
  State<EdgeSwipeBack> createState() => _EdgeSwipeBackState();
}

class _EdgeSwipeBackState extends State<EdgeSwipeBack> {
  static const _edgeWidth = 24.0;
  static const _distanceThreshold = 64.0;
  static const _velocityThreshold = 360.0;

  double _dragDistance = 0;
  bool _isPopping = false;

  void _startDrag(DragStartDetails details) {
    _dragDistance = 0;
  }

  void _updateDrag(DragUpdateDetails details) {
    _dragDistance = (_dragDistance + details.delta.dx)
        .clamp(0, double.infinity)
        .toDouble();
  }

  Future<void> _finishDrag(DragEndDetails details) async {
    final shouldPop =
        _dragDistance >= _distanceThreshold ||
        details.primaryVelocity != null &&
            details.primaryVelocity! >= _velocityThreshold;
    _dragDistance = 0;
    if (!shouldPop || _isPopping || !mounted) return;

    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return;
    _isPopping = true;
    await navigator.maybePop();
    if (mounted) _isPopping = false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          width: _edgeWidth,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: _startDrag,
            onHorizontalDragUpdate: _updateDrag,
            onHorizontalDragEnd: _finishDrag,
          ),
        ),
      ],
    );
  }
}
