import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bunny/models/user_profile.dart';
import 'package:bunny/services/user_service.dart';
import 'package:bunny/services/party_service.dart';
import 'package:bunny/theme/app_theme.dart';

class UserProfileBottomSheet extends StatelessWidget {
  final String userId;

  const UserProfileBottomSheet({super.key, required this.userId});

  Future<_UserProfileAndStats?> _load(BuildContext context) async {
    final userService = context.read<UserService>();
    final partyService = context.read<PartyService>();

    final UserProfile? profile = await userService.getUserProfile(userId);
    int hosted = 0;
    int joined = 0;
    try {
      final allParties = await partyService.getAllParties();
      hosted = allParties.where((p) => p.hostUserId == userId).length;
      joined = allParties
          .where((p) =>
              p.attendeeUserIds.contains(userId) && p.hostUserId != userId)
          .length;
    } catch (_) {}
    if (profile == null) return null;
    return _UserProfileAndStats(
        profile: profile, hostedCount: hosted, joinedCount: joined);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: FutureBuilder<_UserProfileAndStats?>(
        future: _load(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: const Center(child: CircularProgressIndicator()),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: const Center(child: Text('User not found')),
            );
          }

          return Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: _UserProfileCard(
              profile: data.profile,
              hostedCount: data.hostedCount,
              joinedCount: data.joinedCount,
            ),
          );
        },
      ),
    );
  }
}

class _UserProfileCard extends StatelessWidget {
  final UserProfile profile;
  final int hostedCount;
  final int joinedCount;

  const _UserProfileCard({
    required this.profile,
    required this.hostedCount,
    required this.joinedCount,
  });

  String _formatMemberSince(DateTime? dt) {
    if (dt == null) return 'Member since —';
    final monthNames = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return 'Member since ${monthNames[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.colors.primary.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'BUNNY',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                    letterSpacing: 2.0,
                  ),
                ),
                CircleAvatar(
                  radius: 24,
                  backgroundImage: profile.profileImageUrl != null &&
                          profile.profileImageUrl!.isNotEmpty
                      ? NetworkImage(profile.profileImageUrl!)
                      : null,
                  backgroundColor: Colors.grey.shade300,
                  child: (profile.profileImageUrl == null ||
                          profile.profileImageUrl!.isEmpty)
                      ? Icon(Icons.person, color: Colors.grey.shade600)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    profile.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, color: Colors.white, size: 10),
                      SizedBox(width: 3),
                      Text('Verified',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _formatMemberSince(profile.createdAt),
              style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat('Hosted', hostedCount.toString()),
                _stat('Joined', joinedCount.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _UserProfileAndStats {
  final UserProfile profile;
  final int hostedCount;
  final int joinedCount;

  const _UserProfileAndStats(
      {required this.profile,
      required this.hostedCount,
      required this.joinedCount});
}
