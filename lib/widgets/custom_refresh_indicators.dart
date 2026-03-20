import 'package:flutter/material.dart';

class CustomRefreshIndicators {
  // 1. Gradient RefreshIndicator
  static Widget gradientRefreshIndicator({
    required Future<void> Function() onRefresh,
    required Widget child,
    Color primaryColor = Colors.blue,
    Color secondaryColor = Colors.purple,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: primaryColor,
      backgroundColor: Colors.white,
      strokeWidth: 3.0,
      displacement: 40.0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primaryColor.withOpacity(0.1),
              secondaryColor.withOpacity(0.05),
            ],
          ),
        ),
        child: child,
      ),
    );
  }

  // 2. Bouncy RefreshIndicator
  static Widget bouncyRefreshIndicator({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: Colors.blue,
      backgroundColor: Colors.white,
      strokeWidth: 2.5,
      displacement: 50.0,
      child: child,
    );
  }

  // 3. Minimalist RefreshIndicator
  static Widget minimalistRefreshIndicator({
    required Future<void> Function() onRefresh,
    required Widget child,
    Color color = Colors.grey,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: color,
      backgroundColor: Colors.transparent,
      strokeWidth: 2.0,
      displacement: 30.0,
      child: child,
    );
  }

  // 4. Branded RefreshIndicator
  static Widget brandedRefreshIndicator({
    required Future<void> Function() onRefresh,
    required Widget child,
    Color brandColor = Colors.blue,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: brandColor,
      backgroundColor: brandColor.withOpacity(0.1),
      strokeWidth: 3.5,
      displacement: 45.0,
      child: child,
    );
  }

  // 5. Animated RefreshIndicator with Custom Animation
  static Widget animatedRefreshIndicator({
    required Future<void> Function() onRefresh,
    required Widget child,
    List<Color> colors = const [Colors.blue, Colors.purple, Colors.pink],
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: colors.first,
      backgroundColor: Colors.white,
      strokeWidth: 3.0,
      displacement: 40.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors.map((c) => c.withOpacity(0.05)).toList(),
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: child,
      ),
    );
  }
}

// Custom RefreshIndicator with Custom Icon
class CustomIconRefreshIndicator extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final IconData icon;
  final Color color;
  final String text;

  const CustomIconRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.icon = Icons.refresh,
    this.color = Colors.blue,
    this.text = 'Pull to refresh',
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: color,
      backgroundColor: Colors.white,
      strokeWidth: 3.0,
      displacement: 50.0,
      child: child,
    );
  }
}

// Advanced Custom RefreshIndicator with Multiple Animations
class AdvancedRefreshIndicator extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final List<Color> gradientColors;
  final double strokeWidth;
  final double displacement;

  const AdvancedRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.gradientColors = const [Colors.blue, Colors.purple],
    this.strokeWidth = 3.0,
    this.displacement = 40.0,
  });

  @override
  State<AdvancedRefreshIndicator> createState() =>
      _AdvancedRefreshIndicatorState();
}

class _AdvancedRefreshIndicatorState extends State<AdvancedRefreshIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _controller.forward();
        await widget.onRefresh();
        _controller.reverse();
      },
      color: widget.gradientColors.first,
      backgroundColor: Colors.white,
      strokeWidth: widget.strokeWidth,
      displacement: widget.displacement,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: widget.gradientColors
                    .map((color) => color.withOpacity(0.1 * _animation.value))
                    .toList(),
              ),
            ),
            child: widget.child,
          );
        },
      ),
    );
  }
}
