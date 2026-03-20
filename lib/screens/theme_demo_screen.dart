import 'package:flutter/material.dart';
import 'package:bunny/theme/app_theme.dart';

class ThemeDemoScreen extends StatelessWidget {
  const ThemeDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.colors.background,
      appBar: AppBar(
        title: Text(
          'Theme Demo - ${AppTheme.currentTheme.name.toUpperCase()}',
          style: TextStyle(color: AppTheme.colors.surface),
        ),
        backgroundColor: AppTheme.colors.primary,
        foregroundColor: AppTheme.colors.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Theme: ${AppTheme.currentTheme.name.toUpperCase()}',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppTheme.colors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'To change themes, edit this line in lib/theme/app_theme.dart:',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.colors.backgroundLight,
                        border: Border.all(color: AppTheme.colors.cardBorder),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'static const ThemeMode _currentTheme = ThemeMode.pink;',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: AppTheme.colors.text,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Available Themes
            Text(
              'Available Themes:',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.colors.text,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: AppTheme.availableThemes.map((theme) {
                final isCurrent = theme == AppTheme.currentTheme;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? AppTheme.colors.primary
                        : AppTheme.colors.card,
                    border: Border.all(
                      color: isCurrent
                          ? AppTheme.colors.primary
                          : AppTheme.colors.cardBorder,
                      width: isCurrent ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    theme.name.toUpperCase(),
                    style: TextStyle(
                      color: isCurrent
                          ? AppTheme.colors.surface
                          : AppTheme.colors.text,
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 30),

            // Color Palette Demo
            Text(
              'Color Palette:',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.colors.text,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),

            _buildColorPalette(),

            const SizedBox(height: 30),

            // UI Components Demo
            Text(
              'UI Components:',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.colors.text,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),

            _buildUIComponents(),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPalette() {
    return Column(
      children: [
        _buildColorRow('Primary', AppTheme.colors.primary),
        _buildColorRow('Secondary', AppTheme.colors.secondary),
        _buildColorRow('Accent', AppTheme.colors.accent),
        _buildColorRow('Background', AppTheme.colors.background),
        _buildColorRow('Surface', AppTheme.colors.surface),
        _buildColorRow('Text', AppTheme.colors.text),
        _buildColorRow('Text Secondary', AppTheme.colors.textSecondary),
        _buildColorRow('Success', AppTheme.colors.success),
        _buildColorRow('Warning', AppTheme.colors.warning),
        _buildColorRow('Error', AppTheme.colors.error),
      ],
    );
  }

  Widget _buildColorRow(String name, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.colors.cardBorder),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: AppTheme.colors.text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
            style: TextStyle(
              color: AppTheme.colors.textSecondary,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUIComponents() {
    return Builder(
      builder: (context) => Column(
        children: [
          // Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Primary Button'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  child: const Text('Outlined Button'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Cards
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sample Card',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This card demonstrates the current theme colors and styling.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Text Styles
          Text(
            'Headline Large',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          Text(
            'Headline Medium',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text(
            'Title Large',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            'Body Medium',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            'Body Small (Secondary)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
