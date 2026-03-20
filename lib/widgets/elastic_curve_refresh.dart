import 'package:flutter/material.dart';
import 'dart:math' as math;

class ElasticCurveRefreshIndicator extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final Color primaryColor;
  final List<Color> gradientColors;

  const ElasticCurveRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.primaryColor = Colors.blue,
    this.gradientColors = const [Colors.blue, Colors.purple, Colors.pink],
  });

  @override
  State<ElasticCurveRefreshIndicator> createState() =>
      _ElasticCurveRefreshIndicatorState();
}

class _ElasticCurveRefreshIndicatorState
    extends State<ElasticCurveRefreshIndicator> with TickerProviderStateMixin {
  late AnimationController _elasticController;
  late AnimationController _fillController;
  late AnimationController _waveController;
  late AnimationController _pulseController;

  double _pullDistance = 0.0;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();

    _elasticController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fillController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _elasticController.dispose();
    _fillController.dispose();
    _waveController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _startRefresh();
        await widget.onRefresh();
        _stopRefresh();
      },
      color: Colors.transparent,
      backgroundColor: Colors.transparent,
      strokeWidth: 0,
      displacement: 0,
      child: Stack(
        children: [
          widget.child,
          // Elastic curve overlay
          if (_pullDistance > 0 || _isRefreshing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildElasticCurveOverlay(),
            ),
        ],
      ),
    );
  }

  Widget _buildElasticCurveOverlay() {
    return Container(
      height: 120,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _elasticController,
          _fillController,
          _waveController,
          _pulseController,
        ]),
        builder: (context, child) {
          return CustomPaint(
            painter: ElasticCurvePainter(
              pullDistance: _pullDistance,
              isRefreshing: _isRefreshing,
              elasticAnimation: _elasticController,
              fillAnimation: _fillController,
              waveAnimation: _waveController,
              pulseAnimation: _pulseController,
              primaryColor: widget.primaryColor,
              gradientColors: widget.gradientColors,
            ),
          );
        },
      ),
    );
  }

  void _startRefresh() {
    setState(() {
      _isRefreshing = true;
    });

    _elasticController.repeat(reverse: true);
    _fillController.repeat();
    _waveController.repeat();
    _pulseController.repeat(reverse: true);
  }

  void _stopRefresh() {
    _elasticController.stop();
    _fillController.stop();
    _waveController.stop();
    _pulseController.stop();

    setState(() {
      _isRefreshing = false;
      _pullDistance = 0.0;
    });
  }
}

class ElasticCurvePainter extends CustomPainter {
  final double pullDistance;
  final bool isRefreshing;
  final AnimationController elasticAnimation;
  final AnimationController fillAnimation;
  final AnimationController waveAnimation;
  final AnimationController pulseAnimation;
  final Color primaryColor;
  final List<Color> gradientColors;

  ElasticCurvePainter({
    required this.pullDistance,
    required this.isRefreshing,
    required this.elasticAnimation,
    required this.fillAnimation,
    required this.waveAnimation,
    required this.pulseAnimation,
    required this.primaryColor,
    required this.gradientColors,
  }) : super(repaint: elasticAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Calculate progress (0.0 to 1.0)
    final progress = (pullDistance / 100.0).clamp(0.0, 1.0);
    final elasticProgress = isRefreshing ? elasticAnimation.value : progress;

    // Draw elastic curves
    _drawElasticCurves(canvas, size, centerX, centerY, elasticProgress);

    // Draw filling effect
    _drawFillingEffect(canvas, size, centerX, centerY, progress);

    // Draw wave effects
    _drawWaveEffects(canvas, size, centerX, centerY);

    // Draw pulsing center
    _drawPulsingCenter(canvas, centerX, centerY, elasticProgress);
  }

  void _drawElasticCurves(Canvas canvas, Size size, double centerX,
      double centerY, double progress) {
    final paint = Paint()
      ..color = primaryColor.withOpacity(0.8)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // Draw multiple elastic curves
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60.0) * (math.pi / 180);
      final curveLength = 40.0 * progress;
      final elasticOffset =
          math.sin(elasticAnimation.value * 2 * math.pi + i) * 8.0;

      final startX = centerX + (curveLength * 0.3) * math.cos(angle);
      final startY =
          centerY + (curveLength * 0.3) * math.sin(angle) + elasticOffset;

      final endX = centerX + curveLength * math.cos(angle);
      final endY = centerY + curveLength * math.sin(angle) + elasticOffset;

      // Draw elastic curve with bezier
      final path = Path();
      path.moveTo(startX, startY);

      final controlX1 = startX + (endX - startX) * 0.3;
      final controlY1 = startY + (endY - startY) * 0.3 + elasticOffset;
      final controlX2 = startX + (endX - startX) * 0.7;
      final controlY2 = startY + (endY - startY) * 0.7 + elasticOffset;

      path.cubicTo(controlX1, controlY1, controlX2, controlY2, endX, endY);

      canvas.drawPath(path, paint);
    }
  }

  void _drawFillingEffect(Canvas canvas, Size size, double centerX,
      double centerY, double progress) {
    if (progress > 0) {
      final fillPaint = Paint()..style = PaintingStyle.fill;

      // Create gradient fill
      final gradient = RadialGradient(
        colors: gradientColors
            .map((color) => color.withOpacity(0.3 * progress))
            .toList(),
        stops: [0.0, 0.5, 1.0],
      );

      final rect = Rect.fromCircle(
        center: Offset(centerX, centerY),
        radius: 30.0 * progress,
      );

      fillPaint.shader = gradient.createShader(rect);
      canvas.drawCircle(Offset(centerX, centerY), 30.0 * progress, fillPaint);
    }
  }

  void _drawWaveEffects(
      Canvas canvas, Size size, double centerX, double centerY) {
    if (isRefreshing) {
      final wavePaint = Paint()
        ..color = primaryColor.withOpacity(0.6)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      // Draw multiple wave patterns
      for (int wave = 0; wave < 3; wave++) {
        final path = Path();
        final waveHeight = 15.0 + (wave * 5.0);
        final waveLength = size.width / (2 + wave);
        final waveOffset =
            waveAnimation.value * 2 * math.pi + (wave * math.pi / 3);

        path.moveTo(0, centerY);

        for (double x = 0; x <= size.width; x += 3) {
          final y = centerY +
              waveHeight *
                  math.sin((x / waveLength) * 2 * math.pi + waveOffset) *
                  (1.0 - (x / size.width));
          path.lineTo(x, y);
        }

        canvas.drawPath(path, wavePaint);
      }
    }
  }

  void _drawPulsingCenter(
      Canvas canvas, double centerX, double centerY, double progress) {
    if (progress > 0.3) {
      final pulseSize = 8.0 + (pulseAnimation.value * 4.0);
      final pulseOpacity = 0.6 + (pulseAnimation.value * 0.4);

      final centerPaint = Paint()
        ..color = primaryColor.withOpacity(pulseOpacity * progress)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(centerX, centerY),
        pulseSize,
        centerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(ElasticCurvePainter oldDelegate) {
    return pullDistance != oldDelegate.pullDistance ||
        isRefreshing != oldDelegate.isRefreshing ||
        elasticAnimation != oldDelegate.elasticAnimation ||
        fillAnimation != oldDelegate.fillAnimation ||
        waveAnimation != oldDelegate.waveAnimation ||
        pulseAnimation != oldDelegate.pulseAnimation;
  }
}
