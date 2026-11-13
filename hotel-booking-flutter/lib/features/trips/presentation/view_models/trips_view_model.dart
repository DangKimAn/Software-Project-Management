import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/di/providers.dart';
import '../../../auth/presentation/view_models/auth_notifier.dart';
import '../../data/repositories/booking_repository_impl.dart';
import '../../domain/entities/booking.dart';
import '../../domain/repositories/booking_repository.dart';

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  final client = ref.watch(dioClientProvider);
  return BookingRepositoryImpl(client);
});

final myBookingsProvider =
    FutureProvider.autoDispose<List<Booking>>((ref) async {
  final authScope = ref.watch(
    authNotifierProvider.select(
      (s) => (s.valueOrNull?.id, s.valueOrNull?.isAdmin ?? false),
    ),
  );
  if (authScope.$2) {
    return const <Booking>[];
  }
  final repository = ref.watch(bookingRepositoryProvider);
  return repository.getMyBookings();
});

/// Provides the active pending booking that is awaiting payment and has remaining hold time.
/// Returns `null` if user is not authenticated or has no pending payment bookings.
final activePendingBookingProvider = Provider<Booking?>((ref) {
  final authState = ref.watch(authNotifierProvider);
  final user = authState.valueOrNull;
  if (user == null || user.isAdmin) {
    return null;
  }

  final bookingsAsync = ref.watch(myBookingsProvider);
  return bookingsAsync.when(
    data: (bookings) {
      final now = DateTime.now();
      final pendingBookings = bookings.where((b) {
        return b.canPayNow &&
            !b.isPaid &&
            !b.isCancelled &&
            b.computeRemainingPaymentSeconds(now: now) > 0;
      }).toList();

      if (pendingBookings.isEmpty) return null;

      pendingBookings.sort((a, b) =>
          a.computeRemainingPaymentSeconds(now: now)
              .compareTo(b.computeRemainingPaymentSeconds(now: now)));

      return pendingBookings.first;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

final bookingDetailProvider =
    FutureProvider.autoDispose.family<Booking?, String>((ref, bookingId) async {
  ref.watch(authNotifierProvider.select((s) => s.valueOrNull?.id));
  final repository = ref.watch(bookingRepositoryProvider);
  return repository.getBookingById(bookingId);
});

final paymentMethodsProvider =
    FutureProvider.autoDispose<List<PaymentMethodAvailability>>((ref) async {
  final repository = ref.watch(bookingRepositoryProvider);
  return repository.getPaymentMethods();
});

final paymentDetailProvider = FutureProvider.autoDispose
    .family<PaymentSessionResult?, String>((ref, paymentId) async {
  ref.watch(authNotifierProvider.select((s) => s.valueOrNull?.id));
  final repository = ref.watch(bookingRepositoryProvider);
  return repository.getPaymentById(paymentId);
});

