import 'package:flutter/material.dart';
import 'dart:ui' show PointerDeviceKind;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bunny/providers/app_providers.dart';
import 'package:bunny/router/app_router.dart';
import 'package:bunny/config/firebase_config.dart';
import 'package:bunny/theme/app_theme.dart';
import 'package:bunny/services/auth_service.dart';
import 'package:bunny/services/chat_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await FirebaseConfig.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: buildAppProviders(),
      child: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      final authService = context.read<AuthService>();

      // Wait a moment for the auth state to be properly initialized
      await Future.delayed(const Duration(milliseconds: 100));

      // Check if user is already authenticated (persistent session)
      if (authService.isAuthenticated) {
        print('User already authenticated: ${authService.currentUser?.id}');
        print('Current user name: ${authService.currentUser?.displayName}');
        print('Is guest: ${authService.isGuest}');
      } else {
        // Only create a new guest user if no existing session
        print('No existing session, creating new Guest user...');
        await authService.signInAnonymously();
      }
      // Add a test chat group for UI testing
      final chatService = context.read<ChatService>();
      await chatService.createTestChatGroup();
    } catch (e) {
      print('Error during auth initialization: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: AppTheme.colors.background,
          body: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
          PointerDeviceKind.unknown,
        },
      ),
      child: MaterialApp.router(
        title: 'Bunny',
        theme: ThemeData(
          brightness: Brightness.light,
          colorScheme: ColorScheme.light(
            primary: AppTheme.colors.primary,
            secondary: AppTheme.colors.secondary,
            surface: AppTheme.colors.surface,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: AppTheme.colors.text,
          ),
          scaffoldBackgroundColor: AppTheme.colors.background,
          useMaterial3: true,
          // Additional theme customizations
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.colors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: AppTheme.colors.shadow,
            ),
          ),
          cardTheme: CardThemeData(
            color: AppTheme.colors.card,
            elevation: 2,
            shadowColor: AppTheme.colors.shadow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          textTheme: GoogleFonts.poppinsTextTheme().copyWith(
            headlineLarge: GoogleFonts.poppins(
              color: AppTheme.colors.text,
              fontWeight: FontWeight.w900,
              fontSize: 32,
            ),
            headlineMedium: GoogleFonts.poppins(
              color: AppTheme.colors.text,
              fontWeight: FontWeight.w800,
              fontSize: 28,
            ),
            headlineSmall: GoogleFonts.poppins(
              color: AppTheme.colors.text,
              fontWeight: FontWeight.w800,
              fontSize: 24,
            ),
            titleLarge: GoogleFonts.poppins(
              color: AppTheme.colors.text,
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
            titleMedium: GoogleFonts.poppins(
              color: AppTheme.colors.text,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
            titleSmall: GoogleFonts.poppins(
              color: AppTheme.colors.text,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            bodyLarge: GoogleFonts.poppins(
              color: AppTheme.colors.text,
              fontWeight: FontWeight.w400,
            ),
            bodyMedium: GoogleFonts.poppins(
              color: AppTheme.colors.text,
              fontWeight: FontWeight.w400,
            ),
            bodySmall: GoogleFonts.poppins(
              color: AppTheme.colors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        routerConfig: appRouter,
      ),
    );
  }
}
