// Example usage of the dynamic section configuration system

import 'package:flutter/material.dart';
import '../config/dynamic_section_config.dart';

class SectionConfigUsageExample {
  // Example 1: Basic usage - get section config
  static void basicUsage() {
    // Get a specific section
    final ongoingConfig = DynamicSectionConfig.getSection('ongoing');
    if (ongoingConfig != null) {
      print('Title: ${ongoingConfig.title}');
      print('Subtitle: ${ongoingConfig.subtitle}');
      print('Color: ${ongoingConfig.color}');
      print('Visible: ${ongoingConfig.isVisible}');
    }

    // Get all visible sections
    final visibleSections = DynamicSectionConfig.getVisibleSections();
    for (final entry in visibleSections) {
      print('${entry.key}: ${entry.value.title}');
    }
  }

  // Example 2: Update section titles dynamically
  static void updateTitles() {
    // Update individual titles
    DynamicSectionConfig.updateSectionTitle('huge_crowd', 'Massive Parties');
    DynamicSectionConfig.updateSectionTitle('introvert', 'Quiet Gatherings');

    // Update subtitles
    DynamicSectionConfig.updateSectionSubtitle(
        'huge_crowd', 'The biggest parties in town');
    DynamicSectionConfig.updateSectionSubtitle(
        'introvert', 'Small, intimate gatherings');
  }

  // Example 3: Change colors
  static void updateColors() {
    DynamicSectionConfig.updateSectionColor('huge_crowd', Colors.red);
    DynamicSectionConfig.updateSectionColor('introvert', Colors.blue);
    DynamicSectionConfig.updateSectionColor('venues', Colors.green);
  }

  // Example 4: Toggle section visibility
  static void toggleSections() {
    // Hide venues section
    DynamicSectionConfig.toggleSectionVisibility('venues');

    // Show introvert section (if it was hidden)
    DynamicSectionConfig.toggleSectionVisibility('introvert');
  }

  // Example 5: Reorder sections
  static void reorderSections() {
    // Move introvert to position 2
    DynamicSectionConfig.updateSectionOrder('introvert', 2);

    // Move huge_crowd to position 1
    DynamicSectionConfig.updateSectionOrder('huge_crowd', 1);
  }

  // Example 6: Complete section update
  static void completeSectionUpdate() {
    // Update multiple properties at once
    final newConfig = SectionConfig(
      title: 'Epic Parties',
      subtitle: 'The most amazing parties ever',
      color: Colors.purple,
      route: '/view-all-parties',
      isVisible: true,
      order: 1,
    );

    DynamicSectionConfig.updateSection('huge_crowd', newConfig);
  }

  // Example 7: Reset everything
  static void resetAll() {
    DynamicSectionConfig.resetToDefaults();
  }

  // Example 8: Conditional section display
  static List<SectionConfig> getSectionsForUser(String userType) {
    final allSections = DynamicSectionConfig.getVisibleSections();

    switch (userType) {
      case 'new_user':
        // Show only basic sections for new users
        return allSections
            .where((entry) => ['ongoing', 'upcoming'].contains(entry.key))
            .map((entry) => entry.value)
            .toList();

      case 'premium_user':
        // Show all sections for premium users
        return allSections.map((entry) => entry.value).toList();

      case 'introvert':
        // Show only introvert-friendly sections
        return allSections
            .where((entry) => ['introvert', 'venues'].contains(entry.key))
            .map((entry) => entry.value)
            .toList();

      default:
        return allSections.map((entry) => entry.value).toList();
    }
  }

  // Example 9: A/B testing different titles
  static void abTestTitles() {
    // Version A
    DynamicSectionConfig.updateSectionTitle('huge_crowd', 'Huge Crowd');
    DynamicSectionConfig.updateSectionSubtitle(
        'huge_crowd', 'Packed and lively parties');

    // Version B (alternative)
    // DynamicSectionConfig.updateSectionTitle('huge_crowd', 'Massive Parties');
    // DynamicSectionConfig.updateSectionSubtitle('huge_crowd', 'The biggest parties in town');
  }

  // Example 10: Time-based section updates
  static void timeBasedUpdates() {
    final hour = DateTime.now().hour;

    if (hour >= 18 && hour <= 23) {
      // Evening - emphasize party sections
      DynamicSectionConfig.updateSectionTitle('ongoing', 'Live Now');
      DynamicSectionConfig.updateSectionSubtitle(
          'ongoing', 'Parties happening right now');
    } else if (hour >= 0 && hour <= 6) {
      // Late night - emphasize ongoing parties
      DynamicSectionConfig.updateSectionTitle('ongoing', 'Still Going');
      DynamicSectionConfig.updateSectionSubtitle(
          'ongoing', 'Late night parties');
    } else {
      // Daytime - emphasize upcoming parties
      DynamicSectionConfig.updateSectionTitle('upcoming', 'Tonight\'s Plans');
      DynamicSectionConfig.updateSectionSubtitle(
          'upcoming', 'What\'s happening tonight?');
    }
  }
}

// Example widget that uses the dynamic configuration
class DynamicSectionWidget extends StatelessWidget {
  final String sectionKey;

  const DynamicSectionWidget({
    super.key,
    required this.sectionKey,
  });

  @override
  Widget build(BuildContext context) {
    final config = DynamicSectionConfig.getSection(sectionKey);

    if (config == null || !config.isVisible) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: config.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            config.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: config.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            config.subtitle,
            style: TextStyle(
              fontSize: 14,
              color: config.color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
