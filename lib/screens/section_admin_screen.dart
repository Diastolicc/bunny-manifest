import 'package:flutter/material.dart';
import '../config/dynamic_section_config.dart';

class SectionAdminScreen extends StatefulWidget {
  const SectionAdminScreen({super.key});

  @override
  State<SectionAdminScreen> createState() => _SectionAdminScreenState();
}

class _SectionAdminScreenState extends State<SectionAdminScreen> {
  final Map<String, TextEditingController> _titleControllers = {};
  final Map<String, TextEditingController> _subtitleControllers = {};

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final sections = DynamicSectionConfig.getAllSections();
    for (final entry in sections.entries) {
      _titleControllers[entry.key] =
          TextEditingController(text: entry.value.title);
      _subtitleControllers[entry.key] =
          TextEditingController(text: entry.value.subtitle);
    }
  }

  @override
  void dispose() {
    for (final controller in _titleControllers.values) {
      controller.dispose();
    }
    for (final controller in _subtitleControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Section Configuration'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetToDefaults,
            tooltip: 'Reset to defaults',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Section Management',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Update section titles, subtitles, and visibility. Changes will be reflected immediately in the home screen.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section list
          ...DynamicSectionConfig.getAllSections().entries.map((entry) {
            final key = entry.key;
            final config = entry.value;

            return _buildSectionCard(key, config);
          }).toList(),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveAllChanges,
                  icon: const Icon(Icons.save),
                  label: const Text('Save All Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _resetToDefaults,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset to Defaults'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String key, SectionConfig config) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: config.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    key.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: config.isVisible,
                  onChanged: (value) {
                    DynamicSectionConfig.toggleSectionVisibility(key);
                    setState(() {});
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Title field
            TextField(
              controller: _titleControllers[key],
              decoration: const InputDecoration(
                labelText: 'Section Title',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),

            const SizedBox(height: 12),

            // Subtitle field
            TextField(
              controller: _subtitleControllers[key],
              decoration: const InputDecoration(
                labelText: 'Section Subtitle',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),

            const SizedBox(height: 12),

            // Color picker
            Row(
              children: [
                const Text('Color: '),
                GestureDetector(
                  onTap: () => _showColorPicker(key, config.color),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: config.color,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '#${config.color.value.toRadixString(16).substring(2).toUpperCase()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(String key, Color currentColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Color'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              const Text('Select a color for this section:'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Colors.red,
                  Colors.orange,
                  Colors.yellow,
                  Colors.green,
                  Colors.blue,
                  Colors.purple,
                  Colors.pink,
                  Colors.teal,
                  Colors.indigo,
                  Colors.amber,
                  Colors.cyan,
                  Colors.lime,
                ]
                    .map((color) => GestureDetector(
                          onTap: () {
                            DynamicSectionConfig.updateSectionColor(key, color);
                            Navigator.pop(context);
                            setState(() {});
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(8),
                              border: currentColor == color
                                  ? Border.all(color: Colors.black, width: 3)
                                  : null,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _saveAllChanges() {
    // Update all sections with current controller values
    for (final entry in _titleControllers.entries) {
      DynamicSectionConfig.updateSectionTitle(entry.key, entry.value.text);
    }

    for (final entry in _subtitleControllers.entries) {
      DynamicSectionConfig.updateSectionSubtitle(entry.key, entry.value.text);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All changes saved successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _resetToDefaults() {
    DynamicSectionConfig.resetToDefaults();
    _initializeControllers();
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reset to default configuration'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
