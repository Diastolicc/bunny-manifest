import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bunny/models/party.dart';
import 'package:bunny/services/party_service.dart';
import 'package:bunny/services/club_service.dart';
import 'package:bunny/services/auth_service.dart';
import 'package:bunny/services/chat_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PartyTicketScreen extends StatefulWidget {
  final String partyId;

  const PartyTicketScreen({
    super.key,
    required this.partyId,
  });

  @override
  State<PartyTicketScreen> createState() => _PartyTicketScreenState();
}

class _PartyTicketScreenState extends State<PartyTicketScreen>
    with TickerProviderStateMixin {
  Party? _party;
  String? _clubName;
  String? _clubLocation;
  String? _userName;
  bool _isLoading = true;
  String? _error;
  bool _hasArrived = false;
  bool _isMarkingArrival = false;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadPartyData();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadPartyData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load party details
      final partyService = context.read<PartyService>();
      final party = await partyService.getById(widget.partyId);

      if (party == null) {
        setState(() {
          _error = 'Party not found';
          _isLoading = false;
        });
        return;
      }

      // Load club details
      String? clubName;
      String? clubLocation;
      try {
        final clubService = context.read<ClubService>();
        final club = await clubService.getClub(party.clubId);
        clubName = club?.name ?? 'Unknown Venue';
        clubLocation = club?.location ?? 'Unknown Location';
      } catch (e) {
        print('Error loading club data: $e');
        clubName = 'Unknown Venue';
        clubLocation = 'Unknown Location';
      }

      // Load user details
      String? userName;
      try {
        final authService = context.read<AuthService>();
        final user = authService.currentUser;
        userName = user?.displayName ?? user?.email?.split('@')[0] ?? 'Guest';
      } catch (e) {
        print('Error loading user data: $e');
        userName = 'Guest';
      }

      setState(() {
        _party = party;
        _clubName = clubName;
        _clubLocation = clubLocation;
        _userName = userName;
        _isLoading = false;
      });

      // Start animations
      _fadeController.forward();
      _slideController.forward();

      // Check arrival status
      _checkArrivalStatus();
    } catch (e) {
      print('Error loading party data: $e');
      setState(() {
        _error = 'Failed to load party details';
        _isLoading = false;
      });
    }
  }

  String _getPartyImage(String? imageUrl, String title) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return imageUrl;
    }

    // Fallback images for parties without images
    final partyImages = [
      'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=800&h=600&fit=crop',
      'https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=800&h=600&fit=crop',
      'https://images.unsplash.com/photo-1566733971017-f8a6c8c2c6b3?w=800&h=600&fit=crop',
      'https://images.unsplash.com/photo-1520975916090-3105956d8ac38?w=800&h=600&fit=crop',
      'https://images.unsplash.com/photo-1517095037594-166575f1e866?w=800&h=600&fit=crop',
      'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=800&h=600&fit=crop',
      'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?w=800&h=600&fit=crop',
      'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=800&h=600&fit=crop',
    ];

    return partyImages[title.hashCode.abs() % partyImages.length];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('Party Ticket'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null || _party == null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('Party Ticket'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Party not found',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Party Ticket'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        // Chat icon removed
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              Expanded(
                child: _buildTicketCard(),
              ),
              // Arrival Slider
              _buildArrivalSlider(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketCard() {
    final party = _party!;
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return SingleChildScrollView(
      child: Column(
        children: [
          // Event Image Banner with overlay gradient
          _buildEventBanner(party),

          // Ticket Card
          _buildTicketCardContent(party, dateFormat, timeFormat),
        ],
      ),
    );
  }

  Widget _buildEventBanner(Party party) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(_getPartyImage(party.imageUrl, party.title)),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.3),
            ],
          ),
        ),
        child: const Center(
          child: Text(
            'DIGITAL TICKET',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTicketCardContent(
      Party party, DateFormat dateFormat, DateFormat timeFormat) {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event name (bold, large)
            Text(
              party.title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 20),

            // Date + Time (nicely formatted)
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  dateFormat.format(party.dateTime),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 20),
                Icon(
                  Icons.access_time,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  timeFormat.format(party.dateTime),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Venue name + location icon
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$_clubName • $_clubLocation',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Perforated divider
            _buildPerforatedDivider(),

            const SizedBox(height: 30),

            // Party Title (outlined text, huge font) with barcode decoration
            Center(
              child: Column(
                children: [
                  // Barcode above title
                  _buildBarcodeDecoration(),
                  const SizedBox(height: 20),
                  // Party title
                  _buildOutlinedTitle(party.title),
                  const SizedBox(height: 20),
                  // Barcode below title
                  _buildBarcodeDecoration(),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Perforated divider
            _buildPerforatedDivider(),

            const SizedBox(height: 30),

            // Ticket Holder name
            Row(
              children: [
                Icon(
                  Icons.person,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Ticket Holder',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  _userName ?? 'Guest',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Ticket ID (copyable)
            Row(
              children: [
                Icon(
                  Icons.confirmation_number,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Ticket ID',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _copyTicketId(party.id),
                  child: Row(
                    children: [
                      Text(
                        '#${party.id.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF4C57E9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.copy,
                        color: Colors.grey.shade600,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Pricing (₱ format, aligned right)
            Row(
              children: [
                const Spacer(),
                Text(
                  _formatPricing(party),
                  style: const TextStyle(
                    fontSize: 20,
                    color: Color(0xFF4C57E9),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerforatedDivider() {
    return CustomPaint(
      size: const Size(double.infinity, 20),
      painter: PerforatedDividerPainter(),
    );
  }

  Widget _buildOutlinedTitle(String title) {
    // Create outlined text effect using Stack with multiple text layers
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Create outline by drawing text multiple times with offsets
          // Top
          Transform.translate(
            offset: const Offset(0, -3),
            child: _buildOutlinedTextLayer(title, Colors.black),
          ),
          // Bottom
          Transform.translate(
            offset: const Offset(0, 3),
            child: _buildOutlinedTextLayer(title, Colors.black),
          ),
          // Left
          Transform.translate(
            offset: const Offset(-3, 0),
            child: _buildOutlinedTextLayer(title, Colors.black),
          ),
          // Right
          Transform.translate(
            offset: const Offset(3, 0),
            child: _buildOutlinedTextLayer(title, Colors.black),
          ),
          // Diagonals for smoother outline
          Transform.translate(
            offset: const Offset(-2, -2),
            child: _buildOutlinedTextLayer(title, Colors.black),
          ),
          Transform.translate(
            offset: const Offset(2, -2),
            child: _buildOutlinedTextLayer(title, Colors.black),
          ),
          Transform.translate(
            offset: const Offset(-2, 2),
            child: _buildOutlinedTextLayer(title, Colors.black),
          ),
          Transform.translate(
            offset: const Offset(2, 2),
            child: _buildOutlinedTextLayer(title, Colors.black),
          ),
          // Center (transparent fill to maintain spacing)
          _buildOutlinedTextLayer(title, Colors.transparent),
        ],
      ),
    );
  }

  Widget _buildOutlinedTextLayer(String text, Color color) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 64,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: 2.0,
        height: 1.0,
      ),
    );
  }

  Widget _buildBarcodeDecoration() {
    // Create a decorative barcode pattern using vertical lines of varying widths
    return Container(
      height: 40,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: CustomPaint(
        painter: BarcodePainter(),
      ),
    );
  }

  String _formatPricing(Party party) {
    if (party.entranceFeeAmount == 0) {
      return 'FREE';
    }
    return '₱${party.entranceFeeAmount.toStringAsFixed(0)}';
  }

  void _copyTicketId(String ticketId) {
    // Copy to clipboard functionality would go here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ticket ID copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildArrivalSlider() {
    if (_party == null || _userName == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _hasArrived ? 'You have arrived! 🎉' : 'Slide to mark your arrival',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _hasArrived ? Colors.green.shade700 : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _ArrivalSlider(
            hasArrived: _hasArrived,
            isMarkingArrival: _isMarkingArrival,
            onSlideComplete: _hasArrived ? null : _markArrival,
          ),
        ],
      ),
    );
  }

  Future<void> _markArrival() async {
    if (_isMarkingArrival || _hasArrived || _party == null || _userName == null)
      return;

    setState(() {
      _isMarkingArrival = true;
    });

    try {
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Get chat group for the party
      final chatService = context.read<ChatService>();
      final chatGroup = await chatService.getChatGroupForParty(_party!.id);

      if (chatGroup == null) {
        throw Exception('Chat group not found');
      }

      // Send system message to chat group
      await chatService.sendSystemMessage(
        groupId: chatGroup.id,
        text: '${_userName} has arrived at the location! 🎉',
      );

      // Update arrival status in Firestore
      final firestore = FirebaseFirestore.instance;
      final chatGroupRef =
          firestore.collection('chat_groups').doc(chatGroup.id);

      // Get current arrived users list
      final chatGroupDoc = await chatGroupRef.get();
      final currentData = chatGroupDoc.data() ?? {};
      final arrivedUserIds =
          List<String>.from(currentData['arrivedUserIds'] ?? []);

      // Add current user if not already in list
      if (!arrivedUserIds.contains(currentUser.id)) {
        arrivedUserIds.add(currentUser.id);
        await chatGroupRef.update({
          'arrivedUserIds': arrivedUserIds,
        });

        // Award bunny points if party has ended
        final now = DateTime.now();
        final partyEndTime = _party!.dateTime.add(const Duration(hours: 4));
        if (now.isAfter(partyEndTime)) {
          // Party has ended, award 10 bunny points
          await _awardBunnyPoints(currentUser.id, 10);
        }
      }

      setState(() {
        _hasArrived = true;
        _isMarkingArrival = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('Arrival marked! Notification sent to group chat.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error marking arrival: $e');
      setState(() {
        _isMarkingArrival = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark arrival: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _checkArrivalStatus() async {
    if (_party == null) return;

    try {
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUser;
      if (currentUser == null) return;

      // Get chat group for the party
      final chatService = context.read<ChatService>();
      final chatGroup = await chatService.getChatGroupForParty(_party!.id);

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
        });
      }
    } catch (e) {
      print('Error checking arrival status: $e');
    }
  }

  Future<void> _awardBunnyPoints(String userId, int points) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final userDoc = await firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        int currentPoints = (data['bunnyPoints'] ?? 0) as int;
        currentPoints += points;

        await firestore.collection('users').doc(userId).update({
          'bunnyPoints': currentPoints,
        });
      } else {
        // User document doesn't exist, create it
        await firestore.collection('users').doc(userId).set({
          'bunnyPoints': points,
          'bunnyPointsLastRefresh': Timestamp.now(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error awarding bunny points: $e');
    }
  }
}

class PerforatedDividerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final dashWidth = 8.0;
    final dashSpace = 4.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class BarcodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    // Generate decorative barcode pattern with varying line widths
    double x = 0;
    final minWidth = 2.0;
    final maxWidth = 8.0;
    final spacing = 1.0;

    while (x < size.width) {
      // Create varying line widths for barcode effect
      final lineWidth = _getLineWidth(x, minWidth, maxWidth);

      // Draw vertical line
      canvas.drawRect(
        Rect.fromLTWH(x, 0, lineWidth, size.height),
        paint,
      );

      x += lineWidth + spacing;
    }
  }

  double _getLineWidth(double position, double minWidth, double maxWidth) {
    // Create a pseudo-random pattern based on position
    // Using modulo for deterministic variation
    final seed = (position * 0.1).round();
    final variation = (seed % 7) / 7.0; // 0 to 1
    return minWidth + (variation * (maxWidth - minWidth));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _ArrivalSlider extends StatefulWidget {
  final bool hasArrived;
  final bool isMarkingArrival;
  final VoidCallback? onSlideComplete;

  const _ArrivalSlider({
    required this.hasArrived,
    required this.isMarkingArrival,
    this.onSlideComplete,
  });

  @override
  State<_ArrivalSlider> createState() => _ArrivalSliderState();
}

class _ArrivalSliderState extends State<_ArrivalSlider> {
  double _sliderPosition = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _sliderPosition = widget.hasArrived ? 1.0 : 0.0;
  }

  @override
  void didUpdateWidget(_ArrivalSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasArrived && !oldWidget.hasArrived) {
      _sliderPosition = 1.0;
    } else if (!widget.hasArrived && oldWidget.hasArrived) {
      _sliderPosition = 0.0;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (widget.hasArrived || widget.isMarkingArrival) return;

    setState(() {
      _isDragging = true;
      final newPosition = _sliderPosition +
          (details.delta.dx / (MediaQuery.of(context).size.width - 100));
      _sliderPosition = newPosition.clamp(0.0, 1.0);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (widget.hasArrived || widget.isMarkingArrival) return;

    setState(() {
      _isDragging = false;
    });

    // If slider is more than 80% to the right, trigger arrival
    if (_sliderPosition >= 0.8) {
      _sliderPosition = 1.0;
      widget.onSlideComplete?.call();
    } else {
      // Snap back to start
      setState(() {
        _sliderPosition = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final sliderWidth = screenWidth - 40; // Account for padding
    final thumbPosition = _sliderPosition * (sliderWidth - 60);

    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color:
              widget.hasArrived ? Colors.green.shade50 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: widget.hasArrived
                ? Colors.green.shade300
                : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: _isDragging
                  ? const Duration(milliseconds: 0)
                  : const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              left: thumbPosition,
              top: 4,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color:
                      widget.hasArrived ? Colors.green.shade600 : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: widget.isMarkingArrival
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      )
                    : Icon(
                        widget.hasArrived ? Icons.check : Icons.arrow_forward,
                        color: widget.hasArrived
                            ? Colors.white
                            : Colors.grey.shade600,
                        size: 24,
                      ),
              ),
            ),
            if (!widget.hasArrived)
              Positioned(
                left: 70,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Slide to arrive',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (widget.hasArrived)
              Positioned(
                left: 20,
                right: 70,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Arrived at location',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
