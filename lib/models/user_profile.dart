import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

class TimestampConverter implements JsonConverter<DateTime?, dynamic> {
  const TimestampConverter();

  @override
  DateTime? fromJson(dynamic json) {
    if (json == null) {
      return null;
    } else if (json is Timestamp) {
      return json.toDate();
    } else if (json is String) {
      return DateTime.parse(json);
    } else if (json is int) {
      return DateTime.fromMillisecondsSinceEpoch(json);
    }
    throw ArgumentError('Cannot convert $json to DateTime');
  }

  @override
  dynamic toJson(DateTime? dateTime) => dateTime?.toIso8601String();
}

@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    required String displayName,
    String? email,
    String? phoneNumber,
    String? profileImageUrl,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? lastLoginAt,
    // Verification fields
    @Default(false) bool isVerified,
    @Default('unverified')
    String
        verificationStatus, // 'unverified', 'pending', 'verified', 'rejected'
    String? fullName,
    DateTime? birthday,
    @TimestampConverter() DateTime? verificationAppliedAt,
    @TimestampConverter() DateTime? verificationApprovedAt,
    String? verificationRejectionReason,
    // Admin token
    String? tokenAdmin,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}
