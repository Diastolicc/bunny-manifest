import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:go_router/go_router.dart';
import 'package:bunny/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/home_screen.dart';
import '../screens/my_parties_screen.dart';
import '../screens/create_party_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/chat_screen.dart';
import '../services/auth_service.dart';

class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key, required this.child});
  final Widget child;

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  int _currentIndex = 0;

  Future<void> _showCreatePartyAuthPrompt() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Login Required'),
          content: const Text(
            'You need to be logged in to create a party. Please log in or create an account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Not Now'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.push('/login');
              },
              child: const Text('Log In / Create Account'),
            ),
          ],
        );
      },
    );
  }

  int _locationToIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/parties')) return 1;
    if (location.startsWith('/create-party')) return 2;
    if (location.startsWith('/chat')) return 3;
    if (location.startsWith('/profile')) return 4;
    if (location == '/' || location.startsWith('/?')) return 0;

    // Non-tab routes (e.g., /activity) return -1 so we render the provided child.
    return -1;
  }

  void _onTap(BuildContext context, int index) {
    // Special handling for Create Party (index 2) - show as full-screen overlay instead
    if (index == 2) {
      final authService = context.read<AuthService>();
      final isLoggedOut =
          authService.currentUser == null || authService.isGuest;
      if (isLoggedOut) {
        _showCreatePartyAuthPrompt();
        return;
      }

      showGeneralDialog(
        context: context,
        pageBuilder: (context, animation, secondaryAnimation) {
          return const CreatePartyScreen(isOverlay: true);
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) =>
            child,
        transitionDuration: Duration.zero,
      );
      return;
    }

    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });

      // Also update the route for deep link compatibility
      switch (index) {
        case 0:
          context.go('/');
          break;
        case 1:
          context.go('/parties');
          break;
        case 2:
          context.go('/create-party');
          break;
        case 3:
          context.go('/chat');
          break;
        case 4:
          context.go('/profile');
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int routeIndex = _locationToIndex(context);

    // Update current index if route changed and it's a tab route
    if (routeIndex != -1 && routeIndex != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentIndex = routeIndex;
          });
        }
      });
    }

    return Scaffold(
      extendBody: true,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: null,
      body: Stack(
        children: [
          // Keep tab stack mounted so HomeScreen state persists when overlay routes (e.g., Activity) are shown.
          IndexedStack(
            index: _currentIndex,
            children: [
              // Home Screen
              Builder(
                builder: (context) {
                  final String? scrollToClubId = GoRouterState.of(context)
                      .uri
                      .queryParameters['scrollToClub'];
                  return HomeScreen(scrollToClubId: scrollToClubId);
                },
              ),
              // My Parties Screen
              const MyPartiesScreen(),
              // Create Party Screen
              Builder(
                builder: (context) {
                  return const CreatePartyScreen();
                },
              ),
              // Chat Screen
              const ChatScreen(),
              // Profile Screen
              const ProfileScreen(),
            ],
          ),
          if (routeIndex == -1)
            Positioned.fill(
              child: widget.child,
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withOpacity(0.92),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.colors.primary.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Full-height segment background for active destination
                  Positioned.fill(
                    child: Row(
                      children: List<Widget>.generate(5, (int i) {
                        final bool isActive = i == _currentIndex;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 7,
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                              decoration: isActive
                                  ? BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppTheme.colors.primary,
                                          AppTheme.colors.secondary,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.colors.primary
                                              .withOpacity(0.22),
                                          blurRadius: 18,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    )
                                  : const BoxDecoration(
                                      color: Colors.transparent,
                                    ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  Theme(
                    data: Theme.of(context).copyWith(
                      navigationBarTheme: NavigationBarThemeData(
                        backgroundColor: Colors.transparent,
                        labelTextStyle:
                            WidgetStateProperty.resolveWith<TextStyle?>(
                          (Set<WidgetState> states) {
                            if (states.contains(WidgetState.selected)) {
                              return const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              );
                            }
                            return TextStyle(
                              color: AppTheme.colors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            );
                          },
                        ),
                      ),
                    ),
                    child: NavigationBar(
                      backgroundColor: Colors.transparent,
                      height: 64,
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysHide,
                      indicatorColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      selectedIndex: _currentIndex,
                      onDestinationSelected: (int i) => _onTap(context, i),
                      destinations: <NavigationDestination>[
                        NavigationDestination(
                            icon: Icon(Icons.home_outlined,
                                color: AppTheme.colors.text,
                                size: 23,
                                weight: 600),
                            selectedIcon: Icon(Icons.home,
                                color: Colors.white, size: 23, weight: 700),
                            label: 'Home'),
                        NavigationDestination(
                            icon: Icon(Icons.confirmation_number_outlined,
                                color: AppTheme.colors.text,
                                size: 23,
                                weight: 600),
                            selectedIcon: Icon(Icons.confirmation_number,
                                color: Colors.white, size: 23, weight: 700),
                            label: 'Parties'),
                        NavigationDestination(
                            icon: _AnimatedPlusButton(isSelected: false),
                            selectedIcon: _AnimatedPlusButton(isSelected: true),
                            label: 'Create'),
                        NavigationDestination(
                            icon: _ChatIconWithBadge(isSelected: false),
                            selectedIcon: _ChatIconWithBadge(isSelected: true),
                            label: 'Chat'),
                        NavigationDestination(
                            icon: Icon(Icons.person_outline,
                                color: AppTheme.colors.text,
                                size: 23,
                                weight: 600),
                            selectedIcon: Icon(Icons.person,
                                color: Colors.white, size: 23, weight: 700),
                            label: 'Profile'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedPlusButton extends StatefulWidget {
  final bool isSelected;

  const _AnimatedPlusButton({required this.isSelected});

  @override
  State<_AnimatedPlusButton> createState() => _AnimatedPlusButtonState();
}

class _AnimatedPlusButtonState extends State<_AnimatedPlusButton>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _wiggleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
    _wiggleAnimation = Tween<double>(begin: -0.18, end: 0.18)
        .animate(CurvedAnimation(parent: _controller!, curve: Curves.linear));
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_wiggleAnimation == null) {
      return Container(
        width: 80,
        height: 80,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
        ),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Image.asset(
            'assets/logos/bunny_logo.png',
            fit: BoxFit.contain,
          ),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, child) {
        final double angle = 0.18 * math.sin(_controller!.value * 2 * math.pi);
        return Transform.rotate(
          angle: angle,
          child: Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
            ),
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Image.asset(
                'assets/logos/bunny_logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChatIconWithBadge extends StatelessWidget {
  final bool isSelected;

  const _ChatIconWithBadge({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;

    if (currentUser == null) {
      return Icon(
        isSelected ? Icons.chat_bubble : Icons.chat_bubble_outline,
        color: isSelected ? Colors.white : const Color(0xFF374151),
        size: 26,
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_groups')
          .where('memberIds', arrayContains: currentUser.id)
          .snapshots(),
      builder: (context, snapshot) {
        int totalUnread = 0;
        List<String> groupsNeedingMigration = [];

        if (snapshot.hasData) {
          // Calculate synchronously from unreadByUser field
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final unreadByUser = data['unreadByUser'] as Map<String, dynamic>?;

            if (unreadByUser != null &&
                unreadByUser.containsKey(currentUser.id)) {
              // Fast path: use existing unreadByUser field
              final userUnread = unreadByUser[currentUser.id];
              if (userUnread is num) {
                totalUnread += userUnread.toInt();
              }
            } else {
              // Mark for migration, but don't block UI
              groupsNeedingMigration.add(doc.id);
            }
          }

          // Trigger migrations asynchronously in background
          if (groupsNeedingMigration.isNotEmpty) {
            _migrateGroupsInBackground(groupsNeedingMigration, currentUser.id);
          }
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              isSelected ? Icons.chat_bubble : Icons.chat_bubble_outline,
              color: isSelected ? Colors.white : const Color(0xFF374151),
              size: 26,
            ),
            if (totalUnread > 0)
              Positioned(
                right: -8,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white,
                      width: 1.5,
                    ),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    totalUnread > 99 ? '99+' : '$totalUnread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _migrateGroupsInBackground(List<String> groupIds, String userId) {
    // Run migration in background without blocking UI
    Future.microtask(() async {
      for (final groupId in groupIds) {
        try {
          final groupDoc = await FirebaseFirestore.instance
              .collection('chat_groups')
              .doc(groupId)
              .get();

          if (!groupDoc.exists) return;

          final data = groupDoc.data()!;
          final unreadByUser = data['unreadByUser'] as Map<String, dynamic>?;

          // Only migrate if field doesn't exist
          if (unreadByUser == null || !unreadByUser.containsKey(userId)) {
            print('Migrating chat group $groupId in background');

            final messagesSnapshot = await FirebaseFirestore.instance
                .collection('chat_groups')
                .doc(groupId)
                .collection('messages')
                .get();

            final memberIds = List<String>.from(data['memberIds'] ?? []);
            final newUnreadByUser = Map<String, int>.from(unreadByUser ?? {});

            for (final memberId in memberIds) {
              int unreadCount = 0;
              for (var msgDoc in messagesSnapshot.docs) {
                final msgData = msgDoc.data();
                final readBy = List<String>.from(
                    msgData['readBy'] as List<dynamic>? ?? []);
                final isRead = msgData['isRead'] as bool? ?? false;

                if (!readBy.contains(memberId) && !isRead) {
                  unreadCount++;
                }
              }
              newUnreadByUser[memberId] = unreadCount;
            }

            await FirebaseFirestore.instance
                .collection('chat_groups')
                .doc(groupId)
                .update({
              'unreadByUser': newUnreadByUser,
            });

            print('Successfully migrated chat group $groupId in background');
          }
        } catch (e) {
          print('Error migrating group $groupId: $e');
        }
      }
    });
  }
}
