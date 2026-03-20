import 'package:flutter/material.dart';
import 'dart:math' as math;

class AdvancedWigglingRefreshIndicator extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final Color primaryColor;
  final List<Color> gradientColors;

  const AdvancedWigglingRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.primaryColor = Colors.blue,
    this.gradientColors = const [Colors.blue, Colors.purple, Colors.pink],
  });

  @override
  State<AdvancedWigglingRefreshIndicator> createState() =>
      _AdvancedWigglingRefreshIndicatorState();
}

class _AdvancedWigglingRefreshIndicatorState
    extends State<AdvancedWigglingRefreshIndicator>
    with TickerProviderStateMixin {
  late AnimationController _wiggleController;
  late AnimationController _waveController;
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _bounceController;

  @override
  void initState() {
    super.initState();

    // Multiple animation controllers for different effects
    _wiggleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _wiggleController.dispose();
    _waveController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _startAllAnimations();
        await widget.onRefresh();
        _stopAllAnimations();
      },
      color: widget.primaryColor,
      backgroundColor: Colors.transparent,
      strokeWidth: 4.0,
      displacement: 70.0,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _wiggleController,
          _waveController,
          _pulseController,
          _rotationController,
          _bounceController,
        ]),
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: widget.gradientColors
                    .map((color) =>
                        color.withOpacity(0.1 * _pulseController.value))
                    .toList(),
              ),
            ),
            child: Stack(
              children: [
                widget.child,
                // Multiple animated overlays
                if (_wiggleController.isAnimating)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildWigglingLinesOverlay(),
                  ),
                if (_waveController.isAnimating)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildWaveOverlay(),
                  ),
                if (_bounceController.isAnimating)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildBouncingDots(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWigglingLinesOverlay() {
    return Container(
      height: 120,
      child: CustomPaint(
        painter: WigglingLinesPainter(
          wiggleAnimation: _wiggleController,
          pulseAnimation: _pulseController,
          rotationAnimation: _rotationController,
          color: widget.primaryColor,
        ),
      ),
    );
  }

  Widget _buildWaveOverlay() {
    return Container(
      height: 80,
      child: CustomPaint(
        painter: WavePainter(
          waveAnimation: _waveController,
          color: widget.primaryColor,
        ),
      ),
    );
  }

  Widget _buildBouncingDots() {
    return Container(
      height: 60,
      child: CustomPaint(
        painter: BouncingDotsPainter(
          bounceAnimation: _bounceController,
          colors: widget.gradientColors,
        ),
      ),
    );
  }

  void _startAllAnimations() {
    _wiggleController.repeat(reverse: true);
    _waveController.repeat();
    _pulseController.repeat(reverse: true);
    _rotationController.repeat();
    _bounceController.repeat(reverse: true);
  }

  void _stopAllAnimations() {
    _wiggleController.stop();
    _waveController.stop();
    _pulseController.stop();
    _rotationController.stop();
    _bounceController.stop();
  }
}

class WigglingLinesPainter extends CustomPainter {
  final AnimationController wiggleAnimation;
  final AnimationController pulseAnimation;
  final AnimationController rotationAnimation;
  final Color color;

  WigglingLinesPainter({
    required this.wiggleAnimation,
    required this.pulseAnimation,
    required this.rotationAnimation,
    required this.color,
  }) : super(repaint: wiggleAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.9)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = 25.0 * pulseAnimation.value;

    // Draw multiple sets of wiggling lines
    for (int set = 0; set < 3; set++) {
      final setRadius = radius * (0.6 + set * 0.2);
      final setOpacity = 1.0 - (set * 0.3);

      for (int i = 0; i < 12; i++) {
        final angle =
            (i * 30.0 + rotationAnimation.value * 360.0) * (math.pi / 180);
        final wiggleOffset =
            (wiggleAnimation.value - 0.5) * 15.0 * (1.0 + set * 0.5);

        final startX = centerX + (setRadius * 0.5) * math.cos(angle);
        final startY =
            centerY + (setRadius * 0.5) * math.sin(angle) + wiggleOffset;

        final endX = centerX + setRadius * math.cos(angle);
        final endY = centerY + setRadius * math.sin(angle) + wiggleOffset;

        final linePaint = Paint()
          ..color = color.withOpacity(setOpacity)
          ..strokeWidth = 2.0 - (set * 0.5)
          ..style = PaintingStyle.stroke;

        canvas.drawLine(
          Offset(startX, startY),
          Offset(endX, endY),
          linePaint,
        );
      }
    }

    // Draw pulsing center
    final centerPaint = Paint()
      ..color = color.withOpacity(0.4 * pulseAnimation.value)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(centerX, centerY),
      12.0 * pulseAnimation.value,
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(WigglingLinesPainter oldDelegate) {
    return wiggleAnimation != oldDelegate.wiggleAnimation ||
        pulseAnimation != oldDelegate.pulseAnimation ||
        rotationAnimation != oldDelegate.rotationAnimation;
  }
}

class WavePainter extends CustomPainter {
  final AnimationController waveAnimation;
  final Color color;

  WavePainter({
    required this.waveAnimation,
    required this.color,
  }) : super(repaint: waveAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    final waveHeight = 20.0;
    final waveLength = size.width / 4;

    path.moveTo(0, size.height / 2);

    for (double x = 0; x <= size.width; x += 2) {
      final y = size.height / 2 +
          waveHeight *
              math.sin((x / waveLength) * 2 * math.pi +
                  waveAnimation.value * 2 * math.pi);
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) {
    return waveAnimation != oldDelegate.waveAnimation;
  }
}

class BouncingDotsPainter extends CustomPainter {
  final AnimationController bounceAnimation;
  final List<Color> colors;

  BouncingDotsPainter({
    required this.bounceAnimation,
    required this.colors,
  }) : super(repaint: bounceAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    final dotCount = 5;
    final spacing = size.width / (dotCount + 1);

    for (int i = 0; i < dotCount; i++) {
      final x = spacing * (i + 1);
      final y = size.height / 2;

      final bounceOffset =
          math.sin((bounceAnimation.value * 2 * math.pi) + (i * 0.5)) * 15.0;
      final dotY = y + bounceOffset;

      final dotPaint = Paint()
        ..color = colors[i % colors.length].withOpacity(0.8)
        ..style = PaintingStyle.fill;

      final dotSize =
          8.0 + (math.sin(bounceAnimation.value * 2 * math.pi + i) * 4.0);

      canvas.drawCircle(
        Offset(x, dotY),
        dotSize,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(BouncingDotsPainter oldDelegate) {
    return bounceAnimation != oldDelegate.bounceAnimation;
  }
}
