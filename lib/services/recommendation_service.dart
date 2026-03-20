import 'dart:math';
import 'package:bunny/models/user_preferences.dart';
import 'package:bunny/models/club.dart';
import 'package:bunny/services/personalization_service.dart';

class RecommendationService {
  final PersonalizationService _personalizationService =
      PersonalizationService();

  // Get personalized venue recommendations
  Future<List<Club>> getPersonalizedRecommendations({
    required List<Club> allVenues,
    required UserPreferences userPreferences,
    required UserBehavior userBehavior,
    double? userLatitude,
    double? userLongitude,
    int limit = 10,
  }) async {
    // Calculate recommendation scores
    final scores = _personalizationService.calculateRecommendations(
      venues: allVenues,
      userPreferences: userPreferences,
      userBehavior: userBehavior,
      userLatitude: userLatitude,
      userLongitude: userLongitude,
    );

    // Filter out venues user has already visited recently
    final recentVenues = _getRecentVenues(userBehavior, days: 30);
    final filteredScores =
        scores.where((score) => !recentVenues.contains(score.venueId)).toList();

    // Get top recommendations
    final topScores = filteredScores.take(limit).toList();

    // Convert back to Club objects
    final Map<String, Club> venueMap = {
      for (final venue in allVenues) venue.id: venue
    };

    return topScores
        .map((score) => venueMap[score.venueId])
        .where((venue) => venue != null)
        .cast<Club>()
        .toList();
  }

  // Get trending venues based on user preferences
  Future<List<Club>> getTrendingRecommendations({
    required List<Club> allVenues,
    required UserPreferences userPreferences,
    required UserBehavior userBehavior,
    double? userLatitude,
    double? userLongitude,
    int limit = 5,
  }) async {
    // Filter venues by user preferences
    final preferredVenues = allVenues.where((venue) {
      return venue.categories.any(
          (category) => userPreferences.favoriteVenueTypes.contains(category));
    }).toList();

    // Sort by rating and distance
    preferredVenues.sort((a, b) {
      final ratingComparison = b.rating.compareTo(a.rating);
      if (ratingComparison != 0) return ratingComparison;
      return a.distanceKm.compareTo(b.distanceKm);
    });

    return preferredVenues.take(limit).toList();
  }

  // Get similar venues based on a reference venue
  Future<List<Club>> getSimilarVenues({
    required Club referenceVenue,
    required List<Club> allVenues,
    required UserPreferences userPreferences,
    int limit = 5,
  }) async {
    final List<MapEntry<Club, double>> scoredVenues = [];

    for (final venue in allVenues) {
      if (venue.id == referenceVenue.id) continue;

      double similarityScore = 0.0;
      int factors = 0;

      // Category similarity
      final commonCategories = venue.categories
          .where((cat) => referenceVenue.categories.contains(cat))
          .length;
      if (referenceVenue.categories.isNotEmpty) {
        similarityScore +=
            (commonCategories / referenceVenue.categories.length) * 0.4;
        factors++;
      }

      // Rating similarity
      final ratingDiff = (venue.rating - referenceVenue.rating).abs();
      similarityScore += (1.0 - (ratingDiff / 5.0)) * 0.3;
      factors++;

      // Distance similarity (if both have distance data)
      if (venue.distanceKm > 0 && referenceVenue.distanceKm > 0) {
        final distanceDiff =
            (venue.distanceKm - referenceVenue.distanceKm).abs();
        final maxDistance = max(venue.distanceKm, referenceVenue.distanceKm);
        similarityScore += (1.0 - (distanceDiff / maxDistance)) * 0.3;
        factors++;
      }

      if (factors > 0) {
        scoredVenues.add(MapEntry(venue, similarityScore / factors));
      }
    }

    // Sort by similarity score
    scoredVenues.sort((a, b) => b.value.compareTo(a.value));

    return scoredVenues.take(limit).map((entry) => entry.key).toList();
  }

