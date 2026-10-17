import '../../../../core/date/booking_date.dart';
import '../../../../core/network/dio_client.dart';
import '../entities/nightly_price.dart';
import '../entities/villa.dart';

abstract class VillaRepository {
  Future<List<Villa>> getVillas({
    String? searchQuery,
    String? locationGroup,
    double? lat,
    double? lng,
    int? radius,
    String? propertyType,
    int? priceMin,
    int? priceMax,
    int? minGuests,
    int? bedrooms,
    int? beds,
    int? bathrooms,
    List<String>? amenities,
    BookingDate? checkIn,
    BookingDate? checkOut,
    String? sort,
    int page = 1,
    int limit = 20,
  });

  Future<PaginatedResult<Villa>> getVillasPaginated({
    String? searchQuery,
    String? locationGroup,
    double? lat,
    double? lng,
    int? radius,
    String? propertyType,
    int? priceMin,
    int? priceMax,
    int? minGuests,
    int? bedrooms,
    int? beds,
    int? bathrooms,
    List<String>? amenities,
    BookingDate? checkIn,
    BookingDate? checkOut,
    String? sort,
    int page = 1,
    int limit = 12,
  });

  Future<Villa?> getVillaById(String id);

  Future<VillaRules> getVillaRules(String villaId);

  Future<List<Villa>> getRecommendations(String villaId, {int limit = 4});

  Future<Set<String>> getUnavailableDates(
    String villaId, {
    int monthsAhead = 6,
  });

  Future<List<NightlyPrice>> getNightlyPrices({
    required String villaId,
    required BookingDate checkIn,
    required BookingDate checkOut,
  });

  Future<bool> checkAvailability({
    required String villaId,
    required BookingDate checkIn,
    required BookingDate checkOut,
  });

  Future<SemanticSearchResponse> semanticSearch({
    required String query,
    int topK = 12,
  });

  Future<List<Map<String, dynamic>>> getAmenitiesCatalog();
}
