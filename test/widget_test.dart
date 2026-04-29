import 'package:flutter_test/flutter_test.dart';
import 'package:bunny/main.dart';
import 'firebase_mock.dart';

void main() {
  // Setup Firebase mocks before all tests run
  setUpAll(() {
    setupFirebaseMocks();
  });

  testWidgets('App launches without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    
    // Wait for the app to settle (finish loading)
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // If we got here without throwing, the app launched successfully!
    expect(true, true);
  });
}