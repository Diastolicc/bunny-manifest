import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// Fake Firebase implementation for testing
class FakeFirebasePlatform extends FirebasePlatform {
  FakeFirebasePlatform() : super();

  static const FirebaseOptions _testOptions = FirebaseOptions(
    apiKey: 'test-api-key',
    appId: '1:123456789:web:abcdef',
    messagingSenderId: '123456789',
    projectId: 'test-project',
  );

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return FakeFirebaseAppPlatform(name, _testOptions);
  }

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return FakeFirebaseAppPlatform(name ?? defaultFirebaseAppName, options ?? _testOptions);
  }

  @override
  List<FirebaseAppPlatform> get apps {
    return [FakeFirebaseAppPlatform(defaultFirebaseAppName, _testOptions)];
  }
}

class FakeFirebaseAppPlatform extends FirebaseAppPlatform {
  FakeFirebaseAppPlatform(String name, FirebaseOptions options)
      : super(name, options);

  @override
  Future<void> delete() async {}

  @override
  Future<void> setAutomaticDataCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setAutomaticResourceManagementEnabled(bool enabled) async {}

  @override
  bool get isAutomaticDataCollectionEnabled => false;
}

void setupFirebaseMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Register the fake Firebase platform
  FirebasePlatform.instance = FakeFirebasePlatform();
}