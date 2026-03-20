import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bunny/theme/app_theme.dart';
import 'package:bunny/services/auth_service.dart';
import 'package:bunny/screens/admin_manage_clubs_screen.dart';
import 'package:bunny/screens/admin_manage_banners_screen.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.colors.background,
      appBar: AppBar(
        backgroundColor: AppTheme.colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.colors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Admin Settings',
          style: TextStyle(
            color: AppTheme.colors.text,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Admin Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.colors.primary.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.admin_panel_settings,
                          color: AppTheme.colors.primary,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Admin Access',
                                style: TextStyle(
                                  color: AppTheme.colors.text,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.displayName ?? 'Admin User',
                                style: TextStyle(
                                  color: AppTheme.colors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Admin Actions Section
              Text(
                'Admin Actions',
                style: TextStyle(
                  color: AppTheme.colors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: AppTheme.colors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _buildAdminMenuItem(
                      icon: Icons.people,
                      title: 'Manage Users',
                      subtitle: 'View and manage user accounts',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('User Management - Coming Soon'),
                          ),
                        );
                      },
                    ),
                    Divider(
                      height: 1,
                      color: AppTheme.colors.textSecondary.withOpacity(0.2),
                      indent: 60,
                    ),
                    _buildAdminMenuItem(
                      icon: Icons.verified_user,
                      title: 'Verification Requests',
                      subtitle: 'Review pending verification applications',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Verification Management - Coming Soon'),
                          ),
                        );
                      },
                    ),
                    Divider(
                      height: 1,
                      color: AppTheme.colors.textSecondary.withOpacity(0.2),
                      indent: 60,
                    ),
                    _buildAdminMenuItem(
                      icon: Icons.party_mode,
                      title: 'Manage Parties',
                      subtitle: 'View and moderate all parties',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Party Management - Coming Soon'),
                          ),
                        );
                      },
                    ),
                    Divider(
                      height: 1,
                      color: AppTheme.colors.textSecondary.withOpacity(0.2),
                      indent: 60,
                    ),
                    _buildAdminMenuItem(
                      icon: Icons.location_city,
                      title: 'Manage Clubs',
                      subtitle: 'Add, edit, or remove clubs',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminManageClubsScreen(),
                          ),
                        );
                      },
                    ),
                    Divider(
                      height: 1,
                      color: AppTheme.colors.textSecondary.withOpacity(0.2),
                      indent: 60,
                    ),
                    _buildAdminMenuItem(
                      icon: Icons.image,
                      title: 'Manage Banners',
                      subtitle: 'Update home screen banner images',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminManageBannersScreen(),
                          ),
                        );
                      },
                    ),
                    Divider(
                      height: 1,
                      color: AppTheme.colors.textSecondary.withOpacity(0.2),
                      indent: 60,
                    ),
                    _buildAdminMenuItem(
                      icon: Icons.report,
                      title: 'Reports & Moderation',
                      subtitle: 'Review user reports and take action',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Reports Management - Coming Soon'),
                          ),
                        );
                      },
                    ),
                    Divider(
                      height: 1,
                      color: AppTheme.colors.textSecondary.withOpacity(0.2),
                      indent: 60,
                    ),
                    _buildAdminMenuItem(
                      icon: Icons.analytics,
                      title: 'Analytics',
                      subtitle: 'View app statistics and insights',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Analytics - Coming Soon'),
                          ),
                        );
                      },
                      isLast: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // System Section
              Text(
                'System',
                style: TextStyle(
                  color: AppTheme.colors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: AppTheme.colors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _buildAdminMenuItem(
                      icon: Icons.notifications,
                      title: 'Send Notifications',
                      subtitle: 'Send push notifications to users',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Notifications - Coming Soon'),
                          ),
                        );
                      },
                    ),
                    Divider(
                      height: 1,
                      color: AppTheme.colors.textSecondary.withOpacity(0.2),
                      indent: 60,
                    ),
                    _buildAdminMenuItem(
                      icon: Icons.settings,
                      title: 'App Configuration',
                      subtitle: 'Manage app-wide settings',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Configuration - Coming Soon'),
                          ),
                        );
                      },
                      isLast: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: isLast ? Radius.zero : const Radius.circular(20),
          bottom: isLast ? const Radius.circular(20) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.colors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.colors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppTheme.colors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppTheme.colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppTheme.colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
