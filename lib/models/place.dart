import 'package:freezed_annotation/freezed_annotation.dart';

part 'place.freezed.dart';
part 'place.g.dart';

@freezed
class Place with _$Place {
  const factory Place({
    String? placeId,
    String? name,
    String? formattedAddress,
    double? rating,
    int? userRatingsTotal,
    List<String>? types,
    String? photoReference,
    double? latitude,
    double? longitude,
    String? website,
    String? phoneNumber,
    bool? isOpen,
    List<String>? openingHours,
    String? priceLevel,
  }) = _Place;

  factory Place.fromJson(Map<String, dynamic> json) => _$PlaceFromJson(json);

  // Create Place from PlaceDetails
  factory Place.fromPlaceDetails(PlaceDetails details) {
    return Place(
      placeId: details.placeId,
      name: details.name,
      formattedAddress: details.formattedAddress,
      rating: details.rating,
      userRatingsTotal: details.userRatingsTotal,
      types: details.types,
      photoReference: details.photos?.isNotEmpty == true
          ? details.photos![0].photoReference
          : null,
      latitude: details.geometry?.latitude,
      longitude: details.geometry?.longitude,
      website: details.website,
      phoneNumber: details.phoneNumber,
      isOpen: details.openingHours?.isOpen,
      openingHours: details.openingHours?.weekdayText,
      priceLevel: details.priceLevel,
    );
  }
}

@freezed
class PlaceDetails with _$PlaceDetails {
  const factory PlaceDetails({
    String? placeId,
    String? name,
    String? formattedAddress,
    double? rating,
    int? userRatingsTotal,
    List<String>? types,
    List<PlacePhoto>? photos,
    PlaceGeometry? geometry,
    String? website,
    String? phoneNumber,
    PlaceOpeningHours? openingHours,
    String? priceLevel,
  }) = _PlaceDetails;

  factory PlaceDetails.fromJson(Map<String, dynamic> json) =>
      _$PlaceDetailsFromJson(json);
}

@freezed
class PlacePhoto with _$PlacePhoto {
  const factory PlacePhoto({
    String? photoReference,
    int? height,
    int? width,
  }) = _PlacePhoto;

  factory PlacePhoto.fromJson(Map<String, dynamic> json) =>
      _$PlacePhotoFromJson(json);
}

@freezed
class PlaceGeometry with _$PlaceGeometry {
  const factory PlaceGeometry({
    double? latitude,
    double? longitude,
  }) = _PlaceGeometry;

  factory PlaceGeometry.fromJson(Map<String, dynamic> json) =>
      _$PlaceGeometryFromJson(json);
}

@freezed
class PlaceOpeningHours with _$PlaceOpeningHours {
  const factory PlaceOpeningHours({
    bool? isOpen,
    List<String>? weekdayText,
  }) = _PlaceOpeningHours;

  factory PlaceOpeningHours.fromJson(Map<String, dynamic> json) =>
      _$PlaceOpeningHoursFromJson(json);
}
