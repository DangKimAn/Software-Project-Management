import 'villa_specs.dart';

enum VillaBadgeType {
  featured(0, 'Nổi bật'),
  newVilla(1, 'Mới'),
  nearBeach(2, 'Gần biển'),
  saltwater(3, 'Hồ bơi nước mặn'),
  group(4, 'Đoàn đông');

  final int priority;
  final String labelVi;
  const VillaBadgeType(this.priority, this.labelVi);
}

class Villa {
  final String id;
  final String code;
  final String name;
  final String tagline;
  final String address;
  final String description;
  final List<String> imageUrls;
  final VillaSpecs specs;
  final int? basePriceVnd;
  final int? saturdayPriceVnd;
  final double rating;
  final int reviewCount;
  final List<VillaBadgeType> badges;
  final List<String> amenities;
  final Set<String> bookedDatesIso; // 'YYYY-MM-DD' dates that are fully booked

  const Villa({
    required this.id,
    required this.code,
    required this.name,
    required this.tagline,
    required this.address,
    required this.description,
    required this.imageUrls,
    required this.specs,
    this.basePriceVnd,
    this.saturdayPriceVnd,
    this.rating = 5.0,
    this.reviewCount = 0,
    this.badges = const [],
    this.amenities = const [],
    this.bookedDatesIso = const {},
  });

  /// Returns AT MOST ONE primary badge based on strict business priority:
  /// `featured > new > near-beach > saltwater > group`
  VillaBadgeType? get primaryBadge {
    if (badges.isEmpty) return null;
    final sorted = List<VillaBadgeType>.from(badges)
      ..sort((a, b) => a.priority.compareTo(b.priority));
    return sorted.first;
  }
}
