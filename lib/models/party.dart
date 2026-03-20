import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'party.freezed.dart';
part 'party.g.dart';

class TimestampConverter implements JsonConverter<DateTime, dynamic> {
  const TimestampConverter();

  @override
  DateTime fromJson(dynamic json) {
    if (json == null) {
      return DateTime.now(); // Default to current time if null
    }
    if (json is Timestamp) {
      return json.toDate();
    } else if (json is String) {
      return DateTime.parse(json);
    } else if (json is int) {
      return DateTime.fromMillisecondsSinceEpoch(json);
    }
    throw ArgumentError('Cannot convert $json to DateTime');
  }

  @override
  dynamic toJson(DateTime dateTime) => dateTime.toIso8601String();
}

@freezed
class Party with _$Party {
  const factory Party({
    required String id,
    required String clubId,
    required String hostUserId,
    String? hostName,
    required String title,
    @TimestampConverter() required DateTime dateTime,
    @Default(<String>[]) List<String> attendeeUserIds,
    @Default(50) int capacity,
    @Default('') String description,
    @Default('Any') String preferredGender,
    String? imageUrl,
    int? budgetPerHead,
    // New fields
    @Default('') String paymentMethod,
    @Default(<String>[]) List<String> drinkingTags,
    @Default('') String reservationType,
    @Default('') String inviteCode,
    // Entrance fee fields
    @Default(false) bool hasEntranceFee,
    @Default(0) int entranceFeeAmount,
    // Cancellation fields
    @Default(false) bool? isCancelled,
    @TimestampConverter() DateTime? cancelledAt,
    // Request acceptance field
    @Default(true) bool isAcceptingRequests,
  }) = _Party;

  const Party._();

  bool get isFull => attendeeUserIds.length >= capacity;

  factory Party.fromJson(Map<String, dynamic> json) => _$PartyFromJson(json);
}
