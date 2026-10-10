class VillaSpecs {
  // 4 Core Specs (shown in collapsed summary and card)
  final int bedrooms;
  final int beds;
  final int maxGuests;
  final int bathrooms;

  // Supporting Specs (shown in expanded overview)
  final int? beachDistanceMeters;
  final bool hasPrivatePool;
  final bool hasSaltwaterPool;
  final bool hasBbqKitchen;
  final bool hasParking;
  final double? poolAreaM2;

  const VillaSpecs({
    required this.bedrooms,
    required this.beds,
    required this.maxGuests,
    required this.bathrooms,
    this.beachDistanceMeters,
    this.hasPrivatePool = true,
    this.hasSaltwaterPool = false,
    this.hasBbqKitchen = true,
    this.hasParking = true,
    this.poolAreaM2,
  });
}
