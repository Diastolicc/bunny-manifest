import 'package:flutter/material.dart';
import 'package:bunny/screens/club_detail_screen.dart';
import 'package:bunny/screens/create_party_screen.dart';
import 'package:bunny/screens/email_settings_screen.dart';
import 'package:bunny/screens/admin_settings_screen.dart';
import 'package:bunny/screens/favorites_screen.dart';
import 'package:bunny/screens/help_screen.dart';
import 'package:bunny/screens/home_screen.dart';
import 'package:bunny/screens/login_screen.dart';
import 'package:bunny/screens/my_parties_screen.dart';
import 'package:bunny/screens/map_screen.dart';
import 'package:bunny/screens/party_details_screen.dart';
import 'package:bunny/screens/profile_screen.dart';
import 'package:bunny/screens/request_feature_screen.dart';
import 'package:bunny/screens/chat_screen.dart';
import 'package:bunny/screens/chat_room_screen.dart';
import 'package:bunny/screens/intro_screen.dart';
import 'package:bunny/screens/party_invite_screen.dart';
import 'package:bunny/screens/participants_screen.dart';
import 'package:bunny/screens/splash_screen.dart';
import 'package:bunny/screens/view_all_parties_screen.dart';
import 'package:bunny/screens/view_all_venues_screen.dart';
import 'package:bunny/screens/api_test_screen.dart';
import 'package:bunny/screens/party_ticket_screen.dart';
import 'package:bunny/screens/user_profile_view_screen.dart';
import 'package:bunny/screens/activity_screen.dart';
import 'package:bunny/widgets/root_scaffold.dart';
import 'package:bunny/services/party_service.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/splash',
      builder: (context, state) {
        print('Router: Navigating to splash screen');
        return const SplashScreen();
      },
    ),
    GoRoute(
      path: '/party-details',
      builder: (context, state) {
        final String partyId = state.uri.queryParameters['id'] ?? '';
        print('Router: Navigating to party details for partyId: $partyId');
        if (partyId.isEmpty) {
          return const Scaffold(
            body: Center(
              child: Text('Party ID not provided'),
            ),
          );
        }
        return _PartyDetailsWrapper(partyId: partyId);
      },
    ),
    GoRoute(
      path: '/party-ticket',
      builder: (context, state) {
        final String partyId = state.uri.queryParameters['id'] ?? '';
        print('Router: Navigating to party ticket for partyId: $partyId');
        if (partyId.isEmpty) {
          return const Scaffold(
            body: Center(
              child: Text('Party ID not provided'),
            ),
          );
        }
        return PartyTicketScreen(partyId: partyId);
      },
    ),
    GoRoute(
      path: '/intro',
      builder: (context, state) => const IntroScreen(),
    ),
    GoRoute(
      path: '/participants/:partyId',
      builder: (context, state) {
        final String partyId = state.pathParameters['partyId']!;
        return ParticipantsScreen(partyId: partyId);
      },
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    // Club detail screen without navigation bar
    GoRoute(
      path: '/club/:id',
      builder: (context, state) {
        final String id = state.pathParameters['id']!;
        return ClubDetailScreen(clubId: id);
      },
    ),
    GoRoute(
      path: '/create-party',
      builder: (context, state) {
        final bool isEdit = state.uri.queryParameters['edit'] == 'true';
        final String? partyId = state.uri.queryParameters['partyId'];
        return CreatePartyScreen(
          isEdit: isEdit,
          partyId: partyId,
        );
      },
    ),
    GoRoute(
      path: '/create-party/:clubId',
      builder: (context, state) {
        final String clubId = state.pathParameters['clubId']!;
        return CreatePartyScreen(clubId: clubId);
      },
    ),
    GoRoute(
      path: '/view-all-parties',
      builder: (context, state) => const ViewAllPartiesScreen(),
    ),
    GoRoute(
      path: '/view-all-venues',
      builder: (context, state) => const ViewAllVenuesScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => RootScaffold(child: child),
      routes: <GoRoute>[
        GoRoute(
          path: '/',
          pageBuilder: (context, state) {
            final String? scrollToClubId =
                state.uri.queryParameters['scrollToClub'];
            print('Router: Home route with scrollToClubId: $scrollToClubId');
            print('Router: Full URI: ${state.uri}');
            return NoTransitionPage(
                child: HomeScreen(scrollToClubId: scrollToClubId));
          },
          routes: <GoRoute>[
            GoRoute(
              path: 'my-parties',
              builder: (context, state) => const MyPartiesScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/map',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: MapScreen()),
        ),
        GoRoute(
          path: '/parties',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: MyPartiesScreen()),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProfileScreen()),
        ),
        GoRoute(
          path: '/chat',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ChatScreen()),
        ),
        GoRoute(
          path: '/activity',
          builder: (context, state) => const ActivityScreen(),
        ),
      ],
    ),
    // Fullscreen chat room without navbar
    GoRoute(
      path: '/chat/room/:groupId',
      builder: (context, state) {
        final String groupId = state.pathParameters['groupId']!;
        return ChatRoomScreen(groupId: groupId);
      },
    ),
    // User profile view (outside shell for navigation from chat room)
    GoRoute(
      path: '/user-profile/:userId',
      builder: (context, state) {
        final String userId = state.pathParameters['userId']!;
        print('Router: Navigating to user profile for userId: $userId');
        return UserProfileViewScreen(userId: userId);
      },
    ),
    // Party invite screen
    GoRoute(
      path: '/party-invite/:partyId',
      builder: (context, state) {
        final String partyId = state.pathParameters['partyId']!;
        return _PartyInviteWrapper(partyId: partyId);
      },
    ),
    // Settings pages
    GoRoute(
      path: '/email-settings',
      builder: (context, state) => const EmailSettingsScreen(),
    ),
    GoRoute(
      path: '/admin-settings',
      builder: (context, state) => const AdminSettingsScreen(),
    ),
    GoRoute(
      path: '/favorites',
      builder: (context, state) => const FavoritesScreen(),
    ),
    GoRoute(
      path: '/request-feature',
      builder: (context, state) => const RequestFeatureScreen(),
    ),
    GoRoute(
      path: '/help',
      builder: (context, state) => const HelpScreen(),
    ),
    GoRoute(
      path: '/api-test',
      builder: (context, state) => const ApiTestScreen(),
    ),
  ],
);

class _PartyDetailsWrapper extends StatelessWidget {
  final String partyId;

  const _PartyDetailsWrapper({required this.partyId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: context.read<PartyService>().getById(partyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: Text('Party not found'),
            ),
          );
        }

        return PartyDetailsScreen(party: snapshot.data!);
      },
    );
  }
}

class _PartyInviteWrapper extends StatelessWidget {
  final String partyId;

  const _PartyInviteWrapper({required this.partyId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: context.read<PartyService>().getById(partyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: Text('Party not found'),
            ),
          );
        }

        return PartyInviteScreen(party: snapshot.data!);
      },
    );
  }
}
