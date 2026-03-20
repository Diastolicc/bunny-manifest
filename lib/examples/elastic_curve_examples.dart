// Examples of the Elastic Curve Refresh Indicator

import 'package:flutter/material.dart';
import '../widgets/elastic_curve_refresh.dart';
import '../theme/app_theme.dart';

class ElasticCurveExamples {
  // Example 1: Basic Elastic Curve
  static Widget basicElasticCurve({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return ElasticCurveRefreshIndicator(
      onRefresh: onRefresh,
      child: child,
      primaryColor: AppTheme.colors.primary,
      gradientColors: [
        AppTheme.colors.primary,
        Colors.purple,
        Colors.pink,
      ],
    );
  }

  // Example 2: Custom Colors Elastic Curve
  static Widget customColorsElasticCurve({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return ElasticCurveRefreshIndicator(
      onRefresh: onRefresh,
      child: child,
      primaryColor: Colors.purple,
      gradientColors: [
        Colors.purple,
        Colors.blue,
        Colors.teal,
      ],
    );
  }

  // Example 3: Rainbow Elastic Curve
  static Widget rainbowElasticCurve({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return ElasticCurveRefreshIndicator(
      onRefresh: onRefresh,
      child: child,
      primaryColor: Colors.blue,
      gradientColors: [
        Colors.red,
        Colors.orange,
        Colors.yellow,
        Colors.green,
        Colors.blue,
        Colors.indigo,
        Colors.purple,
      ],
    );
  }
}

// How the Elastic Curve Works:
class ElasticCurveExplanation {
  static const String howItWorks = '''
  🎯 ELASTIC CURVE REFRESH - NO CIRCLE ARROW!
  
  ✨ WHAT YOU'LL SEE:
  
  1. 🌊 ELASTIC CURVES:
     - 6 curved lines that grow as you pull down
     - Lines use bezier curves for smooth, elastic feel
     - Each line wiggles independently with elastic animation
  
  2. 🎨 FILLING EFFECT:
     - Gradient circle that fills from center as you pull
     - Uses your brand colors (primary, purple, pink)
     - Opacity increases with pull distance
  
  3. 🌊 WAVE EFFECTS:
     - Multiple sine wave patterns during refresh
     - Waves flow across the screen
     - Creates organic, flowing movement
  
  4. 💫 PULSING CENTER:
     - Center dot that pulses in size and opacity
     - Only appears when you've pulled enough
     - Indicates when refresh will trigger
  
  5. 🎪 ELASTIC ANIMATION:
     - Lines bounce and wiggle with elastic curves
     - Smooth, bouncy feel instead of rigid circle
     - Natural, organic movement
  
  🚀 HOW TO USE:
  - Pull down on your home screen
  - Watch the elastic curves grow and fill
  - Release when you see the pulsing center
  - Enjoy the smooth, elastic refresh animation!
  ''';

  // Technical Details:
  static const String technicalDetails = '''
  🔧 TECHNICAL FEATURES:
  
  - NO RefreshIndicator widget (completely custom)
  - GestureDetector for pull detection
  - Custom Paint for drawing elastic curves
  - 4 Animation Controllers for different effects
  - Bezier curves for smooth elastic lines
  - Radial gradient for filling effect
  - Sine waves for organic movement
  - Elastic curves instead of rigid circles
  ''';
}
