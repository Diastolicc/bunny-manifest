import 'package:flutter/material.dart';

class SectionConfig {
  final String title;
  final String subtitle;
  final Color color;
  final String route;
  final bool isVisible;
  final int order;

  const SectionConfig({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.route,
    this.isVisible = true,
    this.order = 0,
  });

  SectionConfig copyWith({
    String? title,
    String? subtitle,
    Color? color,
    String? route,
    bool? isVisible,
    int? order,
  }) {
    return SectionConfig(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      color: color ?? this.color,
      route: route ?? this.route,
      isVisible: isVisible ?? this.isVisible,
      order: order ?? this.order,
    );
  }
}

class DynamicSectionConfig {
  static final Map<String, SectionConfig> _sections = {
    'ongoing': const SectionConfig(
      title: 'Join the fun now',
      subtitle: 'Parties happening right now',
      color: Color(0xFF00B894),
      route: '/view-all-parties',
      isVisible: true,
      order: 1,
    ),
    'upcoming': const SectionConfig(
      title: 'You might be interested',
      subtitle: 'What\'s happening next?',
      color: Color(0xFF6C5CE7),
      route: '/view-all-parties',
      isVisible: true,
      order: 2,
    ),
    'huge_crowd': const SectionConfig(
      title: 'Huge Crowd',
      subtitle: 'Packed and lively parties',
      color: Color(0xFFFF7675),
      route: '/view-all-parties',
      isVisible: true,
      order: 3,
    ),
    'introvert': const SectionConfig(
      title: 'Introvert Gathering',
      subtitle: 'Chill and cozy vibes',
      color: Color(0xFF74B9FF),
      route: '/view-all-parties',
      isVisible: true,
      order: 4,
    ),
    'venues': const SectionConfig(
      title: 'Places you need to check out',
      subtitle: 'Amazing places to visit',
      color: Color(0xFF0984E3),
      route: '/view-all-venues',
      isVisible: true,
      order: 5,
    ),
  };

  // Get section config by key
  static SectionConfig? getSection(String key) {
    return _sections[key];
  }

  // Get all visible sections in order
  static List<MapEntry<String, SectionConfig>> getVisibleSections() {
    return _sections.entries.where((entry) => entry.value.isVisible).toList()
      ..sort((a, b) => a.value.order.compareTo(b.value.order));
  }

  // Update section config
  static void updateSection(String key, SectionConfig newConfig) {
    _sections[key] = newConfig;
  }

  // Update section title
  static void updateSectionTitle(String key, String newTitle) {
    final current = _sections[key];
    if (current != null) {
      _sections[key] = current.copyWith(title: newTitle);
    }
  }

  // Update section subtitle
  static void updateSectionSubtitle(String key, String newSubtitle) {
    final current = _sections[key];
    if (current != null) {
      _sections[key] = current.copyWith(subtitle: newSubtitle);
    }
  }

  // Update section color
  static void updateSectionColor(String key, Color newColor) {
    final current = _sections[key];
    if (current != null) {
      _sections[key] = current.copyWith(color: newColor);
    }
  }

  // Toggle section visibility
  static void toggleSectionVisibility(String key) {
    final current = _sections[key];
    if (current != null) {
      _sections[key] = current.copyWith(isVisible: !current.isVisible);
    }
  }

  // Update section order
  static void updateSectionOrder(String key, int newOrder) {
    final current = _sections[key];
    if (current != null) {
      _sections[key] = current.copyWith(order: newOrder);
    }
  }

  // Get all sections (including hidden)
  static Map<String, SectionConfig> getAllSections() {
    return Map.from(_sections);
  }

  // Reset to default configuration
  static void resetToDefaults() {
    _sections.clear();
    _sections.addAll({
      'ongoing': const SectionConfig(
        title: 'Join the fun now',
        subtitle: 'Parties happening right now',
        color: Color(0xFF00B894),
        route: '/view-all-parties',
        isVisible: true,
        order: 1,
      ),
      'upcoming': const SectionConfig(
        title: 'You might be interested',
        subtitle: 'What\'s happening next?',
        color: Color(0xFF6C5CE7),
        route: '/view-all-parties',
        isVisible: true,
        order: 2,
      ),
      'huge_crowd': const SectionConfig(
        title: 'Huge Crowd',
        subtitle: 'Packed and lively parties',
        color: Color(0xFFFF7675),
        route: '/view-all-parties',
        isVisible: true,
        order: 3,
      ),
      'introvert': const SectionConfig(
        title: 'Introvert Gathering',
        subtitle: 'Chill and cozy vibes',
        color: Color(0xFF74B9FF),
        route: '/view-all-parties',
        isVisible: true,
        order: 4,
      ),
      'venues': const SectionConfig(
        title: 'Places you need to check out',
        subtitle: 'Amazing places to visit',
        color: Color(0xFF0984E3),
        route: '/view-all-venues',
        isVisible: true,
        order: 5,
      ),
    });
  }
}
