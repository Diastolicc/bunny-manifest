import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../web_admin/screens/web_admin_login.dart';
import '../web_admin/screens/web_admin_dashboard.dart';

final GoRouter webAdminRouter = GoRouter(
  initialLocation: '/admin/login',
  routes: [
    GoRoute(
      path: '/admin/login',
      pageBuilder: (context, state) => MaterialPage(
        child: WebAdminLoginScreen(),
      ),
    ),
    GoRoute(
      path: '/admin/dashboard',
      pageBuilder: (context, state) => MaterialPage(
        child: WebAdminDashboardScreen(),
      ),
    ),
  ],
);
