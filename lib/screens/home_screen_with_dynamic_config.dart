// Example of how to integrate dynamic section configuration
// This shows the updated _buildFeedContent method using the dynamic config

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/dynamic_section_config.dart';
import '../models/party.dart';

// Updated _buildFeedContent method using dynamic configuration
Widget _buildFeedContent(BuildContext context) {
  return Column(
    children: [
      // Get all visible sections in order
      ...DynamicSectionConfig.getVisibleSections().map((entry) {
        final key = entry.key;
        final config = entry.value;

        // Handle special cases for different section types
        switch (key) {
          case 'ongoing':
            return FutureBuilder<List<Party>>(
              future: _ongoingPartiesFuture ?? Future.value(<Party>[]),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  return _buildFeedItem(
                    title: config.title,
                    subtitle: config.subtitle,
                    color: config.color,
                    child: _buildOngoingTab(),
                    onTap: () => context.push(config.route),
                  );
                }
                return const SizedBox.shrink();
              },
            );

          case 'upcoming':
            return _buildFeedItem(
              title: config.title,
              subtitle: config.subtitle,
              color: config.color,
              child: _buildUpcomingTab(),
              onTap: () => context.push(config.route),
            );

          case 'huge_crowd':
            return _buildFeedItem(
              title: config.title,
              subtitle: config.subtitle,
              color: config.color,
              child: _buildHugeCrowdTab(),
              onTap: () => context.push(config.route),
            );

          case 'introvert':
            return _buildFeedItem(
              title: config.title,
              subtitle: config.subtitle,
              color: config.color,
              child: _buildIntrovertTab(),
              onTap: () => context.push(config.route),
            );

          default:
            return const SizedBox.shrink();
        }
      }).toList(),

      // Banner (if you want to keep it between sections)
      _buildBannerImage(),
    ],
  );
}

// Example usage methods for updating sections dynamically
class SectionManager {
  // Update a section title
  static void updateTitle(String sectionKey, String newTitle) {
    DynamicSectionConfig.updateSectionTitle(sectionKey, newTitle);
  }

  // Update a section subtitle
  static void updateSubtitle(String sectionKey, String newSubtitle) {
    DynamicSectionConfig.updateSectionSubtitle(sectionKey, newSubtitle);
  }

  // Update a section color
  static void updateColor(String sectionKey, Color newColor) {
    DynamicSectionConfig.updateSectionColor(sectionKey, newColor);
  }

  // Hide/show a section
  static void toggleSection(String sectionKey) {
    DynamicSectionConfig.toggleSectionVisibility(sectionKey);
  }

  // Reorder sections
  static void reorderSection(String sectionKey, int newOrder) {
    DynamicSectionConfig.updateSectionOrder(sectionKey, newOrder);
  }
}

// Example of how to use the SectionManager
void exampleUsage() {
  // Update section titles
  SectionManager.updateTitle('huge_crowd', 'Massive Parties');
  SectionManager.updateTitle('introvert', 'Quiet Gatherings');

  // Update subtitles
  SectionManager.updateSubtitle('huge_crowd', 'The biggest parties in town');
  SectionManager.updateSubtitle('introvert', 'Small, intimate gatherings');

  // Update colors
  SectionManager.updateColor('huge_crowd', Colors.red);
  SectionManager.updateColor('introvert', Colors.blue);

  // Hide a section
  SectionManager.toggleSection('venues');

  // Reorder sections
  SectionManager.reorderSection('introvert', 2); // Move introvert to position 2
}

// Mock data and functions for the missing implementations
Future<List<Party>>? _ongoingPartiesFuture = Future.value(<Party>[]);

Widget _buildFeedItem({
  required String title,
  required String subtitle,
  required Color color,
  required Widget child,
  required VoidCallback onTap,
}) {
  return Card(
    child: ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
      trailing: child,
    ),
  );
}

Widget _buildOngoingTab() {
  return const Text('Ongoing Parties');
}

Widget _buildUpcomingTab() {
  return const Text('Upcoming Parties');
}

Widget _buildHugeCrowdTab() {
  return const Text('Huge Crowd Parties');
}

Widget _buildIntrovertTab() {
  return const Text('Introvert Parties');
}

Widget _buildBannerImage() {
  return Container(
    height: 100,
    color: Colors.grey.shade200,
    child: const Center(child: Text('Banner Image')),
  );
}
