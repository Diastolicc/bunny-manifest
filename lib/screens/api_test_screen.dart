import 'package:flutter/material.dart';
import 'package:bunny/services/api_test_service.dart';
import 'package:bunny/theme/app_theme.dart';

class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _testResults;
  String _statusMessage = 'Ready to test API';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Test'),
        backgroundColor: AppTheme.colors.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.colors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.colors.primary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Google Places API Test',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.colors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This will test your Google Places API configuration and connectivity.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Test Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _runApiTest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.colors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Testing API...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Run API Test',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // Status Message
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getStatusColor()),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(),
                    color: _getStatusColor(),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _getStatusColor(),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_testResults != null) ...[
              const SizedBox(height: 24),

              // Test Results
              Text(
                'Test Results',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildTestResultCard(
                        'Basic Connectivity',
                        _testResults!['connectivity'],
                        Icons.wifi,
                      ),
                      const SizedBox(height: 12),
                      _buildTestResultCard(
                        'Nightlife Search',
                        _testResults!['nightlife_search'],
                        Icons.nightlife,
                      ),
                      const SizedBox(height: 12),
                      _buildTestResultCard(
                        'Autocomplete',
                        _testResults!['autocomplete'],
                        Icons.search,
                      ),
                      const SizedBox(height: 12),
                      _buildTestResultCard(
                        'Overall Result',
                        _testResults!['summary'],
                        Icons.check_circle,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTestResultCard(
      String title, Map<String, dynamic> result, IconData icon) {
    final isSuccess = result['success'] == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSuccess
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSuccess ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: isSuccess ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isSuccess ? Colors.green : Colors.red,
                ),
              ),
              const Spacer(),
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? Colors.green : Colors.red,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            result['message'] ?? 'No message',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
          if (result['results_count'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Results: ${result['results_count']}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
          if (result['venues_found'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Venues: ${result['venues_found']}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
          if (result['suggestions_found'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Suggestions: ${result['suggestions_found']}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (_isLoading) return Colors.blue;
    if (_testResults != null) {
      return _testResults!['overall_success'] == true
          ? Colors.green
          : Colors.red;
    }
    return Colors.grey;
  }

  IconData _getStatusIcon() {
    if (_isLoading) return Icons.hourglass_empty;
    if (_testResults != null) {
      return _testResults!['overall_success'] == true
          ? Icons.check_circle
          : Icons.error;
    }
    return Icons.info;
  }

  Future<void> _runApiTest() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Running API tests...';
    });

    try {
      final results = await ApiTestService.runComprehensiveTest();

      setState(() {
        _testResults = results;
        _isLoading = false;
        _statusMessage = results['overall_success'] == true
            ? 'All tests passed! API is working correctly.'
            : 'Some tests failed. Check results below.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error running tests: $e';
      });
    }
  }
}
