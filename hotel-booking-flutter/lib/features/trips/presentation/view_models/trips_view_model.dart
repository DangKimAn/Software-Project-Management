import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/di/providers.dart';
import '../../data/repositories/booking_repository_impl.dart';
import '../../domain/entities/booking.dart';
import '../../domain/repositories/booking_repository.dart';

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  final client = ref.watch(dioClientProvider);
  return BookingRepositoryImpl(client);
});

final myBookingsProvider =
    FutureProvider.autoDispose<List<Booking>>((ref) async {
  final repository = ref.watch(bookingRepositoryProvider);
  return repository.getMyBookings();
});
