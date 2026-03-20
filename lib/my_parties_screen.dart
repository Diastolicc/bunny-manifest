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

class MyPartiesScreen extends StatefulWidget {
  const MyPartiesScreen({super.key});

  @override
  State<MyPartiesScreen> createState() => _MyPartiesScreenState();
}

class _MyPartiesScreenState extends State<MyPartiesScreen>
    with SingleTickerProviderStateMixin {
  String _selectedFilter = 'upcoming'; // upcoming, ongoing, past
  bool _isHostView = false; // false = Joiner, true = Host
  List<Party> _parties = [];
  bool _isLoading = true;
  ScrollController _scrollController = ScrollController();
  bool _showScrollbar = false;
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
      final isScrolling = _scrollController.position.isScrollingNotifier.value;
      if (_showScrollbar != isScrolling) {
        setState(() {
          _showScrollbar = isScrolling;
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
        print('   ⚠️ Current user is NULL! Waiting for profile before loading parties...');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          // Header with Action Buttons
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              left: 24,
              right: 24,
              bottom: 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Parties',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 56,
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.transparent,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    onTap: (index) {
                      setState(() {
                        _isHostView = index == 1;
                      });
                    },
                    indicator: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.colors.primary.withOpacity(0.95),
                          AppTheme.colors.primary.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.colors.primary.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey.shade700,
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    indicatorPadding: EdgeInsets.zero,
                    labelPadding: EdgeInsets.zero,
                    tabs: const [
                      Tab(text: 'Joining'),
                      Tab(text: 'Hosting'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _refreshData,
                  child: Consumer<AuthService>(
                    builder: (context, auth, child) {
                      if (auth.currentUser == null) {
                        return _buildEmptyState();
                      }

                      if (_isLoading) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.colors.primary),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Loading your parties...',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (_parties.isEmpty) {
                        print('❌ NO PARTIES LOADED - Showing empty state');
                        print('   Current user: ${auth.currentUser?.id}');
                        print(
                            '   Current user name: ${auth.currentUser?.displayName}');
                        return _buildEmptyState();
                      }

                      print('\n📊 RENDERING WITH CURRENT STATE:');
                      print('   Total parties loaded: ${_parties.length}');
                      print('   IsHostView: $_isHostView');
                      print('   SelectedFilter: $_selectedFilter');
                      print('   Current user: ${auth.currentUser?.id}');
                      final filteredParties = _filterParties(_parties);
                      print(
                          '   ✅ After filtering: ${filteredParties.length} parties remain\n');

                      return Column(
                        children: [
                          // Party Summary and Filter Tabs
                          _buildSummaryAndFilters(_parties, filteredParties),

                          // Parties List
                          Expanded(
                            child: filteredParties.isEmpty
                                ? _buildNoPartiesForFilter()
                                : _buildPartiesList(filteredParties),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                // Floating Scrollbar
                if (_showScrollbar)
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: _buildFloatingScrollbar(),
                  ),
              ],
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

    final upcoming =
        relevantParties.where((p) => _getPartyStatus(p) == 'upcoming').length;
    final ongoing =
        relevantParties.where((p) => _getPartyStatus(p) == 'ongoing').length;
    final past =
        relevantParties.where((p) => _getPartyStatus(p) == 'past').length;

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Filter Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterPill('upcoming', 'Upcoming', upcoming),
                const SizedBox(width: 8),
                _buildFilterPill('ongoing', 'Ongoing', ongoing),
                const SizedBox(width: 8),
                _buildFilterPill('past', 'Past', past),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String filter, String label, int count) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.colors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.colors.primary : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPartiesList(List<Party> parties) {
    return ListView.separated(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).padding.bottom +
            100, // Add space for bottom nav bar
      ),
      itemCount: parties.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final party = parties[index];
        return _MyPartyCompactCard(
          party: party,
          onPartyAction: (partyId, isHost, isCancelled) =>
              _handlePartyAction(partyId, isHost, isCancelled),
          showFeedbackCard:
              _selectedFilter == 'past', // Show feedback card on past tab
          onFeedbackTap: _showFeedbackBottomSheet,
        );
      },
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.colors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.celebration,
                size: 64,
                color: AppTheme.colors.primary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Parties Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.colors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start exploring clubs and join parties to see them here!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context.push('/view-all-parties');
              },
              icon: const Icon(Icons.explore),
              label: const Text('Explore'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.colors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPartiesForFilter() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_list,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${_selectedFilter == 'all' ? '' : _selectedFilter} parties',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try changing the filter or join some parties!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingScrollbar() {
    return AnimatedOpacity(
      opacity: _showScrollbar ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade400,
          borderRadius: BorderRadius.circular(2),
        ),
        child: AnimatedBuilder(
          animation: _scrollController,
          builder: (context, child) {
            if (!_scrollController.hasClients) return const SizedBox.shrink();

            final scrollOffset = _scrollController.offset;
            final maxScrollExtent = _scrollController.position.maxScrollExtent;
            final viewportHeight = _scrollController.position.viewportDimension;

            if (maxScrollExtent <= 0) return const SizedBox.shrink();

            final scrollPercentage = scrollOffset / maxScrollExtent;
            final thumbHeight = (viewportHeight *
                    viewportHeight /
                    (viewportHeight + maxScrollExtent))
                .clamp(20.0, viewportHeight * 0.8);
            final thumbTop = scrollPercentage * (viewportHeight - thumbHeight);

            return Stack(
              children: [
                // Track
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Thumb
                Positioned(
                  top: thumbTop,
                  child: Container(
                    width: 4,
                    height: thumbHeight,
                    decoration: BoxDecoration(
                      color: AppTheme.colors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
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

  @override
  void initState() {
    super.initState();
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
            // Host goes to party details
            context.push('/party-details?id=${widget.party.id}');
          } else {
            // Joiner goes to party ticket
            context.push('/party-ticket?id=${widget.party.id}');
          }
        },
        child: Container(
          width: double.infinity,
          height: 200,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image (top)
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        child: ColorFiltered(
                          colorFilter: _isPartyCancelled(widget.party)
                              ? const ColorFilter.mode(
                                  Colors.red, BlendMode.saturation)
                              : _isPartyFinished(widget.party)
                                  ? const ColorFilter.mode(
                                      Colors.grey, BlendMode.saturation)
                                  : const ColorFilter.mode(
                                      Colors.transparent, BlendMode.multiply),
                          child: Image.network(
                            widget.party.imageUrl ??
                                _fallbackImage(widget.party.clubId),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: Icon(Icons.image_not_supported,
                                      size: 24, color: Colors.grey),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    // Status overlay
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isPartyCancelled(widget.party)
                              ? Colors.red
                              : isHost
                                  ? Colors.purple
                                  : (_isPartyFinished(widget.party) &&
                                          _hasArrived &&
                                          isAttending)
                                      ? Colors.green
                                      : (isAttending
                                          ? Colors.blue
                                          : Colors.grey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _isPartyCancelled(widget.party)
                              ? 'Cancelled'
                              : isHost
                                  ? 'Hosting'
                                  : (_isPartyFinished(widget.party) &&
                                          _hasArrived &&
                                          isAttending)
                                      ? 'Attended'
                                      : (isAttending ? 'Going' : 'Guest'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    // Manage chip on image (host only)
                    if (isHost)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => _showManageOptions(
                              context, widget.party, widget.onPartyAction),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Manage',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Details (bottom)
              Expanded(
                flex: 2,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left half - Party details
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Title
                            Text(
                              widget.party.title.isNotEmpty
                                  ? widget.party.title
                                  : 'Untitled Party',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            // Venue
                            Text(
                              _clubName ?? 'Loading location...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            // Date
                            Row(
                              children: [
                                const Icon(Icons.access_time,
                                    size: 10, color: Colors.black54),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    DateFormat('MMM d, h:mm a')
                                        .format(widget.party.dateTime),
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.black54),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Right half - Feedback button or attendee avatars
                    if (widget.showFeedbackCard && widget.onFeedbackTap != null)
                      Expanded(
                        flex: 1,
                        child: GestureDetector(
                          onTap: widget.onFeedbackTap,
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.colors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.colors.primary.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'How\'s your party? Rate your new friends',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.colors.primary,
                                          height: 1.3,
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 14,
                                      color: AppTheme.colors.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_attendeeNames.isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ...List.generate(
                                          _attendeeNames.length > 3
                                              ? 3
                                              : _attendeeNames.length,
                                          (index) => Padding(
                                            padding: EdgeInsets.only(
                                                right: index < 2 ? 2 : 0),
                                            child: CircleAvatar(
                                              radius: 8,
                                              backgroundColor:
                                                  Colors.grey.shade300,
                                              child: Text(
                                                _attendeeNames[index].isNotEmpty
                                                    ? _attendeeNames[index][0]
                                                        .toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                    fontSize: 8,
                                                    color: Colors.black87),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (_attendeeNames.length > 3)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(left: 2),
                                            child: CircleAvatar(
                                              radius: 8,
                                              backgroundColor:
                                                  Colors.grey.shade400,
                                              child: Text(
                                                '+${_attendeeNames.length - 3}',
                                                style: const TextStyle(
                                                    fontSize: 8,
                                                    color: Colors.white),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  if (_attendeeNames.isNotEmpty)
                                    const SizedBox(width: 4),
                                  Icon(
                                    Icons.people,
                                    size: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.party.attendeeUserIds.length}/${widget.party.capacity}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700),
                                  ),
                                ],
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Icon(Icons.settings,
                        color: AppTheme.colors.primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Manage Party',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Management Options
              Expanded(
                child: _buildManageOptionsList(context, party),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildManageOptionsList(BuildContext context, Party party) {
    final options = [
      {
        'title': 'View Participants',
        'subtitle': 'See who\'s joining your party',
        'icon': Icons.people,
        'color': Colors.blue,
        'onTap': () {
          Navigator.of(context).pop();
          context.push('/participants/${party.id}');
        },
      },
      {
        'title': 'Edit Party Details',
        'subtitle': 'Update party information',
        'icon': Icons.edit,
        'color': Colors.orange,
        'onTap': () {
          final authService = context.read<AuthService>();
          final isLoggedOut =
              authService.currentUser == null || authService.isGuest;

          Navigator.of(context).pop();
          if (isLoggedOut) {
            _showCreatePartyAuthPrompt();
            return;
          }

          context.push('/create-party?edit=true&partyId=${party.id}');
        },
      },
      {
        'title': 'Send Reminders',
        'subtitle': 'Notify participants about the party',
        'icon': Icons.notifications_active,
        'color': Colors.green,
        'onTap': () {
          Navigator.of(context).pop();
          _showSendRemindersDialog(context, party);
        },
      },
      {
        'title': 'Party Analytics',
        'subtitle': 'View party statistics and insights',
        'icon': Icons.analytics,
        'color': Colors.purple,
        'onTap': () {
          Navigator.of(context).pop();
          _showPartyAnalytics(context, party);
        },
      },
      {
        'title': 'Share Party',
        'subtitle': 'Invite more people to join',
        'icon': Icons.share,
        'color': Colors.teal,
        'onTap': () {
          Navigator.of(context).pop();
          _showSharePartyDialog(context, party);
        },
      },
      {
        'title':
            (party.isCancelled ?? false) ? 'Restore Party' : 'Cancel Party',
        'subtitle': (party.isCancelled ?? false)
            ? 'Restore this party and notify participants'
            : 'Cancel this party and notify participants',
        'icon': (party.isCancelled ?? false) ? Icons.restore : Icons.cancel,
        'color': (party.isCancelled ?? false) ? Colors.green : Colors.red,
        'onTap': () {
          Navigator.of(context).pop();
          if (party.isCancelled ?? false) {
            _showRestorePartyDialog(context, party);
          } else {
            _showCancelPartyDialog(context, party);
          }
        },
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final option = options[index];

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (option['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                option['icon'] as IconData,
                color: option['color'] as Color,
                size: 20,
              ),
            ),
            title: Text(
              option['title'] as String,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              option['subtitle'] as String,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade400,
              size: 16,
            ),
            onTap: option['onTap'] as VoidCallback,
          ),
        );
      },
    );
  }

  void _showCancelPartyDialog(BuildContext context, Party party) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 24),
              const SizedBox(width: 8),
              const Text('Cancel Party'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to cancel "${party.title}"?'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.red.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'All participants will be notified and the party will be removed from all feeds.',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Keep Party'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Use the existing onPartyAction callback to cancel the party
                print('Calling onPartyAction to cancel party: ${party.id}');
                await widget.onPartyAction(party.id, true,
                    false); // isHost=true, isCancelled=false (will be cancelled)
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancel Party'),
            ),
          ],
        );
      },
    );
  }

  void _showRestorePartyDialog(BuildContext context, Party party) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.restore, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              const Text('Restore Party'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to restore "${party.title}"?'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.green.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'All participants will be notified and the party will be restored to all feeds.',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Keep Cancelled'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Use the existing onPartyAction callback to restore the party
                print('Calling onPartyAction to restore party: ${party.id}');
                await widget.onPartyAction(party.id, true,
                    true); // isHost=true, isCancelled=true (will be restored)
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Restore Party'),
            ),
          ],
        );
      },
    );
  }

  // Send Reminders Dialog
  void _showSendRemindersDialog(BuildContext context, Party party) {
    final TextEditingController reminderController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.green),
            const SizedBox(width: 8),
            const Text('Send Reminder'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send a reminder to all participants of "${party.title}"'),
            const SizedBox(height: 16),
            TextField(
              controller: reminderController,
              decoration: const InputDecoration(
                labelText: 'Reminder message',
                hintText: 'e.g., "Don\'t forget! Party starts in 2 hours!"',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reminderController.text.trim().isNotEmpty) {
                Navigator.of(context).pop();
                await _sendReminderToParticipants(
                    party, reminderController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Send Reminder',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Send reminder to participants
  Future<void> _sendReminderToParticipants(Party party, String message) async {
    try {
      final chatService = context.read<ChatService>();
      final chatGroup = await chatService.getChatGroupForParty(party.id);

      if (chatGroup != null) {
        await chatService.sendSystemMessage(
          groupId: chatGroup.id,
          text: '🔔 Reminder: $message',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Reminder sent to ${party.attendeeUserIds.length} participants'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('Error sending reminder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send reminder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Party Analytics Dialog
  void _showPartyAnalytics(BuildContext context, Party party) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.analytics, color: Colors.purple),
            const SizedBox(width: 8),
            const Text('Party Analytics'),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Analytics for "${party.title}"',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildAnalyticsItem('Total Participants',
                    '${party.attendeeUserIds.length}', Icons.people),
                _buildAnalyticsItem(
                    'Capacity', '${party.capacity}', Icons.event_seat),
                _buildAnalyticsItem(
                    'Fill Rate',
                    '${((party.attendeeUserIds.length / party.capacity) * 100).toStringAsFixed(1)}%',
                    Icons.trending_up),
                _buildAnalyticsItem('Party Date', _formatDate(party.dateTime),
                    Icons.calendar_today),
                FutureBuilder<String>(
                  future: _getClubName(party.clubId),
                  builder: (context, snapshot) {
                    return _buildAnalyticsItem('Venue',
                        snapshot.data ?? 'Loading...', Icons.location_on);
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'More detailed analytics coming soon!',
                          style: TextStyle(
                              color: Colors.blue.shade700, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<String> _getClubName(String clubId) async {
    try {
      final clubService = ClubService();
      final club = await clubService.getById(clubId);
      return club?.name ?? 'Unknown Venue';
    } catch (e) {
      print('Error loading club name: $e');
      return 'Unknown Venue';
    }
  }

  // Share Party Dialog
  void _showSharePartyDialog(BuildContext context, Party party) {
    final partyLink = 'https://thebunnyapp.com/party/${party.id}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.share, color: Colors.teal),
            const SizedBox(width: 8),
            const Text('Share Party'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share "${party.title}" with friends!',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      partyLink,
                      style:
                          TextStyle(color: Colors.grey.shade700, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // Copy to clipboard
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Link copied to clipboard!')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Share via:',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareButton(Icons.message, 'Message', Colors.blue),
                _buildShareButton(Icons.email, 'Email', Colors.red),
                _buildShareButton(Icons.link, 'Copy Link', Colors.grey),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildShareButton(IconData icon, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}
