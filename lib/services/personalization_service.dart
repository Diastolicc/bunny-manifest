import 'package:bunny/models/user_preferences.dart';
import 'package:bunny/models/club.dart';

class PersonalizationService {
  // Machine Learning weights for recommendation algorithm
  static const double _distanceWeight = 0.25;
  static const double _preferenceWeight = 0.35;
  static const double _socialWeight = 0.20;
  static const double _popularityWeight = 0.20;

  // Calculate personalized recommendation scores
  List<RecommendationScore> calculateRecommendations({
    required List<Club> venues,
    required UserPreferences userPreferences,
    required UserBehavior userBehavior,
    double? userLatitude,
    double? userLongitude,
  }) {
    final List<RecommendationScore> scores = [];

    for (final venue in venues) {
      final score = _calculateVenueScore(
        venue: venue,
        userPreferences: userPreferences,
        userBehavior: userBehavior,
        userLatitude: userLatitude,
        userLongitude: userLongitude,
      );
      scores.add(score);
    }

    // Sort by score (highest first)
    scores.sort((a, b) => b.score.compareTo(a.score));
    return scores;
  }

  // Calculate individual venue score
  RecommendationScore _calculateVenueScore({
    required Club venue,
    required UserPreferences userPreferences,
    required UserBehavior userBehavior,
    double? userLatitude,
    double? userLongitude,
  }) {
    final List<String> matchingFactors = [];

    // Distance score (closer is better)
    double distanceScore = _calculateDistanceScore(venue, userLatitude,
        userLongitude, userPreferences.preferredDistanceKm);

    // Preference score (based on user preferences)
    double preferenceScore = _calculatePreferenceScore(venue, userPreferences);

    // Social score (based on friends' preferences)
    double socialScore = _calculateSocialScore(venue, userPreferences);

    // Popularity score (based on venue popularity and user behavior)
    double popularityScore = _calculatePopularityScore(venue, userBehavior);

    // Calculate weighted total score
    double totalScore = (distanceScore * _distanceWeight) +
        (preferenceScore * _preferenceWeight) +
        (socialScore * _socialWeight) +
        (popularityScore * _popularityWeight);

    // Generate reason for recommendation
    String reason = _generateRecommendationReason(
        venue, distanceScore, preferenceScore, socialScore, popularityScore);

    // Add matching factors
    if (distanceScore > 0.7) matchingFactors.add('Close to you');
    if (preferenceScore > 0.7) matchingFactors.add('Matches your preferences');
    if (socialScore > 0.7) matchingFactors.add('Popular with your friends');
    if (popularityScore > 0.7) matchingFactors.add('Highly rated venue');

    return RecommendationScore(
      venueId: venue.id,
      score: totalScore,
      reason: reason,
      matchingFactors: matchingFactors,
      distanceScore: distanceScore,
      preferenceScore: preferenceScore,
      socialScore: socialScore,
      popularityScore: popularityScore,
    );
  }

  // Calculate distance-based score
  double _calculateDistanceScore(
      Club venue, double? userLat, double? userLng, double preferredDistance) {
    if (userLat == null || userLng == null)
      return 0.5; // Neutral score if no location

    final double distance = venue.distanceKm;
    final double maxDistance = preferredDistance > 0 ? preferredDistance : 10.0;

    if (distance <= maxDistance) {
      return 1.0 -
          (distance / maxDistance) * 0.5; // Score decreases with distance
    } else {
      return 0.5 -
          ((distance - maxDistance) / maxDistance) *
              0.4; // Lower score for far venues
    }
  }

  // Calculate preference-based score
  double _calculatePreferenceScore(Club venue, UserPreferences preferences) {
    double score = 0.0;
    int factors = 0;

    // Check venue type preferences
    for (final category in venue.categories) {
      if (preferences.favoriteVenueTypes.contains(category)) {
        score += 0.3;
        factors++;
      }
    }

    // Check if venue is in favorites
    if (preferences.favoriteVenues.contains(venue.id)) {
      score += 0.4;
      factors++;
    }

    // Check if venue was avoided
    if (preferences.avoidedVenues.contains(venue.id)) {
      score -= 0.5;
      factors++;
    }

    // Check venue rating vs user's average
    if (preferences.venueRatings.containsKey(venue.id)) {
      final userRating = preferences.venueRatings[venue.id]!;
      score += (userRating / 5.0) * 0.3;
      factors++;
    }

    return factors > 0 ? (score / factors).clamp(0.0, 1.0) : 0.5;
  }

