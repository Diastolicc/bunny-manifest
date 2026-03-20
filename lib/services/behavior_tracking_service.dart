import 'package:bunny/models/user_preferences.dart';
import 'package:bunny/services/personalization_service.dart';

class BehaviorTrackingService {
  final PersonalizationService _personalizationService =
      PersonalizationService();

  // Track user behavior event
  void trackEvent({
    required String userId,
    required String eventType,
    required String venueId,
    double rating = 0.0,
    String category = '',
    String location = '',
    int duration = 0,
    List<String> tags = const [],
  }) {
    final event = BehaviorEvent(
      eventType: eventType,
      venueId: venueId,
      timestamp: DateTime.now(),
      rating: rating,
      category: category,
      location: location,
      duration: duration,
      tags: tags,
    );

    // Store event (in a real app, this would be stored in a database)
    _storeBehaviorEvent(userId, event);
  }

  // Track venue visit
  void trackVenueVisit({
    required String userId,
    required String venueId,
    required String venueCategory,
    required String venueLocation,
    double rating = 0.0,
    int duration = 0,
  }) {
    trackEvent(
      userId: userId,
      eventType: 'venue_visit',
      venueId: venueId,
      rating: rating,
      category: venueCategory,
      location: venueLocation,
      duration: duration,
    );
  }

  // Track party creation
  void trackPartyCreation({
    required String userId,
    required String venueId,
    required String venueCategory,
    required String venueLocation,
  }) {
    trackEvent(
      userId: userId,
      eventType: 'party_creation',
      venueId: venueId,
      category: venueCategory,
      location: venueLocation,
    );
  }

  // Track party join
  void trackPartyJoin({
    required String userId,
    required String venueId,
    required String venueCategory,
    required String venueLocation,
  }) {
    trackEvent(
      userId: userId,
      eventType: 'party_join',
      venueId: venueId,
      category: venueCategory,
      location: venueLocation,
    );
  }

  // Track venue rating
  void trackVenueRating({
    required String userId,
    required String venueId,
    required String venueCategory,
    required double rating,
  }) {
    trackEvent(
      userId: userId,
      eventType: 'venue_rating',
      venueId: venueId,
      rating: rating,
      category: venueCategory,
    );
  }

  // Track search behavior
  void trackSearch({
    required String userId,
    required String searchQuery,
    required String selectedVenueId,
    required String venueCategory,
  }) {
    trackEvent(
      userId: userId,
      eventType: 'search',
      venueId: selectedVenueId,
      category: venueCategory,
      tags: [searchQuery],
    );
  }

  // Get user behavior analysis
  UserBehavior analyzeUserBehavior({
    required String userId,
    required List<BehaviorEvent> events,
  }) {
    final userEvents = events.where((e) => e.eventType != 'search').toList();

    // Calculate statistics
    final totalPartiesCreated =
        userEvents.where((e) => e.eventType == 'party_creation').length;
    final totalPartiesJoined =
        userEvents.where((e) => e.eventType == 'party_join').length;
    final totalVenuesVisited = userEvents.map((e) => e.venueId).toSet().length;

    // Calculate average rating
    final ratedEvents = userEvents.where((e) => e.rating > 0).toList();
    final averageRating = ratedEvents.isEmpty
        ? 0.0
        : ratedEvents.map((e) => e.rating).reduce((a, b) => a + b) /
            ratedEvents.length;

    // Analyze active days and times
    final activeDays = _analyzeActiveDays(userEvents);
    final activeTimes = _analyzeActiveTimes(userEvents);
    final preferredLocations = _analyzePreferredLocations(userEvents);

    // Calculate engagement scores
    final venueEngagementScores = _calculateVenueEngagementScores(userEvents);
    final categoryEngagementScores =
        _calculateCategoryEngagementScores(userEvents);

    return UserBehavior(
      userId: userId,
      events: userEvents,
      totalPartiesCreated: totalPartiesCreated,
      totalPartiesJoined: totalPartiesJoined,
      totalVenuesVisited: totalVenuesVisited,
      averagePartyRating: averageRating,
      mostActiveDays: activeDays,
      mostActiveTimes: activeTimes,
      preferredLocations: preferredLocations,
      venueEngagementScores: venueEngagementScores,
      categoryEngagementScores: categoryEngagementScores,
    );
  }

