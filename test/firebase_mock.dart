import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Callback = void Function(MethodCall call);

Future<void> setupFirebaseMocks([Callback? customHandlers]) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  setupFirebaseCoreMocks();
  
  // Actually initialize Firebase after setting up mocks
  await Firebase.initializeApp();
}

Future<T> neverEndingFuture<T>() async {
  // This is to prevent the test from finishing before the tester.pumpWidget completes
  // See https://github.com/flutter/flutter/issues/88765
  await Future.delayed(const Duration(days: 365));
  throw '';
}

void setupFirebaseCoreMocks() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel(
      'plugins.flutter.io/firebase_core',
    ),
    (methodCall) async {
      if (methodCall.method == 'Firebase#initializeCore') {
        return [
          {
            'name': '[DEFAULT]',
            'options': {
              'apiKey': 'test-api-key',
              'appId': '1:123456789:web:abcdef',
              'messagingSenderId': '123456789',
              'projectId': 'test-project',
            },
            'pluginConstants': {},
          }
        ];
      }

      if (methodCall.method == 'Firebase#initializeApp') {
        return {
          'name': methodCall.arguments['appName'],
          'options': methodCall.arguments['options'],
          'pluginConstants': {},
        };
      }

      return null;
    },
  );
}

void setupFirebaseAuthMocks() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/firebase_auth'),
    (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'Auth#registerIdTokenListener':
          return {
            'user': null,
          };
        case 'Auth#registerChangeListener':
          return {
            'user': null,
          };
        default:
          return null;
      }
    },
  );
}

void setupFirebaseFirestoreMocks() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/cloud_firestore'),
    (MethodCall methodCall) async {
      return null;
    },
  );
}

void setupFirebaseStorageMocks() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/firebase_storage'),
    (MethodCall methodCall) async {
      return null;
    },
  );
}

void setupFirebaseAnalyticsMocks() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/firebase_analytics'),
    (MethodCall methodCall) async {
      return null;
    },
  );
}