import 'package:flutter/material.dart';
import 'package:bunny/theme/app_theme.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.colors.primary,
        title: const Text(
          'Map',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: const Center(
        child: Text(
          'Map coming soon',
          style: TextStyle(color: Colors.black87, fontSize: 18),
        ),
      ),
    );
  }
}
