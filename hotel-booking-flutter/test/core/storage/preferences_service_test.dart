import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/app/di/providers.dart';
import 'package:hotel_booking_flutter/core/storage/preferences_service.dart';

void main() {
  group('PreferencesService Null-Safe Serialization & Session DI Sync', () {
    test(
        'BookingQueueItem.fromJson and RecentlyViewedItem.fromJson safely parse string/num/bool/null fields',
        () {
      final queueItem = BookingQueueItem.fromJson({
        'listingId': 'villa-101',
        'title': 'Ocean Pool Villa',
        'pricePerNight': '4500000',
        'cleaningFee': '250000.5',
        'serviceFee': null,
        'maxGuests': '12',
        'instantBook': 'true',
        'guests': '8',
        'checkIn': '2026-11-01',
        'checkOut': '2026-11-04',
      });

      expect(queueItem.listingId, 'villa-101');
      expect(queueItem.pricePerNight, 4500000);
      expect(queueItem.cleaningFee, 250000);
      expect(queueItem.serviceFee, 0);
      expect(queueItem.maxGuests, 12);
      expect(queueItem.instantBook, isTrue);
      expect(queueItem.guests, 8);
      expect(queueItem.guestsCount, 8);
      expect(queueItem.calculatePriceEstimate().nights, 3);

      final recentItem = RecentlyViewedItem.fromJson({
        'id': 'villa-202',
        'title': 'Hilltop Sanctuary',
        'location': 'Bãi Sau, Vũng Tàu',
        'pricePerNight': '3800000',
        'rating': '4.85',
        'reviewCount': '42',
        'imageUrl': 'https://example.com/v202.jpg',
        'bedrooms': '4',
        'maxGuests': '10',
        'viewedAtIso': '2026-10-27T10:00:00.000Z',
      });

      expect(recentItem.id, 'villa-202');
      expect(recentItem.pricePerNight, 3800000);
      expect(recentItem.rating, closeTo(4.85, 0.001));
      expect(recentItem.reviewCount, 42);
      expect(recentItem.bedrooms, 4);
      expect(recentItem.maxGuests, 10);
    });

    test(
        'clearSessionData clears favorites, bookingQueue, searchHistory, and wishlistSynced while notifying DI providers',
        () async {
      final prefs = PreferencesService.inMemory();
      final container = ProviderContainer(
        overrides: [
          preferencesServiceProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      // Populate favorites, search history, and booking queue via Riverpod notifiers
      await container.read(favoritesProvider.notifier).toggleFavorite('101');
      await container.read(favoritesProvider.notifier).toggleFavorite('102');
      await container.read(searchHistoryProvider.notifier).addTerm('Bãi Sau');
      final addStatus =
          await container.read(bookingQueueProvider.notifier).addItem(
                const BookingQueueItem(
                  listingId: '101',
                  title: 'Villa 1',
                  location: 'Vũng Tàu',
                  imageUrl: '',
                  pricePerNight: 3000000,
                  cleaningFee: 0,
                  serviceFee: 0,
                  maxGuests: 10,
                  instantBook: false,
                  checkIn: '2026-11-01',
                  checkOut: '2026-11-03',
                  guests: 4,
                ),
              );
      await prefs.markWishlistSynced(
        backendIds: const ['101', '102'],
        migratedGuestIds: const ['101'],
        userId: 'user-1',
      );

      expect(addStatus, 'added');
      expect(container.read(favoritesProvider), {'101', '102'});
      expect(container.read(searchHistoryProvider), ['Bãi Sau']);
      expect(container.read(bookingQueueProvider).length, 1);
      expect(prefs.isWishlistSynced, isTrue);

      // Simulate logout / session expiry clearing session data
      await prefs.clearSessionData();

      expect(container.read(favoritesProvider), isEmpty);
      expect(container.read(searchHistoryProvider), isEmpty);
      expect(container.read(bookingQueueProvider), isEmpty);
      expect(prefs.isWishlistSynced, isFalse);
    });
  });
}
