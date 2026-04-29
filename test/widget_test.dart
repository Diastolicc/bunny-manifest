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
    
    // Just pump once to trigger the first build
    await tester.pump();

    // If we got here without throwing, the app launched successfully!
    expect(true, true);
  });
}