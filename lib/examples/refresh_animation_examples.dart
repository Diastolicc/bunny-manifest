// Examples of different pull-to-refresh animation options for your home screen

import 'package:flutter/material.dart';
import '../widgets/custom_refresh_indicators.dart';
import '../theme/app_theme.dart';

class RefreshAnimationExamples {
  // Example 1: Replace your current RefreshIndicator with a gradient one
  static Widget gradientRefreshExample({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return CustomRefreshIndicators.gradientRefreshIndicator(
      onRefresh: onRefresh,
      child: child,
      primaryColor: AppTheme.colors.primary,
      secondaryColor: Colors.purple,
    );
  }

  // Example 2: Bouncy animation for more playful feel
  static Widget bouncyRefreshExample({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return CustomRefreshIndicators.bouncyRefreshIndicator(
      onRefresh: onRefresh,
      child: child,
    );
  }

  // Example 3: Minimalist for clean design
  static Widget minimalistRefreshExample({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return CustomRefreshIndicators.minimalistRefreshIndicator(
      onRefresh: onRefresh,
      child: child,
      color: Colors.grey.shade600,
    );
  }

  // Example 4: Branded with your app colors
  static Widget brandedRefreshExample({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return CustomRefreshIndicators.brandedRefreshIndicator(
      onRefresh: onRefresh,
      child: child,
      brandColor: AppTheme.colors.primary,
    );
  }

  // Example 5: Animated with multiple colors
  static Widget animatedRefreshExample({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return CustomRefreshIndicators.animatedRefreshIndicator(
      onRefresh: onRefresh,
      child: child,
      colors: [
        AppTheme.colors.primary,
        Colors.purple,
        Colors.pink,
      ],
    );
  }

  // Example 6: Advanced with custom animations
  static Widget advancedRefreshExample({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return AdvancedRefreshIndicator(
      onRefresh: onRefresh,
      child: child,
      gradientColors: [
        AppTheme.colors.primary,
        Colors.purple,
      ],
      strokeWidth: 3.5,
      displacement: 45.0,
    );
  }

  // Example 7: Custom icon refresh indicator
  static Widget customIconRefreshExample({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return CustomIconRefreshIndicator(
      onRefresh: onRefresh,
      child: child,
      icon: Icons.refresh,
      color: AppTheme.colors.primary,
      text: 'Pull to refresh',
    );
  }
}

// How to implement in your home screen:
class HomeScreenRefreshExamples {
  // Replace your current RefreshIndicator with any of these:

  // Option 1: Gradient (Recommended for your app)
  static Widget buildGradientRefresh({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.colors.primary,
      backgroundColor: Colors.white,
      strokeWidth: 3.0,
      displacement: 40.0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.colors.primary.withOpacity(0.1),
              Colors.purple.withOpacity(0.05),
            ],
          ),
        ),
        child: child,
      ),
    );
  }

  // Option 2: Bouncy Animation
  static Widget buildBouncyRefresh({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.colors.primary,
      backgroundColor: Colors.white,
      strokeWidth: 2.5,
      displacement: 50.0,
      child: child,
    );
  }

  // Option 3: Minimalist
  static Widget buildMinimalistRefresh({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: Colors.grey.shade600,
      backgroundColor: Colors.transparent,
      strokeWidth: 2.0,
      displacement: 30.0,
      child: child,
    );
  }

  // Option 4: Branded with your theme
  static Widget buildBrandedRefresh({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.colors.primary,
      backgroundColor: AppTheme.colors.primary.withOpacity(0.1),
      strokeWidth: 3.5,
      displacement: 45.0,
      child: child,
    );
  }

  // Option 5: Custom with different colors
  static Widget buildCustomColorRefresh({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: Colors.purple,
      backgroundColor: Colors.purple.withOpacity(0.1),
      strokeWidth: 3.0,
      displacement: 40.0,
      child: child,
    );
  }
}

// Animation curve options for different feels:
class RefreshAnimationCurves {
  static const Curve bouncy = Curves.elasticOut;
  static const Curve smooth = Curves.easeInOut;
  static const Curve quick = Curves.fastOutSlowIn;
  static const Curve gentle = Curves.easeOut;
  static const Curve sharp = Curves.easeIn;
}

// Different stroke widths for different styles:
class RefreshStrokeWidths {
  static const double thin = 1.5;
  static const double normal = 2.5;
  static const double thick = 3.5;
  static const double extraThick = 4.5;
}

// Different displacement values for different pull distances:
class RefreshDisplacements {
  static const double close = 30.0;
  static const double normal = 40.0;
  static const double far = 50.0;
  static const double extraFar = 60.0;
}
