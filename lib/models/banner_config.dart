import 'package:freezed_annotation/freezed_annotation.dart';

part 'banner_config.freezed.dart';
part 'banner_config.g.dart';

@freezed
class BannerConfig with _$BannerConfig {
  const factory BannerConfig({
    required String id,
    required String imageUrl,
    @Default(true) bool isActive,
    @Default('') String title,
    @Default('') String description,
    String? linkUrl,
    @Default(0) int displayOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _BannerConfig;

  factory BannerConfig.fromJson(Map<String, dynamic> json) => _$BannerConfigFromJson(json);
}
