import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/firebase_config.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/club_service.dart';
import '../services/party_service.dart';
import '../services/chat_service.dart';
import '../router/web_admin_router.dart';
import '../theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const WebAdminApp());
}

class WebAdminApp extends StatelessWidget {
  const WebAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => AuthService()),
        Provider(create: (_) => UserService()),
        Provider(create: (_) => ClubService()),
        Provider(create: (_) => PartyService()),
        Provider(create: (_) => ChatService()),
      ],
      child: MaterialApp.router(
        title: 'Club Reservation Admin Panel',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.colors.primary),
          useMaterial3: true,
        ),
        routerConfig: webAdminRouter,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