  // Get recommendations based on friends' preferences
  Future<List<Club>> getSocialRecommendations({
    required List<Club> allVenues,
    required UserPreferences userPreferences,
    required List<String> friendIds,
    int limit = 5,
  }) async {
    if (friendIds.isEmpty) return [];

    // This would integrate with social features
    // For now, return venues that are popular in general
    final popularVenues =
        allVenues.where((venue) => venue.rating >= 4.0).toList();

    popularVenues.sort((a, b) => b.rating.compareTo(a.rating));

    return popularVenues.take(limit).toList();
  }

  // Get time-based recommendations
  Future<List<Club>> getTimeBasedRecommendations({
    required List<Club> allVenues,
    required UserPreferences userPreferences,
    required UserBehavior userBehavior,
    required DateTime currentTime,
    int limit = 5,
  }) async {
    // This would use currentTime for time-based filtering
    // For now, we'll use a simplified approach

    // Filter venues based on time preferences
    final timeAppropriateVenues = allVenues.where((venue) {
      // This would check venue hours and user's preferred times
      return true; // Simplified for now
    }).toList();

    // Sort by user's time preferences
    timeAppropriateVenues.sort((a, b) {
      // This would use userBehavior.mostActiveTimes and mostActiveDays
      return b.rating.compareTo(a.rating);
    });

    return timeAppropriateVenues.take(limit).toList();
  }

  // Get diverse recommendations (mix of different types)
  Future<List<Club>> getDiverseRecommendations({
    required List<Club> allVenues,
    required UserPreferences userPreferences,
    required UserBehavior userBehavior,
    double? userLatitude,
    double? userLongitude,
    int limit = 10,
  }) async {
    final List<Club> diverseVenues = [];
    final Set<String> usedCategories = {};
    final Set<String> usedVenues = {};

    // Get personalized recommendations first
    final personalized = await getPersonalizedRecommendations(
      allVenues: allVenues,
      userPreferences: userPreferences,
      userBehavior: userBehavior,
      userLatitude: userLatitude,
      userLongitude: userLongitude,
      limit: limit ~/ 2,
    );

    for (final venue in personalized) {
      if (diverseVenues.length >= limit) break;

      // Check if we need more diversity
      final hasNewCategory =
          venue.categories.any((cat) => !usedCategories.contains(cat));
      if (hasNewCategory || diverseVenues.isEmpty) {
        diverseVenues.add(venue);
        usedVenues.add(venue.id);
        usedCategories.addAll(venue.categories);
      }
    }

    // Fill remaining slots with different categories
    for (final venue in allVenues) {
      if (diverseVenues.length >= limit) break;
      if (usedVenues.contains(venue.id)) continue;

      final hasNewCategory =
          venue.categories.any((cat) => !usedCategories.contains(cat));
      if (hasNewCategory) {
        diverseVenues.add(venue);
        usedVenues.add(venue.id);
        usedCategories.addAll(venue.categories);
      }
    }

    return diverseVenues;
  }

  // Helper method to get recently visited venues
  List<String> _getRecentVenues(UserBehavior userBehavior, {int days = 30}) {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));

    return userBehavior.events
        .where((event) => event.timestamp.isAfter(cutoffDate))
        .map((event) => event.venueId)
        .toSet()
        .toList();
  }

  // Get recommendation explanation
  String getRecommendationExplanation(RecommendationScore score) {
    final explanations = <String>[];

    if (score.distanceScore > 0.7) {
      explanations.add('Close to your location');
    }

    if (score.preferenceScore > 0.7) {
      explanations.add('Matches your preferences');
    }

    if (score.socialScore > 0.7) {
      explanations.add('Popular with your friends');
    }

    if (score.popularityScore > 0.7) {
      explanations.add('Highly rated venue');
    }

    if (explanations.isEmpty) {
      return 'Recommended based on your activity patterns';
    }

    return explanations.join(' and ');
  }
}
