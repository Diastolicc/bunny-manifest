// Examples of how to use the wiggling refresh indicators

import 'package:flutter/material.dart';
import '../widgets/wiggling_refresh_indicator.dart';
import '../widgets/advanced_wiggling_refresh.dart';
import '../theme/app_theme.dart';

class WigglingRefreshExamples {
  // Example 1: Basic Wiggling Lines
  static Widget basicWigglingExample({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return WigglingRefreshIndicator(
      onRefresh: onRefresh,
      child: child,
      color: AppTheme.colors.primary,
      strokeWidth: 3.0,
    );
  }

  // Example 2: Advanced Wiggling with Multiple Effects
  static Widget advancedWigglingExample({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return AdvancedWigglingRefreshIndicator(
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

  // Example 3: Custom Colors Wiggling
  static Widget customColorsWigglingExample({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return AdvancedWigglingRefreshIndicator(
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

  // Example 4: Rainbow Wiggling
  static Widget rainbowWigglingExample({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return AdvancedWigglingRefreshIndicator(
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

// How to implement in your home screen:
class HomeScreenWigglingImplementation {
  // Replace your current RefreshIndicator with this:
  static Widget buildWigglingRefresh({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return AdvancedWigglingRefreshIndicator(
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
}

// Animation Effects Explained:
class WigglingEffects {
  // What you'll see with the wiggling refresh:
  static const String effects = '''
  🎪 WIGGLING EFFECTS:
  
  1. 🌊 Wiggling Lines:
     - Multiple sets of animated lines that wiggle up and down
     - Lines rotate around a center point
     - Different opacity levels for depth
  
  2. 🌈 Gradient Background:
     - Smooth gradient that pulses with your brand colors
     - Changes opacity during refresh
  
  3. 🎯 Bouncing Dots:
     - Colorful dots that bounce up and down
     - Each dot has different timing for wave effect
     - Uses your gradient colors
  
  4. 🌊 Wave Animation:
     - Sine wave pattern that moves across the screen
     - Creates a flowing, organic feel
  
  5. 🔄 Rotation Effects:
     - Lines rotate around center point
     - Creates a spinning, dynamic effect
  
  6. 💫 Pulsing Center:
     - Center circle that pulses in size
     - Changes opacity during animation
  ''';
}
