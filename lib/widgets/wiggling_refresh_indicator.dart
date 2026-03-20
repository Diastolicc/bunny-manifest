import 'dart:math' as math;
import 'package:flutter/material.dart';

class WigglingRefreshIndicator extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final Color color;
  final double strokeWidth;

  const WigglingRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color = Colors.blue,
    this.strokeWidth = 3.0,
  });

  @override
  State<WigglingRefreshIndicator> createState() =>
      _WigglingRefreshIndicatorState();
}

class _WigglingRefreshIndicatorState extends State<WigglingRefreshIndicator>
    with TickerProviderStateMixin {
  late AnimationController _wiggleController;
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _wiggleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    // Wiggling animation
    _wiggleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _wiggleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _wiggleController,
      curve: Curves.elasticInOut,
    ));

    // Pulsing animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Rotation animation
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _wiggleController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _startAnimations();
        await widget.onRefresh();
        _stopAnimations();
      },
      color: widget.color,
      backgroundColor: Colors.transparent,
      strokeWidth: widget.strokeWidth,
      displacement: 60.0,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _wiggleAnimation,
          _pulseAnimation,
          _rotationAnimation,
        ]),
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  widget.color.withOpacity(0.1 * _pulseAnimation.value),
                  Colors.transparent,
                ],
              ),
            ),
            child: Stack(
              children: [
                widget.child,
                // Wiggling lines overlay
                if (_wiggleController.isAnimating)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildWigglingLines(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWigglingLines() {
    return Container(
      height: 100,
      child: CustomPaint(
        painter: WigglingLinesPainter(
          animation: _wiggleAnimation,
          pulseAnimation: _pulseAnimation,
          rotationAnimation: _rotationAnimation,
          color: widget.color,
        ),
      ),
    );
  }

  void _startAnimations() {
    _wiggleController.repeat(reverse: true);
    _pulseController.repeat(reverse: true);
    _rotationController.repeat();
  }

  void _stopAnimations() {
    _wiggleController.stop();
    _pulseController.stop();
    _rotationController.stop();
  }
}

class WigglingLinesPainter extends CustomPainter {
  final Animation<double> animation;
  final Animation<double> pulseAnimation;
  final Animation<double> rotationAnimation;
  final Color color;

  WigglingLinesPainter({
    required this.animation,
    required this.pulseAnimation,
    required this.rotationAnimation,
    required this.color,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = 20.0 * pulseAnimation.value;

    // Draw wiggling lines
    for (int i = 0; i < 8; i++) {
      final angle =
          (i * 45.0 + rotationAnimation.value * 360.0) * (3.14159 / 180);
      final wiggleOffset = (animation.value - 0.5) * 10.0;

      final startX = centerX + (radius * 0.7) * math.cos(angle);
      final startY = centerY + (radius * 0.7) * math.sin(angle) + wiggleOffset;

      final endX = centerX + radius * math.cos(angle);
      final endY = centerY + radius * math.sin(angle) + wiggleOffset;

      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        paint,
      );
    }

    // Draw pulsing center circle
    final centerPaint = Paint()
      ..color = color.withOpacity(0.3 * pulseAnimation.value)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(centerX, centerY),
      8.0 * pulseAnimation.value,
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(WigglingLinesPainter oldDelegate) {
    return animation != oldDelegate.animation ||
        pulseAnimation != oldDelegate.pulseAnimation ||
        rotationAnimation != oldDelegate.rotationAnimation;
  }
}
