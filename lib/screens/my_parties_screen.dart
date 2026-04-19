import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bunny/models/party.dart';
import 'package:bunny/services/auth_service.dart';
import 'package:bunny/services/party_service.dart';
import 'package:bunny/services/user_service.dart';
import 'package:bunny/services/club_service.dart';
import 'package:bunny/services/chat_service.dart';
import 'package:bunny/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'manage_party_screen.dart';

class MyPartiesScreen extends StatefulWidget {
  const MyPartiesScreen({super.key});

  @override
  State<MyPartiesScreen> createState() => _MyPartiesScreenState();
}

class _MyPartiesScreenState extends State<MyPartiesScreen>
    with SingleTickerProviderStateMixin {
  static const double _toggleRadius = 36;
  String _selectedFilter = 'upcoming'; // upcoming, ongoing, past
  bool _isHostView = false; // false = Joiner, true = Host
  List<Party> _parties = [];
  bool _isLoading = true;
  ScrollController _scrollController = ScrollController();
  bool _isHeroCollapsed = false;
  bool _hasRequestedInitialLoad = false;
  late TabController _tabController;

  void _handleAuthChange() {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;

    // Trigger initial load only after the profile is available to avoid a premature empty state
    if (user != null && !_hasRequestedInitialLoad) {
      _hasRequestedInitialLoad = true;
      _loadParties();
    }

    // Clear state if the user signs out so a future sign-in can reload
    if (user == null && _hasRequestedInitialLoad) {
      _hasRequestedInitialLoad = false;
      if (mounted) {
        setState(() {
          _parties = [];
          _isLoading = false;
        });
      }
    }
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    final bool nextIsHost = _tabController.index == 1;
    if (nextIsHost != _isHostView) {
      setState(() {
        _isHostView = nextIsHost;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    // Wait for AuthService to deliver the user profile before loading parties
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthService>().addListener(_handleAuthChange);
      _handleAuthChange();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    context.read<AuthService>().removeListener(_handleAuthChange);
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final shouldCollapse = _scrollController.offset > 72;
      if (_isHeroCollapsed != shouldCollapse) {
        setState(() {
          _isHeroCollapsed = shouldCollapse;
        });
      }
    }
  }

  Future<void> _loadParties() async {
    print('\n🎯 _loadParties() CALLED');
    setState(() {
      _isLoading = true;
    });

    try {
      print('   Getting AuthService...');
      final auth = context.read<AuthService>();
      final currentUser = auth.currentUser;
      print('   Current user: ${currentUser?.id}');
      print('   Current user name: ${currentUser?.displayName}');

      if (currentUser == null) {
        print(
            '   ⚠️ Current user is NULL! Waiting for profile before loading parties...');
        if (!mounted) return;
        setState(() {
          // Keep spinner up if Firebase user exists but profile not yet loaded
          _isLoading = auth.firebaseUser != null;
        });
        return;
      }

      print('   Calling PartyService.listByUser(${currentUser.id})...');
      final partyService = context.read<PartyService>();
      final parties = await partyService.listByUser(currentUser.id);

      // Debug: Print party details to identify duplicates
      print('=== MY PARTIES DEBUG ===');
      print('Total parties loaded: ${parties.length}');
      for (int i = 0; i < parties.length; i++) {
        final party = parties[i];
        print(
            'Party $i: ID=${party.id}, Title="${party.title}", Host=${party.hostUserId}, Attendees=${party.attendeeUserIds}');
      }
      print('========================');
      if (!mounted) return;
      setState(() {
        _parties = parties;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('❌ Error loading parties: $e');
      print('Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Party> _filterParties(List<Party> parties) {
    // First filter by host/joiner
    final auth = context.read<AuthService>();
    final currentUser = auth.currentUser;
    if (currentUser == null) return [];

    print('=== FILTER DEBUG ===');
    print('Filtering ${parties.length} parties');
    print('IsHostView: $_isHostView');
    print('SelectedFilter: $_selectedFilter');
    print('CurrentUser: ${currentUser.id}');
    print('CurrentUser DisplayName: ${currentUser.displayName}');

    final filteredByRole = parties.where((party) {
      final isHost = party.hostUserId == currentUser.id;
      final isAttendee = party.attendeeUserIds.contains(currentUser.id);

      print('---');
      print('Party: ${party.title}');
      print('  PartyId: ${party.id}');
      print('  HostUserId: ${party.hostUserId}');
      print('  AttendeeUserIds: ${party.attendeeUserIds}');
      print('  AttendeeCount: ${party.attendeeUserIds.length}');
      print('  IsHost: $isHost');
      print('  IsAttendee: $isAttendee');
      print('  DateTime: ${party.dateTime}');
      print('  Status: ${_getPartyStatus(party)}');

      bool shouldShow;
      if (_isHostView) {
        // Show parties where user is the host
        shouldShow = isHost;
      } else {
        // Show parties where user is attending but NOT hosting
        shouldShow = isAttendee && !isHost;
      }

      print(
          '  ShouldShow in ${_isHostView ? "HOST" : "JOINER"} view: $shouldShow');

      return shouldShow;
    }).toList();

    print('After role filter: ${filteredByRole.length} parties');

    final now = DateTime.now();
    List<Party> finalFiltered;

    switch (_selectedFilter) {
      case 'upcoming':
        finalFiltered = filteredByRole
            .where((party) => party.dateTime.isAfter(now))
            .toList();
        print('After UPCOMING time filter: ${finalFiltered.length} parties');
        break;
      case 'ongoing':
        final startTime = now.subtract(const Duration(hours: 4));
        final endTime = now.add(const Duration(hours: 4));
        finalFiltered = filteredByRole
            .where((party) =>
                party.dateTime.isAfter(startTime) &&
                party.dateTime.isBefore(endTime))
            .toList();
        print('After ONGOING time filter: ${finalFiltered.length} parties');
        break;
      case 'past':
        finalFiltered = filteredByRole
            .where((party) => party.dateTime.isBefore(now))
            .toList();
        print('After PAST time filter: ${finalFiltered.length} parties');
        break;
      default:
        // Default to upcoming if filter is invalid
        finalFiltered = filteredByRole
            .where((party) => party.dateTime.isAfter(now))
            .toList();
        print(
            'After DEFAULT (upcoming) time filter: ${finalFiltered.length} parties');
        break;
    }

    print('===================');
    return finalFiltered;
  }

  String _getPartyStatus(Party party) {
    final now = DateTime.now();
    final startTime = now.subtract(const Duration(hours: 4));
    final endTime = now.add(const Duration(hours: 4));

    if (party.dateTime.isAfter(endTime)) {
      return 'upcoming';
    } else if (party.dateTime.isAfter(startTime) &&
        party.dateTime.isBefore(endTime)) {
      return 'ongoing';
    } else {
      return 'past';
    }
  }

  // Removed unused helpers after redesign

  // Removed unused helpers after redesign

  // Removed unused helpers after redesign

  // Removed unused helpers after redesign

  Widget _buildHeroHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.of(context).padding.top + 20,
        24,
        18,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.colors.primary.withOpacity(0.18),
            Colors.white,
            AppTheme.colors.secondary.withOpacity(0.12),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.7),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.colors.primary.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.celebration_outlined,
                  size: 16,
                  color: AppTheme.colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _isHostView ? 'HOST MODE' : 'JOIN MODE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: AppTheme.colors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _isHostView ? 'Your hosted\nplans' : 'Your party\nlineup',
            style: TextStyle(
              fontSize: 42,
              height: 0.96,
              fontWeight: FontWeight.w900,
              color: AppTheme.colors.text,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _isHostView
                ? 'Manage the nights you are running with cleaner controls and quick status views.'
                : 'Keep every invite, active party, and past night in one bold, easy-to-scan place.',
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: AppTheme.colors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleShell({EdgeInsetsGeometry? margin}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      margin: margin,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(_isHeroCollapsed ? 0.94 : 0.84),
        borderRadius: BorderRadius.circular(_toggleRadius),
        border: Border.all(
          color: Colors.white.withOpacity(0.92),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isHeroCollapsed ? 0.09 : 0.05),
            blurRadius: _isHeroCollapsed ? 20 : 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: _buildRoleToggle(),
    );
  }

  Widget _buildInlineRoleToggle() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: _isHeroCollapsed
          ? const SizedBox.shrink()
          : _buildToggleShell(
              margin: const EdgeInsets.fromLTRB(20, 2, 20, 12),
            ),
    );
  }

  Widget _buildPinnedRoleToggle() {
    return _buildToggleShell(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
    );
  }

  Widget _buildRoleToggle() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isHostView = !_isHostView;
          _tabController.index = _isHostView ? 1 : 0;
        });
      },
      child: Container(
        height: 62,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(_toggleRadius),
          border: Border.all(
            color: Colors.white.withOpacity(0.75),
          ),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              alignment:
                  _isHostView ? Alignment.centerRight : Alignment.centerLeft,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: Container(
                width: (MediaQuery.of(context).size.width - 92) / 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.colors.primary,
                      AppTheme.colors.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(_toggleRadius),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.colors.primary.withOpacity(0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _buildRoleToggleLabel(
                    label: 'Joining',
                    icon: Icons.groups_rounded,
                    selected: !_isHostView,
                  ),
                ),
                Expanded(
                  child: _buildRoleToggleLabel(
                    label: 'Hosting',
                    icon: Icons.campaign_rounded,
                    selected: _isHostView,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableContent({required List<Widget> slivers}) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: _buildHeroHeader(),
        ),
        SliverToBoxAdapter(
          child: _buildInlineRoleToggle(),
        ),
        ...slivers,
      ],
    );
  }

  Widget _buildRoleToggleLabel({
    required String label,
    required IconData icon,
    required bool selected,
  }) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: selected ? Colors.white : AppTheme.colors.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : AppTheme.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateCard({
    required IconData icon,
    required String eyebrow,
    required String title,
    required String message,
    String? buttonLabel,
    VoidCallback? onPressed,
    Widget? footer,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withOpacity(0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.colors.primary.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.colors.primary.withOpacity(0.18),
                      AppTheme.colors.secondary.withOpacity(0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  icon,
                  size: 38,
                  color: AppTheme.colors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                eyebrow,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppTheme.colors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  height: 0.98,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.colors.text,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: AppTheme.colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (buttonLabel != null && onPressed != null) ...[
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.explore_outlined),
                  label: Text(buttonLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.colors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              if (footer != null) ...[
                const SizedBox(height: 20),
                footer,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return _buildStateCard(
      icon: Icons.nightlife_rounded,
      eyebrow: 'SYNCING',
      title: 'Loading\nyour nights',
      message: 'Pulling together your hosted and joined parties now.',
      footer: SpinKitWaveSpinner(
        color: AppTheme.colors.primary,
        size: 42,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.colors.background,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned(
            top: -90,
            left: -40,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.colors.primary.withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            top: 110,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.colors.secondary.withOpacity(0.10),
              ),
            ),
          ),
          Consumer<AuthService>(
            builder: (context, auth, child) {
              if (auth.currentUser == null) {
                return CustomRefreshIndicator(
                  onRefresh: _refreshData,
                  builder: (context, child, controller) {
                    return AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) {
                        return Stack(
                          children: [
                            Transform.translate(
                              offset: Offset(0, controller.value * 100),
                              child: child,
                            ),
                            if (controller.isLoading || controller.value > 0)
                              Positioned(
                                top: 20 + (controller.value * 50),
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: SpinKitWaveSpinner(
                                    color: AppTheme.colors.primary,
                                    size: 40.0,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                  child: _buildScrollableContent(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: _buildEmptyState(),
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (_isLoading) {
                return CustomRefreshIndicator(
                  onRefresh: _refreshData,
                  builder: (context, child, controller) {
                    return AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) {
                        return Stack(
                          children: [
                            Transform.translate(
                              offset: Offset(0, controller.value * 100),
                              child: child,
                            ),
                            if (controller.isLoading || controller.value > 0)
                              Positioned(
                                top: 20 + (controller.value * 50),
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: SpinKitWaveSpinner(
                                    color: AppTheme.colors.primary,
                                    size: 40.0,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                  child: _buildScrollableContent(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: _buildLoadingState(),
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (_parties.isEmpty) {
                print('❌ NO PARTIES LOADED - Showing empty state');
                print('   Current user: ${auth.currentUser?.id}');
                print('   Current user name: ${auth.currentUser?.displayName}');
                return CustomRefreshIndicator(
                  onRefresh: _refreshData,
                  builder: (context, child, controller) {
                    return AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) {
                        return Stack(
                          children: [
                            Transform.translate(
                              offset: Offset(0, controller.value * 100),
                              child: child,
                            ),
                            if (controller.isLoading || controller.value > 0)
                              Positioned(
                                top: 20 + (controller.value * 50),
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: SpinKitWaveSpinner(
                                    color: AppTheme.colors.primary,
                                    size: 40.0,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                  child: _buildScrollableContent(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: _buildEmptyState(),
                        ),
                      ),
                    ],
                  ),
                );
              }

              print('\n📊 RENDERING WITH CURRENT STATE:');
              print('   Total parties loaded: ${_parties.length}');
              print('   IsHostView: $_isHostView');
              print('   SelectedFilter: $_selectedFilter');
              print('   Current user: ${auth.currentUser?.id}');
              final filteredParties = _filterParties(_parties);
              print(
                  '   ✅ After filtering: ${filteredParties.length} parties remain\n');

              return CustomRefreshIndicator(
                onRefresh: _refreshData,
                builder: (context, child, controller) {
                  return AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) {
                      return Stack(
                        children: [
                          Transform.translate(
                            offset: Offset(0, controller.value * 100),
                            child: child,
                          ),
                          if (controller.isLoading || controller.value > 0)
                            Positioned(
                              top: 20 + (controller.value * 50),
                              left: 0,
                              right: 0,
                              child: Center(
                                child: SpinKitWaveSpinner(
                                  color: AppTheme.colors.primary,
                                  size: 40.0,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
                child: _buildScrollableContent(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                        child: _buildSummaryAndFilters(
                          _parties,
                          filteredParties,
                        ),
                      ),
                    ),
                    if (filteredParties.isEmpty)
                      SliverFillRemaining(
                        child: _buildNoPartiesForFilter(),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          0,
                          20,
                          MediaQuery.of(context).padding.bottom + 100,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final party = filteredParties[index];
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index < filteredParties.length - 1
                                      ? 16
                                      : 0,
                                ),
                                child: _MyPartyCompactCard(
                                  party: party,
                                  onPartyAction:
                                      (partyId, isHost, isCancelled) =>
                                          _handlePartyAction(
                                              partyId, isHost, isCancelled),
                                  showFeedbackCard: _selectedFilter == 'past',
                                  onFeedbackTap: _showFeedbackBottomSheet,
                                ),
                              );
                            },
                            childCount: filteredParties.length,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          if (_isHeroCollapsed)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: _buildPinnedRoleToggle(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryAndFilters(
      List<Party> allParties, List<Party> filteredParties) {
    final currentUser = context.read<AuthService>().currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    // Align summary counts with the same role filter used in the list
    final relevantParties = _isHostView
        ? allParties.where((p) => p.hostUserId == currentUser.id).toList()
        : allParties
            .where((p) =>
                p.attendeeUserIds.contains(currentUser.id) &&
                p.hostUserId != currentUser.id)
            .toList();

    final now = DateTime.now();
    final upcomingCount =
        relevantParties.where((party) => party.dateTime.isAfter(now)).length;
    final pastCount =
        relevantParties.where((party) => party.dateTime.isBefore(now)).length;
    final ongoingCount = relevantParties.where((party) {
      final startTime = now.subtract(const Duration(hours: 4));
      final endTime = now.add(const Duration(hours: 4));
      return party.dateTime.isAfter(startTime) &&
          party.dateTime.isBefore(endTime);
    }).length;

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.88),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.9),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isHostView ? 'Host dashboard' : 'Party dashboard',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.colors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${filteredParties.length} ${_selectedFilter == 'ongoing' ? 'live now' : _selectedFilter} ${filteredParties.length == 1 ? 'party' : 'parties'}',
                  style: TextStyle(
                    fontSize: 28,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.colors.text,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isHostView
                      ? 'See what is coming up, what is active, and what has already wrapped.'
                      : 'Flip between upcoming nights, current plans, and the parties you have already been to.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppTheme.colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryMetric(
                        'Upcoming',
                        '$upcomingCount',
                        Icons.schedule_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSummaryMetric(
                        'Live',
                        '$ongoingCount',
                        Icons.bolt_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSummaryMetric(
                        'Past',
                        '$pastCount',
                        Icons.history_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.colors.background,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildFilterPill('upcoming', 'Upcoming'),
                      ),
                      Expanded(
                        child: _buildFilterPill('ongoing', 'Ongoing'),
                      ),
                      Expanded(
                        child: _buildFilterPill('past', 'Past'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.colors.background.withOpacity(0.95),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: AppTheme.colors.primary,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppTheme.colors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String filter, String label) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppTheme.colors.primary,
                    AppTheme.colors.secondary,
                  ],
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.colors.primary.withOpacity(0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : AppTheme.colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  void _showFeedbackBottomSheet() {
    final auth = context.read<AuthService>();
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tell us your experience',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Share your feedback and help us improve',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Rate Host Card
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showRateHostDialog();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.blue.shade100,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.shade50,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.person_outline,
                                color: Colors.blue.shade700,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rate and Review Host',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Rate the party host from your past parties',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 18,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Rate Joiners Card
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showRateJoinersDialog();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.green.shade100,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.shade50,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.people_outline,
                                color: Colors.green.shade700,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rate Other Joiners',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Rate other attendees from your past parties',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 18,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Rate App Card
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showRateAppDialog();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.orange.shade100,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.shade50,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.star_outline,
                                color: Colors.orange.shade700,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rate the App and Recommend',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Share your experience and recommend the app',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 18,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRateHostDialog() async {
    final auth = context.read<AuthService>();
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    // Get past parties where user is a joiner
    final pastParties = _filterParties(_parties).where((party) {
      return party.hostUserId != currentUser.id &&
          party.attendeeUserIds.contains(currentUser.id);
    }).toList();

    if (pastParties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No past parties found to rate hosts'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Get unique host IDs
    final Set<String> hostIds = pastParties.map((p) => p.hostUserId).toSet();

    // Fetch host profiles
    final userService = context.read<UserService>();
    final Map<String, String> hostNames = {};
    for (final hostId in hostIds) {
      try {
        final profile = await userService.getUserProfile(hostId);
        hostNames[hostId] = profile?.displayName ?? 'Unknown User';
      } catch (e) {
        hostNames[hostId] = 'Unknown User';
      }
    }

    if (context.mounted) {
      // Get unique hosts only
      final uniqueHosts = hostIds
          .map((hostId) => {
                'id': hostId,
                'name': hostNames[hostId] ?? 'Unknown User',
              })
          .toList();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rate Host'),
          content: SizedBox(
            width: double.maxFinite,
            child: uniqueHosts.isEmpty
                ? const Center(child: Text('No hosts found'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: uniqueHosts.length,
                    itemBuilder: (context, index) {
                      final host = uniqueHosts[index];
                      final hostId = host['id'] as String;
                      final hostName = host['name'] as String;
                      return FutureBuilder(
                        future:
                            context.read<UserService>().getUserProfile(hostId),
                        builder: (context, snapshot) {
                          final profile = snapshot.data;
                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/user-profile/$hostId');
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Colors.grey.shade200,
                                    backgroundImage: profile?.profileImageUrl !=
                                                null &&
                                            profile!.profileImageUrl!.isNotEmpty
                                        ? NetworkImage(profile.profileImageUrl!)
                                        : null,
                                    child: profile?.profileImageUrl == null ||
                                            profile!.profileImageUrl!.isEmpty
                                        ? Icon(
                                            Icons.person,
                                            color: Colors.grey.shade600,
                                            size: 28,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      hostName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 18,
                                    color: Colors.grey.shade400,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  void _showRateJoinersDialog() async {
    final auth = context.read<AuthService>();
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    // Get past parties where user is a joiner
    final pastParties = _filterParties(_parties).where((party) {
      return party.hostUserId != currentUser.id &&
          party.attendeeUserIds.contains(currentUser.id);
    }).toList();

    if (pastParties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No past parties found to rate joiners'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Collect all unique joiner IDs from past parties
    final Set<String> joinerIds = {};
    for (final party in pastParties) {
      joinerIds
          .addAll(party.attendeeUserIds.where((id) => id != currentUser.id));
    }

    if (joinerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No other joiners found to rate'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Fetch joiner profiles
    final userService = context.read<UserService>();
    final Map<String, String> joinerNames = {};
    for (final joinerId in joinerIds) {
      try {
        final profile = await userService.getUserProfile(joinerId);
        joinerNames[joinerId] = profile?.displayName ?? 'Unknown User';
      } catch (e) {
        joinerNames[joinerId] = 'Unknown User';
      }
    }

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rate Joiners'),
          content: SizedBox(
            width: double.maxFinite,
            child: joinerIds.isEmpty
                ? const Center(child: Text('No joiners found'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: joinerIds.length,
                    itemBuilder: (context, index) {
                      final joinerId = joinerIds.elementAt(index);
                      final joinerName =
                          joinerNames[joinerId] ?? 'Unknown User';
                      return FutureBuilder(
                        future: context
                            .read<UserService>()
                            .getUserProfile(joinerId),
                        builder: (context, snapshot) {
                          final profile = snapshot.data;
                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/user-profile/$joinerId');
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Colors.grey.shade200,
                                    backgroundImage: profile?.profileImageUrl !=
                                                null &&
                                            profile!.profileImageUrl!.isNotEmpty
                                        ? NetworkImage(profile.profileImageUrl!)
                                        : null,
                                    child: profile?.profileImageUrl == null ||
                                            profile!.profileImageUrl!.isEmpty
                                        ? Icon(
                                            Icons.person,
                                            color: Colors.grey.shade600,
                                            size: 28,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      joinerName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 18,
                                    color: Colors.grey.shade400,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  void _showRateAppDialog() {
    int selectedRating = 0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Rate the App'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How would you rate your experience?',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final isSelected = index < selectedRating;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedRating = index + 1;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            isSelected ? Icons.star : Icons.star_border,
                            color: isSelected
                                ? Colors.orange
                                : Colors.grey.shade300,
                            size: 40,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: commentController,
                    decoration: InputDecoration(
                      labelText: 'Share your feedback (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      hintText: 'Tell us what you think...',
                    ),
                    maxLines: 4,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: selectedRating == 0
                    ? null
                    : () async {
                        await _submitAppRating(
                            selectedRating, commentController.text);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Thank you for your feedback!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                child: const Text('Submit'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submitAppRating(int rating, String comment) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final auth = context.read<AuthService>();
      final currentUser = auth.currentUser;

      if (currentUser == null) return;

      await firestore.collection('app_reviews').add({
        'userId': currentUser.id,
        'userName': currentUser.displayName,
        'rating': rating,
        'comment': comment.trim(),
        'createdAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error submitting app rating: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit rating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handlePartyAction(String partyId, bool isHost,
      [bool isCurrentlyCancelled = false]) async {
    try {
      final partyService = context.read<PartyService>();
      final chatService = context.read<ChatService>();
      final auth = context.read<AuthService>();
      final currentUser = auth.currentUser;

      if (currentUser == null) return;

      if (isHost) {
        if (isCurrentlyCancelled) {
          // Host restores the party
          await partyService.uncancelParty(partyId);

          // Send system message to chat group
          final chatGroup = await chatService.getChatGroupForParty(partyId);
          if (chatGroup != null) {
            await chatService.sendSystemMessage(
              groupId: chatGroup.id,
              text: 'The party has is back on, lets gooooooooo!',
            );
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Party restored successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          // Host cancels the party
          await partyService.cancelParty(partyId);

          // Deduct 10 bunny points for cancelling a hosting party
          await _deductBunnyPoints(currentUser.id, 10);

          // Send system message to chat group
          final chatGroup = await chatService.getChatGroupForParty(partyId);
          if (chatGroup != null) {
            await chatService.sendSystemMessage(
              groupId: chatGroup.id,
              text: 'The party has been cancelled by the host.',
            );
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Party cancelled successfully'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // Joiner leaves the party
        await partyService.leave(partyId: partyId, userId: currentUser.id);

        // Send system message to chat group
        final chatGroup = await chatService.getChatGroupForParty(partyId);
        if (chatGroup != null) {
          await chatService.sendSystemMessage(
            groupId: chatGroup.id,
            text:
                '👋 ${currentUser.displayName.isNotEmpty ? currentUser.displayName : 'Someone'} left the party.',
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Left party successfully'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // Refresh the parties list to update counts and remove deleted party
      if (mounted) {
        _loadParties();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Removed legacy full-width card after redesign

  Widget _buildEmptyState() {
    return _buildStateCard(
      icon: Icons.celebration_rounded,
      eyebrow: 'NOTHING HERE YET',
      title: 'No parties\nso far',
      message:
          'Start exploring clubs and jump into a night out to build your list.',
      buttonLabel: 'Explore parties',
      onPressed: () {
        context.push('/view-all-parties');
      },
    );
  }

  Widget _buildNoPartiesForFilter() {
    return _buildStateCard(
      icon: Icons.tune_rounded,
      eyebrow: 'FILTERED VIEW',
      title:
          'No ${_selectedFilter == 'ongoing' ? 'live' : _selectedFilter}\nparties',
      message: 'Try another filter or come back later when your plans shift.',
    );
  }

  Future<void> _refreshData() async {
    print('🔄 Refreshing My Parties data...');
    await _loadParties();
    print('✅ My Parties data refreshed');
  }

  Future<void> cancelParty(Party party) async {
    print('cancelParty method called for party: ${party.title}');
    try {
      final partyService = context.read<PartyService>();
      final chatService = context.read<ChatService>();

      print('Services obtained, calling partyService.cancelParty...');
      // Cancel the party using the same logic as swipe action
      await partyService.cancelParty(party.id);
      print('Party cancelled successfully');

      // Send system message to chat group
      final chatGroup = await chatService.getChatGroupForParty(party.id);
      if (chatGroup != null) {
        await chatService.sendSystemMessage(
          groupId: chatGroup.id,
          text: '🚫 The party has been cancelled by the host.',
        );
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Party "${party.title}" has been cancelled'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Refresh the parties list
      setState(() {
        _loadParties();
      });
    } catch (e) {
      print('Error cancelling party: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel party: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deductBunnyPoints(String userId, int points) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final userDoc = await firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        int currentPoints = (data['bunnyPoints'] ?? 0) as int;
        currentPoints = (currentPoints - points)
            .clamp(0, double.infinity)
            .toInt(); // Don't go below 0

        await firestore.collection('users').doc(userId).update({
          'bunnyPoints': currentPoints,
        });
      }
    } catch (e) {
      print('Error deducting bunny points: $e');
    }
  }
}

class _MyPartyCompactCard extends StatefulWidget {
  const _MyPartyCompactCard({
    required this.party,
    required this.onPartyAction,
    this.showFeedbackCard = false,
    this.onFeedbackTap,
  });
  final Party party;
  final Function(String partyId, bool isHost, bool isCancelled) onPartyAction;
  final bool showFeedbackCard;
  final VoidCallback? onFeedbackTap;

  @override
  State<_MyPartyCompactCard> createState() => _MyPartyCompactCardState();
}

class _MyPartyCompactCardState extends State<_MyPartyCompactCard> {
  String? _clubName;
  List<String> _attendeeNames = [];
  bool _hasArrived = false;
  bool _isCheckingArrival = false;
  late bool _isAcceptingRequests;

  @override
  void initState() {
    super.initState();
    _isAcceptingRequests = widget.party.isAcceptingRequests;
    _loadClubName();
    _loadAttendeeNames();
    if (_isPartyFinished(widget.party)) {
      _checkArrivalStatus();
    }
  }

  Future<void> _loadClubName() async {
    try {
      final clubService = context.read<ClubService>();
      final club = await clubService.getById(widget.party.clubId);
      if (club != null && mounted) {
        setState(() => _clubName = club.name);
        return;
      }
      try {
        final placeId = widget.party.clubId.split('_')[0];
        final details = await clubService.getVenueDetails(placeId);
        if (mounted)
          setState(() => _clubName = details?.name ?? 'Unknown Location');
      } catch (_) {
        if (mounted) setState(() => _clubName = 'Unknown Location');
      }
    } catch (_) {
      if (mounted) setState(() => _clubName = 'Unknown Location');
    }
  }

  Future<void> _loadAttendeeNames() async {
    try {
      if (widget.party.attendeeUserIds.isEmpty) {
        print('⚠️ Party ${widget.party.id} has no attendee IDs');
        return;
      }
      final userService = context.read<UserService>();
      final profiles = await userService
          .getUserProfiles(widget.party.attendeeUserIds.take(5).toList());
      if (mounted) {
        setState(() => _attendeeNames =
            profiles.values.map((p) => p.displayName).toList());
        print(
            '✅ Loaded ${_attendeeNames.length} attendee names for party ${widget.party.id}');
      }
    } catch (e) {
      print('❌ Error loading attendee names for party ${widget.party.id}: $e');
    }
  }

  Future<void> _checkArrivalStatus() async {
    if (_isCheckingArrival) return;

    try {
      _isCheckingArrival = true;
      final auth = context.read<AuthService>();
      final currentUser = auth.currentUser;
      if (currentUser == null) return;

      // Get chat group for the party
      final chatService = context.read<ChatService>();
      final chatGroup = await chatService.getChatGroupForParty(widget.party.id);

      if (chatGroup == null) return;

      // Check if user has already arrived
      final firestore = FirebaseFirestore.instance;
      final chatGroupDoc =
          await firestore.collection('chat_groups').doc(chatGroup.id).get();
      final data = chatGroupDoc.data() ?? {};
      final arrivedUserIds = List<String>.from(data['arrivedUserIds'] ?? []);

      if (mounted) {
        setState(() {
          _hasArrived = arrivedUserIds.contains(currentUser.id);
          _isCheckingArrival = false;
        });
      }
    } catch (e) {
      print('Error checking arrival status: $e');
      if (mounted) {
        setState(() {
          _isCheckingArrival = false;
        });
      }
    }
  }

  String _fallbackImage(String clubId) {
    final images = [
      'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1566733971017-f8a6c8c2c6b3?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1520975916090-3105956d8ac38?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1517095037594-166575f1e866?w=400&h=300&fit=crop',
    ];
    return images[clubId.hashCode.abs() % images.length];
  }

  bool _isPartyFinished(Party party) {
    final now = DateTime.now();
    // Consider party finished if it's been more than 4 hours since the party time
    final partyEndTime = party.dateTime.add(const Duration(hours: 4));
    return now.isAfter(partyEndTime);
  }

  bool _isPartyCancelled(Party party) {
    return party.isCancelled ?? false;
  }

  Future<void> _toggleAcceptingRequests(bool isAccepting) async {
    try {
      final partyService = context.read<PartyService>();
      await partyService.updateParty(widget.party.id, {
        'isAcceptingRequests': isAccepting,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAccepting
                  ? 'Now accepting join requests'
                  : 'Stopped accepting requests',
            ),
            backgroundColor: isAccepting ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error updating accepting requests status: $e');
      if (mounted) {
        setState(() {
          _isAcceptingRequests = !isAccepting; // Revert on error
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final currentUser = auth.currentUser;
    final isHost =
        currentUser != null && widget.party.hostUserId == currentUser.id;
    final isAttending = currentUser != null &&
        widget.party.attendeeUserIds.contains(currentUser.id);

    return Dismissible(
      key: ValueKey('party-${widget.party.id}'),
      direction: DismissDirection.endToStart, // Swipe left to right
      background: Container(
        decoration: BoxDecoration(
          color: _isPartyCancelled(widget.party)
              ? (isHost ? Colors.green.shade100 : Colors.orange.shade100)
              : (isHost ? Colors.red.shade100 : Colors.orange.shade100),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isPartyCancelled(widget.party)
                  ? (isHost ? Icons.refresh : Icons.exit_to_app)
                  : (isHost ? Icons.cancel : Icons.exit_to_app),
              color: _isPartyCancelled(widget.party)
                  ? (isHost ? Colors.green.shade600 : Colors.orange.shade600)
                  : (isHost ? Colors.red.shade600 : Colors.orange.shade600),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              _isPartyCancelled(widget.party)
                  ? (isHost ? 'Restore' : 'Leave')
                  : (isHost ? 'Cancel' : 'Leave'),
              style: TextStyle(
                color: _isPartyCancelled(widget.party)
                    ? (isHost ? Colors.green.shade600 : Colors.orange.shade600)
                    : (isHost ? Colors.red.shade600 : Colors.orange.shade600),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await _showConfirmationDialog(
            isHost, _isPartyCancelled(widget.party));
      },
      onDismissed: (direction) {
        widget.onPartyAction(
            widget.party.id, isHost, _isPartyCancelled(widget.party));
      },
      child: GestureDetector(
        onTap: () {
          // Check if user is a joiner (not host)
          final auth = context.read<AuthService>();
          final currentUser = auth.currentUser;
          final isHost =
              currentUser != null && widget.party.hostUserId == currentUser.id;

          if (isHost) {
            // Host opens manage bottomsheet
            _showManageOptions(context, widget.party, widget.onPartyAction);
          } else {
            // Joiner goes to party ticket
            context.push('/party-ticket?id=${widget.party.id}');
          }
        },
        child: Container(
          width: double.infinity,
          height: isHost ? 308 : 248,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: isHost
              ? _buildHostCard(context, isHost, isAttending)
              : _buildJoinerCard(context, isHost, isAttending),
        ),
      ),
    );
  }

  // Redesigned Host Card
  Widget _buildHostCard(BuildContext context, bool isHost, bool isAttending) {
    final bool cancelled = _isPartyCancelled(widget.party);
    final bool finished = _isPartyFinished(widget.party);
    final DateTime endTime =
        widget.party.dateTime.add(const Duration(hours: 4));

    final String statusText = cancelled
        ? 'Cancelled'
        : finished
            ? 'Hosted'
            : 'Hosting';

    final Color statusColor = cancelled
        ? const Color(0xFFC83C3C)
        : finished
            ? const Color(0xFF2E7D32)
            : const Color(0xFF2F7D45);

    final Color statusBg = cancelled
        ? const Color(0xFFFDEBEC)
        : finished
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFEAF4EC);

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FC),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE5EAF3)),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    cancelled
                        ? Icons.cancel_rounded
                        : Icons.check_circle_rounded,
                    size: 18,
                    color: statusColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: ColorFiltered(
                            colorFilter: cancelled
                                ? const ColorFilter.mode(
                                    Colors.red, BlendMode.saturation)
                                : finished
                                    ? const ColorFilter.mode(
                                        Colors.grey, BlendMode.saturation)
                                    : const ColorFilter.mode(
                                        Colors.transparent,
                                        BlendMode.multiply,
                                      ),
                            child: Image.network(
                              widget.party.imageUrl ??
                                  _fallbackImage(widget.party.clubId),
                              width: 74,
                              height: 74,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 74,
                                  height: 74,
                                  color: Colors.grey.shade200,
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    size: 22,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.party.title.isNotEmpty
                                    ? widget.party.title
                                    : 'Untitled Party',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF171A22),
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${DateFormat('d MMM').format(widget.party.dateTime)} (${DateFormat('HH:mm').format(widget.party.dateTime)})  ->  ${DateFormat('d MMM').format(endTime)} (${DateFormat('HH:mm').format(endTime)})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_rounded,
                                    size: 15,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _clubName ?? 'Loading location...',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildWaveProgressBar(
                      widget.party.attendeeUserIds.length,
                      widget.party.capacity,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.how_to_reg,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Accepting Requests',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          Transform.scale(
                            scale: 0.82,
                            child: Switch(
                              value: _isAcceptingRequests,
                              onChanged: (value) {
                                setState(() {
                                  _isAcceptingRequests = value;
                                });
                                _toggleAcceptingRequests(value);
                              },
                              activeColor: AppTheme.colors.primary,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: const BoxDecoration(
                color: Color(0xFFEFF2FB),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildHostActionButton(
                      icon: Icons.chat_bubble_outline,
                      label: 'Chat',
                      color: Colors.blue,
                      onTap: () =>
                          context.push('/party-details?id=${widget.party.id}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.key,
                          size: 12,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.party.inviteCode.isNotEmpty
                              ? widget.party.inviteCode
                              : 'N/A',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateCard(DateTime dateTime) {
    final day = DateFormat('d').format(dateTime);
    final month = DateFormat('MMM').format(dateTime).toUpperCase();
    final time = DateFormat('h:mm a').format(dateTime);

    return Container(
      width: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Month header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.colors.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Text(
              month,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // Day
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              day,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
                height: 1,
              ),
            ),
          ),
          // Time
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
            ),
            child: Text(
              time,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveProgressBar(int current, int capacity) {
    final progress = capacity > 0 ? (current / capacity).clamp(0.0, 1.0) : 0.0;
    final progressColor = progress >= 0.9
        ? Colors.orange
        : progress >= 0.7
            ? Colors.amber
            : AppTheme.colors.primary;

    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Progress fill
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        progressColor,
                        progressColor.withOpacity(0.7),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              ),
            ),
            // Text and icon in unfilled area
            Positioned.fill(
              child: Row(
                children: [
                  // Empty space for filled portion
                  if (progress > 0)
                    Flexible(
                      flex: (progress * 100).toInt(),
                      child: const SizedBox(),
                    ),
                  // Text and icon in unfilled portion
                  if (progress < 1.0)
                    Flexible(
                      flex: ((1 - progress) * 100).toInt().clamp(1, 100),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '$current/$capacity',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Original Joiner Card
  Widget _buildJoinerCard(BuildContext context, bool isHost, bool isAttending) {
    final bool cancelled = _isPartyCancelled(widget.party);
    final bool attended = _isPartyFinished(widget.party) && _hasArrived;
    final bool confirmed = isAttending && !cancelled;

    final String statusText = cancelled
        ? 'Cancelled'
        : attended
            ? 'Attended'
            : confirmed
                ? 'Confirmed'
                : 'Guest';

    final Color statusColor = cancelled
        ? const Color(0xFFC83C3C)
        : attended
            ? const Color(0xFF2E7D32)
            : const Color(0xFF2F7D45);

    final Color statusBg = cancelled
        ? const Color(0xFFFDEBEC)
        : attended
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFEAF4EC);

    final DateTime endTime =
        widget.party.dateTime.add(const Duration(hours: 4));

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FC),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE5EAF3)),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    cancelled
                        ? Icons.cancel_rounded
                        : Icons.check_circle_rounded,
                    size: 18,
                    color: statusColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: ColorFiltered(
                        colorFilter: cancelled
                            ? const ColorFilter.mode(
                                Colors.red, BlendMode.saturation)
                            : attended
                                ? const ColorFilter.mode(
                                    Colors.grey, BlendMode.saturation)
                                : const ColorFilter.mode(
                                    Colors.transparent,
                                    BlendMode.multiply,
                                  ),
                        child: Image.network(
                          widget.party.imageUrl ??
                              _fallbackImage(widget.party.clubId),
                          width: 76,
                          height: 76,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 76,
                              height: 76,
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.image_not_supported,
                                size: 22,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.party.title.isNotEmpty
                                ? widget.party.title
                                : 'Untitled Party',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF171A22),
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${DateFormat('d MMM').format(widget.party.dateTime)} (${DateFormat('HH:mm').format(widget.party.dateTime)})  ->  ${DateFormat('d MMM').format(endTime)} (${DateFormat('HH:mm').format(endTime)})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 15,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _clubName ?? 'Loading location...',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 8, 10, 10),
              decoration: const BoxDecoration(
                color: Color(0xFFEFF2FB),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '1 Booking',
                    style: TextStyle(
                      color: AppTheme.colors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '•',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.people_alt_outlined,
                      size: 15, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.party.attendeeUserIds.length}',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  if (widget.showFeedbackCard && widget.onFeedbackTap != null)
                    GestureDetector(
                      onTap: widget.onFeedbackTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.colors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Rate',
                          style: TextStyle(
                            color: AppTheme.colors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.colors.primary,
                      size: 24,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showConfirmationDialog(
      bool isHost, bool isCurrentlyCancelled) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            final isRestore = isHost && isCurrentlyCancelled;
            final isCancel = isHost && !isCurrentlyCancelled;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(
                isRestore
                    ? 'Restore Party'
                    : (isCancel ? 'Cancel Party' : 'Leave Party'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Text(
                isRestore
                    ? 'Are you sure you want to restore this party? All attendees will be notified that the party is back on.'
                    : isCancel
                        ? 'Are you sure you want to cancel this party? This action cannot be undone and all attendees will be notified.'
                        : 'Are you sure you want to leave this party? You can rejoin later if there\'s space available.',
                style: const TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRestore
                        ? Colors.green
                        : (isCancel ? Colors.red : Colors.orange),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(isRestore
                      ? 'Restore Party'
                      : (isCancel ? 'Cancel Party' : 'Leave Party')),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  void _showManageOptions(BuildContext context, Party party,
      Function(String partyId, bool isHost, bool isCancelled) onPartyAction) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ManagePartyScreen(
          party: party,
          onPartyAction: onPartyAction,
        ),
      ),
    );
  }
}

class _WaveAnimation extends StatefulWidget {
  const _WaveAnimation();

  @override
  State<_WaveAnimation> createState() => _WaveAnimationState();
}

class _WaveAnimationState extends State<_WaveAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_controller.value * 20 - 10, 0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.0),
                  Colors.white.withOpacity(0.3),
                  Colors.white.withOpacity(0.0),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        );
      },
    );
  }
}
