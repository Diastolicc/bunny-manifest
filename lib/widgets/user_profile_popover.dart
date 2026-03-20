import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bunny/models/user_profile.dart';
import 'package:bunny/services/user_service.dart';
import 'package:bunny/services/party_service.dart';

Future<void> showUserProfilePopover({
  required BuildContext context,
  required Rect anchorRect,
  required String userId,
}) async {
  final overlay = Overlay.of(context);
  if (overlay == null) return;

  late OverlayEntry barrierEntry;
  late OverlayEntry contentEntry;

  barrierEntry = OverlayEntry(
    builder: (_) => GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        barrierEntry.remove();
        contentEntry.remove();
      },
      child: const SizedBox.expand(),
    ),
  );

  contentEntry = OverlayEntry(
    builder: (ctx) {
      final screenSize = MediaQuery.of(ctx).size;
      const double cardWidth = 300;
      const double cardPadding = 12;

      double left = anchorRect.right + 8;
      double top = anchorRect.top - 8;

      if (left + cardWidth + cardPadding > screenSize.width) {
        left = anchorRect.left - cardWidth - 8;
      }
      if (left < cardPadding) {
        left = cardPadding;
      }
      final double maxTop = screenSize.height - 200; // keep inside viewport
      if (top > maxTop) top = maxTop;
      if (top < cardPadding) top = cardPadding;

      return Positioned(
        left: left,
        top: top,
        width: cardWidth,
        child: _UserPopoverCard(
          userId: userId,
          onClose: () {
            barrierEntry.remove();
            contentEntry.remove();
          },
        ),
      );
    },
  );

  overlay.insert(barrierEntry);
  overlay.insert(contentEntry);
}

class _UserPopoverCard extends StatefulWidget {
  final String userId;
  final VoidCallback onClose;
  const _UserPopoverCard({required this.userId, required this.onClose});

  @override
  State<_UserPopoverCard> createState() => _UserPopoverCardState();
}

class _UserPopoverCardState extends State<_UserPopoverCard> {
  UserProfile? _profile;
  int _hosted = 0;
  int _joined = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final userService = context.read<UserService>();
      final partyService = context.read<PartyService>();
      final prof = await userService.getUserProfile(widget.userId);
      int hosted = 0;
      int joined = 0;
      try {
        final all = await partyService.getAllParties();
        hosted = all.where((p) => p.hostUserId == widget.userId).length;
        joined = all
            .where((p) =>
                p.attendeeUserIds.contains(widget.userId) &&
                p.hostUserId != widget.userId)
            .length;
      } catch (_) {}
      if (mounted) {
        setState(() {
          _profile = prof;
          _hosted = hosted;
          _joined = joined;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, 8)),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: _loading
            ? _Skeleton()
            : (_profile == null
                ? const Text('User not found',
                    style: TextStyle(color: Colors.black54))
                : _Content(
                    profile: _profile!,
                    hosted: _hosted,
                    joined: _joined,
                    onClose: widget.onClose)),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget bar({double height = 12, double width = 140}) => Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6)),
        );
    return Row(
      children: [
        CircleAvatar(radius: 24, backgroundColor: Colors.grey.shade200),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(height: 14, width: 160),
              const SizedBox(height: 8),
              bar(width: 120),
              const SizedBox(height: 12),
              Row(children: [
                bar(width: 60),
                const SizedBox(width: 12),
                bar(width: 60)
              ])
            ],
          ),
        )
      ],
    );
  }
}

class _Content extends StatelessWidget {
  final UserProfile profile;
  final int hosted;
  final int joined;
  final VoidCallback onClose;
  const _Content(
      {required this.profile,
      required this.hosted,
      required this.joined,
      required this.onClose});

  String _memberSince(DateTime? dt) {
    if (dt == null) return 'Member since —';
    const months = [
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
    return 'Member since ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.displayName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(_memberSince(profile.createdAt),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 18),
              splashRadius: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _stat('Hosted', hosted),
            const SizedBox(width: 16),
            _stat('Joined', joined),
          ],
        )
      ],
    );
  }

  Widget _stat(String label, int value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value.toString(),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}