  // Update user preferences based on behavior
  UserPreferences updatePreferencesFromBehavior({
    required UserPreferences currentPreferences,
    required List<BehaviorEvent> newEvents,
  }) {
    return _personalizationService.updatePreferencesFromBehavior(
      currentPreferences: currentPreferences,
      newEvents: newEvents,
    );
  }

  // Analyze active days of the week
  List<String> _analyzeActiveDays(List<BehaviorEvent> events) {
    final dayCounts = <int, int>{};

    for (final event in events) {
      final dayOfWeek = event.timestamp.weekday;
      dayCounts[dayOfWeek] = (dayCounts[dayOfWeek] ?? 0) + 1;
    }

    final sortedDays = dayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedDays.take(3).map((entry) => _getDayName(entry.key)).toList();
  }

  // Analyze active times of day
  List<String> _analyzeActiveTimes(List<BehaviorEvent> events) {
    final timeCounts = <String, int>{};

    for (final event in events) {
      final hour = event.timestamp.hour;
      final timeSlot = _getTimeSlot(hour);
      timeCounts[timeSlot] = (timeCounts[timeSlot] ?? 0) + 1;
    }

    final sortedTimes = timeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedTimes.take(3).map((entry) => entry.key).toList();
  }

  // Analyze preferred locations
  List<String> _analyzePreferredLocations(List<BehaviorEvent> events) {
    final locationCounts = <String, int>{};

    for (final event in events) {
      if (event.location.isNotEmpty) {
        locationCounts[event.location] =
            (locationCounts[event.location] ?? 0) + 1;
      }
    }

    final sortedLocations = locationCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedLocations.take(3).map((entry) => entry.key).toList();
  }

  // Calculate venue engagement scores
  Map<String, double> _calculateVenueEngagementScores(
      List<BehaviorEvent> events) {
    final venueScores = <String, List<double>>{};

    for (final event in events) {
      if (!venueScores.containsKey(event.venueId)) {
        venueScores[event.venueId] = [];
      }
      venueScores[event.venueId]!.add(event.rating);
    }

    final engagementScores = <String, double>{};
    for (final entry in venueScores.entries) {
      final scores = entry.value;
      final averageScore = scores.reduce((a, b) => a + b) / scores.length;
      engagementScores[entry.key] = averageScore;
    }

    return engagementScores;
  }

  // Calculate category engagement scores
  Map<String, double> _calculateCategoryEngagementScores(
      List<BehaviorEvent> events) {
    final categoryScores = <String, List<double>>{};

    for (final event in events) {
      if (event.category.isNotEmpty) {
        if (!categoryScores.containsKey(event.category)) {
          categoryScores[event.category] = [];
        }
        categoryScores[event.category]!.add(event.rating);
      }
    }

    final engagementScores = <String, double>{};
    for (final entry in categoryScores.entries) {
      final scores = entry.value;
      final averageScore = scores.reduce((a, b) => a + b) / scores.length;
      engagementScores[entry.key] = averageScore;
    }

    return engagementScores;
  }

  // Get day name from weekday number
  String _getDayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[weekday - 1];
  }

  // Get time slot from hour
  String _getTimeSlot(int hour) {
    if (hour >= 6 && hour < 12) return 'Morning';
    if (hour >= 12 && hour < 17) return 'Afternoon';
    if (hour >= 17 && hour < 22) return 'Evening';
    return 'Night';
  }

  // Store behavior event (placeholder - would integrate with database)
  void _storeBehaviorEvent(String userId, BehaviorEvent event) {
    // In a real app, this would store the event in a database
    print(
        'Storing behavior event for user $userId: ${event.eventType} at ${event.venueId}');
  }
}
