import 'package:flutter/material.dart';

class SectionConfig {
  final String title;
  final String subtitle;
  final Color color;
  final String route;
  final bool isVisible;

  const SectionConfig({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.route,
    this.isVisible = true,
  });
}

class HomeSectionConfig {
  static const Map<String, SectionConfig> sections = {
    'ongoing': SectionConfig(
      title: 'Join the fun now',
      subtitle: 'Parties happening right now',
      color: Color(0xFF00B894),
      route: '/view-all-parties',
      isVisible: true,
    ),
    'upcoming': SectionConfig(
      title: 'You might be interested',
      subtitle: 'What\'s happening next?',
      color: Color(0xFF6C5CE7),
      route: '/view-all-parties',
      isVisible: true,
    ),
    'huge_crowd': SectionConfig(
      title: 'Huge Crowd',
      subtitle: 'Packed and lively parties',
      color: Color(0xFFFF7675),
      route: '/view-all-parties',
      isVisible: true,
    ),
    'introvert': SectionConfig(
      title: 'Introvert Gathering',
      subtitle: 'Chill and cozy vibes',
      color: Color(0xFF74B9FF),
      route: '/view-all-parties',
      isVisible: true,
    ),
    'venues': SectionConfig(
      title: 'Places you need to check out',
      subtitle: 'Amazing places to visit',
      color: Color(0xFF0984E3),
      route: '/view-all-venues',
      isVisible: true,
    ),
  };

  // Get section config by key
  static SectionConfig? getSection(String key) {
    return sections[key];
  }

  // Get all visible sections
  static List<MapEntry<String, SectionConfig>> getVisibleSections() {
    return sections.entries.where((entry) => entry.value.isVisible).toList();
  }

  // Update section visibility
  static void updateSectionVisibility(String key, bool isVisible) {
    // This would require making the map mutable or using a different approach
    // For now, this is a placeholder for future implementation
  }

  // Get section order (for custom ordering)
  static List<String> getSectionOrder() {
    return [
      'ongoing',
      'upcoming',
      'huge_crowd',
      'introvert',
      'venues',
    ];
  }
}
