import 'package:freezed_annotation/freezed_annotation.dart';

part 'club.freezed.dart';
part 'club.g.dart';

@freezed
class Club with _$Club {
  const factory Club({
    required String id,
    required String name,
    required String location,
    @Default('') String description,
    @Default('') String imageUrl,
    @Default('') String mapsLink,
    @Default('') String city,
    @Default('') String area,
    @Default(<String>[]) List<String> categories,
    @Default(0.0) double rating,
    @Default(0.0) double distanceKm,
  }) = _Club;

  factory Club.fromJson(Map<String, dynamic> json) => _$ClubFromJson(json);
}
