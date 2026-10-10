import '../../../../core/date/booking_date.dart';
import '../entities/nightly_price.dart';
import '../entities/villa.dart';

abstract class VillaRepository {
  Future<List<Villa>> getVillas({
    String? searchQuery,
    int? minGuests,
    BookingDate? checkIn,
    BookingDate? checkOut,
  });
  Future<Villa?> getVillaById(String id);
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
}
