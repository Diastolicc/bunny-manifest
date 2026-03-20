// How to replace your current RefreshIndicator with different animation options

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HomeScreenRefreshOptions {
  // OPTION 1: Gradient RefreshIndicator (Recommended)
  // Replace your current RefreshIndicator with this:
  static Widget gradientRefreshIndicator({
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

  // OPTION 2: Bouncy Animation
  static Widget bouncyRefreshIndicator({
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

  // OPTION 3: Minimalist
  static Widget minimalistRefreshIndicator({
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

  // OPTION 4: Branded with Theme Colors
  static Widget brandedRefreshIndicator({
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

  // OPTION 5: Custom Colors
  static Widget customColorRefreshIndicator({
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

  // OPTION 6: Thick Stroke
  static Widget thickStrokeRefreshIndicator({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.colors.primary,
      backgroundColor: Colors.white,
      strokeWidth: 4.0,
      displacement: 40.0,
      child: child,
    );
  }

  // OPTION 7: Close Displacement
  static Widget closeRefreshIndicator({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.colors.primary,
      backgroundColor: Colors.white,
      strokeWidth: 3.0,
      displacement: 30.0,
      child: child,
    );
  }

  // OPTION 8: Far Displacement
  static Widget farRefreshIndicator({
    required Future<void> Function() onRefresh,
    required Widget child,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.colors.primary,
      backgroundColor: Colors.white,
      strokeWidth: 3.0,
      displacement: 60.0,
      child: child,
    );
  }
}

// IMPLEMENTATION GUIDE:
// To use any of these options, replace your current RefreshIndicator in home_screen.dart:

/*
CURRENT CODE:
RefreshIndicator(
  onRefresh: () async {
    await Future.wait([
      _loadClubs(),
      _loadUpcomingParties(),
    ]);
    setState(() {});
  },
  child: SingleChildScrollView(...),
)

REPLACE WITH:
HomeScreenRefreshOptions.gradientRefreshIndicator(
  onRefresh: () async {
    await Future.wait([
      _loadClubs(),
      _loadUpcomingParties(),
    ]);
    setState(() {});
  },
  child: SingleChildScrollView(...),
)
*/
