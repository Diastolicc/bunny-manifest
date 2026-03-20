import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_preferences.freezed.dart';
part 'user_preferences.g.dart';

@freezed
class UserPreferences with _$UserPreferences {
  const factory UserPreferences({
    @Default('') String userId,
    @Default(<String>[]) List<String> favoriteVenueTypes,
    @Default(<String>[]) List<String> favoriteVenues,
    @Default(<String>[]) List<String> visitedVenues,
    @Default(<String>[]) List<String> avoidedVenues,
    @Default(0.0) double preferredDistanceKm,
    @Default(<String>[]) List<String> preferredMusicGenres,
    @Default(<String>[]) List<String> preferredAtmosphere,
    @Default(0.0) double averageSpending,
    @Default(<String>[]) List<String> preferredTimes,
    @Default(<String>[]) List<String> socialConnections,
    @Default({}) Map<String, double> venueRatings,
    @Default({}) Map<String, int> venueVisitCounts,
    @Default({}) Map<String, double> categoryPreferences,
    @Default({}) Map<String, double> timePreferences,
    @Default({}) Map<String, double> locationPreferences,
  }) = _UserPreferences;

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      _$UserPreferencesFromJson(json);
}

@freezed
class UserBehavior with _$UserBehavior {
  const factory UserBehavior({
    @Default('') String userId,
    @Default(<BehaviorEvent>[]) List<BehaviorEvent> events,
    @Default(0) int totalPartiesCreated,
    @Default(0) int totalPartiesJoined,
    @Default(0) int totalVenuesVisited,
    @Default(0.0) double averagePartyRating,
    @Default(<String>[]) List<String> mostActiveDays,
    @Default(<String>[]) List<String> mostActiveTimes,
    @Default(<String>[]) List<String> preferredLocations,
    @Default({}) Map<String, double> venueEngagementScores,
    @Default({}) Map<String, double> categoryEngagementScores,
  }) = _UserBehavior;

  factory UserBehavior.fromJson(Map<String, dynamic> json) =>
      _$UserBehaviorFromJson(json);
}

@freezed
class BehaviorEvent with _$BehaviorEvent {
  const factory BehaviorEvent({
    required String eventType,
    required String venueId,
    required DateTime timestamp,
    @Default(0.0) double rating,
    @Default('') String category,
    @Default('') String location,
    @Default(0) int duration,
    @Default(<String>[]) List<String> tags,
  }) = _BehaviorEvent;

  factory BehaviorEvent.fromJson(Map<String, dynamic> json) =>
      _$BehaviorEventFromJson(json);
}

@freezed
class RecommendationScore with _$RecommendationScore {
  const factory RecommendationScore({
    required String venueId,
    required double score,
    required String reason,
    @Default(<String>[]) List<String> matchingFactors,
    @Default(0.0) double distanceScore,
    @Default(0.0) double preferenceScore,
    @Default(0.0) double socialScore,
    @Default(0.0) double popularityScore,
  }) = _RecommendationScore;

  factory RecommendationScore.fromJson(Map<String, dynamic> json) =>
      _$RecommendationScoreFromJson(json);
}