  // Calculate social-based score
  double _calculateSocialScore(Club venue, UserPreferences preferences) {
    if (preferences.socialConnections.isEmpty) return 0.5;

    // This would integrate with social features
    // For now, return a neutral score
    return 0.5;
  }

  // Calculate popularity-based score
  double _calculatePopularityScore(Club venue, UserBehavior behavior) {
    double score = 0.0;

    // Base score from venue rating
    score += (venue.rating / 5.0) * 0.4;

    // Boost score if user has visited similar venues
    for (final category in venue.categories) {
      if (behavior.categoryEngagementScores.containsKey(category)) {
        score += behavior.categoryEngagementScores[category]! * 0.3;
      }
    }

    // Boost score if user has high engagement with this venue
    if (behavior.venueEngagementScores.containsKey(venue.id)) {
      score += behavior.venueEngagementScores[venue.id]! * 0.3;
    }

    return score.clamp(0.0, 1.0);
  }

  // Generate human-readable recommendation reason
  String _generateRecommendationReason(
    Club venue,
    double distanceScore,
    double preferenceScore,
    double socialScore,
    double popularityScore,
  ) {
    final List<String> reasons = [];

    if (distanceScore > 0.8) {
      reasons.add('Very close to you');
    } else if (distanceScore > 0.6) {
      reasons.add('Close to you');
    }

    if (preferenceScore > 0.8) {
      reasons.add('Perfect match for your preferences');
    } else if (preferenceScore > 0.6) {
      reasons.add('Matches your preferences');
    }

    if (popularityScore > 0.8) {
      reasons.add('Highly rated venue');
    } else if (popularityScore > 0.6) {
      reasons.add('Well-rated venue');
    }

    if (reasons.isEmpty) {
      return 'Based on your location and preferences';
    }

    return reasons.join(', ');
  }

  // Update user preferences based on behavior
  UserPreferences updatePreferencesFromBehavior({
    required UserPreferences currentPreferences,
    required List<BehaviorEvent> newEvents,
  }) {
    var updatedPreferences = currentPreferences;

    for (final event in newEvents) {
      // Update venue ratings
      if (event.rating > 0) {
        updatedPreferences = updatedPreferences.copyWith(
          venueRatings: {
            ...updatedPreferences.venueRatings,
            event.venueId: event.rating,
          },
        );
      }

      // Update visit counts
      final currentCount =
          updatedPreferences.venueVisitCounts[event.venueId] ?? 0;
      updatedPreferences = updatedPreferences.copyWith(
        venueVisitCounts: {
          ...updatedPreferences.venueVisitCounts,
          event.venueId: currentCount + 1,
        },
      );

      // Update category preferences
      if (event.category.isNotEmpty) {
        final currentScore =
            updatedPreferences.categoryPreferences[event.category] ?? 0.0;
        final newScore = (currentScore + (event.rating / 5.0)) / 2.0;
        updatedPreferences = updatedPreferences.copyWith(
          categoryPreferences: {
            ...updatedPreferences.categoryPreferences,
            event.category: newScore,
          },
        );
      }
    }

    return updatedPreferences;
  }

  // Learn from user behavior patterns
  UserBehavior analyzeBehaviorPatterns({
    required UserBehavior currentBehavior,
    required List<BehaviorEvent> newEvents,
  }) {
    var updatedBehavior = currentBehavior;

    // Update engagement scores
    for (final event in newEvents) {
      // Update venue engagement
      final currentScore =
          updatedBehavior.venueEngagementScores[event.venueId] ?? 0.0;
      final newScore = (currentScore + (event.rating / 5.0)) / 2.0;
      updatedBehavior = updatedBehavior.copyWith(
        venueEngagementScores: {
          ...updatedBehavior.venueEngagementScores,
          event.venueId: newScore,
        },
      );

      // Update category engagement
      if (event.category.isNotEmpty) {
        final currentScore =
            updatedBehavior.categoryEngagementScores[event.category] ?? 0.0;
        final newScore = (currentScore + (event.rating / 5.0)) / 2.0;
        updatedBehavior = updatedBehavior.copyWith(
          categoryEngagementScores: {
            ...updatedBehavior.categoryEngagementScores,
            event.category: newScore,
          },
        );
      }
    }

    return updatedBehavior;
  }
}
