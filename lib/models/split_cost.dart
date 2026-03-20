import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'split_cost.freezed.dart';
part 'split_cost.g.dart';

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
class SplitCost with _$SplitCost {
  const factory SplitCost({
    required String id,
    required String groupId,
    required double amount,
    required String description,
    required String payerId,
    required String owerId,
    required String status, // 'pending' or 'paid'
    @TimestampConverter() required DateTime createdAt,
    @TimestampConverter() DateTime? paidAt,
  }) = _SplitCost;

  factory SplitCost.fromJson(Map<String, dynamic> json) =>
      _$SplitCostFromJson(json);
}
