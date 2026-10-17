import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/date/booking_date.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/socket_service.dart';
import '../../core/security/secure_storage_service.dart';
import '../../core/storage/preferences_service.dart';
import '../../features/auth/presentation/view_models/auth_notifier.dart';
import '../../features/favorites/data/repositories/wishlist_repository_impl.dart';
import '../../features/favorites/domain/repositories/wishlist_repository.dart';
import '../../features/villas/data/repositories/villa_repository_impl.dart';
import '../../features/villas/domain/entities/nightly_price.dart';
import '../../features/villas/domain/entities/villa.dart';
import '../../features/villas/domain/repositories/villa_repository.dart';

// --- Core Providers ---

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return const SecureStorageService();
});

final dioClientProvider = Provider<DioClient>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  final client = DioClient(secureStorage: secureStorage);
  ref.onDispose(() {
    client.abortSession(clearStorage: false);
  });
  return client;
});

final socketServiceProvider = Provider<SocketService>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  final service = SocketService(secureStorage: secureStorage);
  ref.onDispose(service.dispose);
  return service;
});

/// Overridden in bootstrap when initialized
final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  throw UnimplementedError(
      'preferencesServiceProvider must be overridden in bootstrap');
});

// --- Repository Provider (Production REST API - Zero Mock / Zero Seed) ---

final villaRepositoryProvider = Provider<VillaRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return VillaRepositoryImpl(dioClient);
});

// --- App State Providers ---

/// Locale Provider managing Vietnamese, English, and Korean language switching
class LocaleNotifier extends StateNotifier<String> {
  final PreferencesService _prefs;

  LocaleNotifier(this._prefs) : super(_prefs.getLocale());

  Future<void> setLocale(String languageCode) async {
    state = languageCode;
    await _prefs.setLocale(languageCode);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, String>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return LocaleNotifier(prefs);
});

final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  final client = ref.watch(dioClientProvider);
  PreferencesService? prefs;
  try {
    prefs = ref.watch(preferencesServiceProvider);
  } catch (_) {
    prefs = null;
  }
  return WishlistRepositoryImpl(client, prefs: prefs);
});

/// Wishlist / Favorites Notifier
class FavoritesNotifier extends StateNotifier<Set<String>> {
  final PreferencesService _prefs;
  final WishlistRepository? _wishlistRepo;
  final bool _isAuthenticated;

  FavoritesNotifier(this._prefs, this._wishlistRepo, this._isAuthenticated)
      : super(_prefs.getFavorites().toSet()) {
    if (_isAuthenticated && _wishlistRepo != null) {
      _syncFromBackend();
    }
  }

  Future<void> _syncFromBackend() async {
    try {
      final backendIds = await _wishlistRepo!.getWishlistListingIds();
      final merged = Set<String>.from(state)..addAll(backendIds);
      state = merged;
      await _prefs.setFavorites(merged.toList());
    } catch (_) {
      // Keep offline preferences if network is unavailable
    }
  }

  Future<void> toggleFavorite(String villaId) async {
    final updated = Set<String>.from(state);
    final isAdding = !updated.contains(villaId);
    if (isAdding) {
      updated.add(villaId);
    } else {
      updated.remove(villaId);
    }
    state = updated;
    await _prefs.setFavorites(updated.toList());

    if (_isAuthenticated && _wishlistRepo != null) {
      try {
        if (isAdding) {
          await _wishlistRepo.addWishlistListing(villaId);
        } else {
          await _wishlistRepo.removeWishlistListing(villaId);
        }
      } catch (_) {
        // Silently keep local state if offline
      }
    }
  }

  bool isFavorite(String villaId) => state.contains(villaId);
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  final wishlistRepo = ref.watch(wishlistRepositoryProvider);
  final authUser = ref.watch(authNotifierProvider).valueOrNull;
  return FavoritesNotifier(prefs, wishlistRepo, authUser != null);
});

/// Recently Viewed Notifier (max 8 items, synced to PreferencesService)
class RecentlyViewedNotifier extends StateNotifier<List<RecentlyViewedItem>> {
  final PreferencesService _prefs;

  RecentlyViewedNotifier(this._prefs) : super(_prefs.getRecentlyViewed());

  Future<void> recordVilla(Villa villa) async {
    final item = RecentlyViewedItem(
      id: villa.id,
      title: villa.name,
      location: villa.address,
      pricePerNight: villa.basePriceVnd ?? 0,
      rating: villa.rating,
      reviewCount: villa.reviewCount,
      imageUrl: villa.imageUrls.isNotEmpty ? villa.imageUrls.first : '',
      bedrooms: villa.specs.bedrooms,
      maxGuests: villa.specs.maxGuests,
      viewedAtIso: DateTime.now().toIso8601String(),
    );
    await _prefs.addRecentlyViewed(item);
    state = _prefs.getRecentlyViewed();
  }

  Future<void> clear() async {
    await _prefs.clearRecentlyViewed();
    state = const [];
  }
}

final recentlyViewedProvider =
    StateNotifierProvider<RecentlyViewedNotifier, List<RecentlyViewedItem>>(
        (ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return RecentlyViewedNotifier(prefs);
});

/// Search History Notifier (max 8 items)
class SearchHistoryNotifier extends StateNotifier<List<String>> {
  final PreferencesService _prefs;

  SearchHistoryNotifier(this._prefs) : super(_prefs.getSearchHistory());

  Future<void> addTerm(String term) async {
    await _prefs.addSearchHistory(term);
    state = _prefs.getSearchHistory();
  }

  Future<void> removeTerm(String term) async {
    await _prefs.removeSearchHistory(term);
    state = _prefs.getSearchHistory();
  }

  Future<void> clear() async {
    await _prefs.clearSearchHistory();
    state = const [];
  }
}

final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return SearchHistoryNotifier(prefs);
});

/// Booking Queue (Giỏ chờ đặt — MultiBooking) Notifier (max 5 items)
class BookingQueueNotifier extends StateNotifier<List<BookingQueueItem>> {
  final PreferencesService _prefs;

  BookingQueueNotifier(this._prefs) : super(_prefs.getBookingQueue());

  Future<String> addItem(BookingQueueItem item) async {
    final status = await _prefs.addToBookingQueue(item);
    state = _prefs.getBookingQueue();
    return status; // 'added' | 'exists' | 'full'
  }

  Future<void> updateItem(BookingQueueItem item) async {
    await _prefs.updateBookingQueueItem(item);
    state = _prefs.getBookingQueue();
  }

  Future<void> removeItem(String listingId) async {
    await _prefs.removeFromBookingQueue(listingId);
    state = _prefs.getBookingQueue();
  }

  Future<void> clear() async {
    await _prefs.clearBookingQueue();
    state = const [];
  }
}

final bookingQueueProvider =
    StateNotifierProvider<BookingQueueNotifier, List<BookingQueueItem>>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return BookingQueueNotifier(prefs);
});

// --- Villa Feature ViewModels ---

class VillaFilterState {
  final String searchQuery;
  final String? locationGroup;
  final double? lat;
  final double? lng;
  final int? radius;
  final String
      propertyType; // 'all' | 'villa' | 'apartment' | 'house' | 'resort' | 'homestay'
  final int? priceMin;
  final int? priceMax;
  final int? minGuests;
  final int adults;
  final int children;
  final int infants;
  final int pets;
  final int? bedrooms;
  final int? beds;
  final int? bathrooms;
  final List<String> amenities;
  final BookingDate? checkIn;
  final BookingDate? checkOut;
  final String sort; // 'newest' | 'price_asc' | 'price_desc' | 'rating_desc'
  final int page;
  final int limit;
  final String dateMode; // 'dates' | 'months' | 'flexible'
  final List<int> selectedMonths;
  final String flexDuration; // 'weekend' | 'week' | 'month'
  final int exactnessDays; // 0 | 1 | 2 | 3 | 7 | 14

  const VillaFilterState({
    this.searchQuery = '',
    this.locationGroup,
    this.lat,
    this.lng,
    this.radius,
    this.propertyType = 'all',
    this.priceMin,
    this.priceMax,
    this.minGuests,
    this.adults = 0,
    this.children = 0,
    this.infants = 0,
    this.pets = 0,
    this.bedrooms,
    this.beds,
    this.bathrooms,
    this.amenities = const [],
    this.checkIn,
    this.checkOut,
    this.sort = 'newest',
    this.page = 1,
    this.limit = 12,
    this.dateMode = 'dates',
    this.selectedMonths = const [],
    this.flexDuration = 'weekend',
    this.exactnessDays = 0,
  });

  int get effectiveGuests {
    final fromCounters = adults + children;
    if (fromCounters > 0) return fromCounters;
    return minGuests ?? 0;
  }

  int get activeFilterCount {
    int count = 0;
    if (propertyType != 'all' && propertyType.isNotEmpty) count++;
    if (priceMin != null && priceMin! > 500000) count++;
    if (priceMax != null && priceMax! < 20000000) count++;
    if (bedrooms != null && bedrooms! > 0) count++;
    if (beds != null && beds! > 0) count++;
    if (bathrooms != null && bathrooms! > 0) count++;
    count += amenities.length;
    if (sort != 'newest') count++;
    return count;
  }

  VillaFilterState copyWith({
    String? searchQuery,
    String? locationGroup,
    bool clearLocationGroup = false,
    double? lat,
    double? lng,
    int? radius,
    bool clearGeo = false,
    String? propertyType,
    int? priceMin,
    int? priceMax,
    bool clearPrice = false,
    int? minGuests,
    int? adults,
    int? children,
    int? infants,
    int? pets,
    int? bedrooms,
    int? beds,
    int? bathrooms,
    List<String>? amenities,
    BookingDate? checkIn,
    BookingDate? checkOut,
    bool clearDates = false,
    String? sort,
    int? page,
    int? limit,
    String? dateMode,
    List<int>? selectedMonths,
    String? flexDuration,
    int? exactnessDays,
  }) {
    final nextAdults = adults ?? this.adults;
    final nextChildren = children ?? this.children;
    final nextMinGuests = minGuests ??
        ((adults != null || children != null)
            ? (nextAdults + nextChildren > 0 ? nextAdults + nextChildren : null)
            : this.minGuests);

    return VillaFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      locationGroup:
          clearLocationGroup ? null : (locationGroup ?? this.locationGroup),
      lat: clearGeo ? null : (lat ?? this.lat),
      lng: clearGeo ? null : (lng ?? this.lng),
      radius: clearGeo ? null : (radius ?? this.radius),
      propertyType: propertyType ?? this.propertyType,
      priceMin: clearPrice ? null : (priceMin ?? this.priceMin),
      priceMax: clearPrice ? null : (priceMax ?? this.priceMax),
      minGuests: nextMinGuests,
      adults: nextAdults,
      children: nextChildren,
      infants: infants ?? this.infants,
      pets: pets ?? this.pets,
      bedrooms: bedrooms ?? this.bedrooms,
      beds: beds ?? this.beds,
      bathrooms: bathrooms ?? this.bathrooms,
      amenities: amenities ?? this.amenities,
      checkIn: clearDates ? null : (checkIn ?? this.checkIn),
      checkOut: clearDates ? null : (checkOut ?? this.checkOut),
      sort: sort ?? this.sort,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      dateMode: dateMode ?? this.dateMode,
      selectedMonths: selectedMonths ?? this.selectedMonths,
      flexDuration: flexDuration ?? this.flexDuration,
      exactnessDays: exactnessDays ?? this.exactnessDays,
    );
  }
}

final villaFilterProvider = StateProvider<VillaFilterState>((ref) {
  return const VillaFilterState();
});

/// Loads villas live from Backend API.
final villaListProvider = FutureProvider.autoDispose<List<Villa>>((ref) async {
  final repository = ref.watch(villaRepositoryProvider);
  final filter = ref.watch(villaFilterProvider);

  return repository.getVillas(
    searchQuery: filter.searchQuery,
    locationGroup: filter.locationGroup,
    lat: filter.lat,
    lng: filter.lng,
    radius: filter.radius,
    propertyType: filter.propertyType,
    priceMin: filter.priceMin,
    priceMax: filter.priceMax,
    minGuests: filter.effectiveGuests > 0 ? filter.effectiveGuests : null,
    bedrooms: filter.bedrooms,
    beds: filter.beds,
    bathrooms: filter.bathrooms,
    amenities: filter.amenities,
    checkIn: filter.checkIn,
    checkOut: filter.checkOut,
    sort: filter.sort,
    page: filter.page,
    limit: filter.limit,
  );
});

/// Loads paginated villas with pagination metadata.
final villaPaginatedProvider =
    FutureProvider.autoDispose<PaginatedResult<Villa>>((ref) async {
  final repository = ref.watch(villaRepositoryProvider);
  final filter = ref.watch(villaFilterProvider);

  return repository.getVillasPaginated(
    searchQuery: filter.searchQuery,
    locationGroup: filter.locationGroup,
    lat: filter.lat,
    lng: filter.lng,
    radius: filter.radius,
    propertyType: filter.propertyType,
    priceMin: filter.priceMin,
    priceMax: filter.priceMax,
    minGuests: filter.effectiveGuests > 0 ? filter.effectiveGuests : null,
    bedrooms: filter.bedrooms,
    beds: filter.beds,
    bathrooms: filter.bathrooms,
    amenities: filter.amenities,
    checkIn: filter.checkIn,
    checkOut: filter.checkOut,
    sort: filter.sort,
    page: filter.page,
    limit: filter.limit,
  );
});

/// Loads villa detail live from Backend API.
final villaDetailProvider =
    FutureProvider.autoDispose.family<Villa?, String>((ref, id) async {
  final repository = ref.watch(villaRepositoryProvider);
  return repository.getVillaById(id);
});

/// Loads nearby/similar recommendations for a villa.
final villaRecommendationsProvider =
    FutureProvider.autoDispose.family<List<Villa>, String>((ref, id) async {
  final repository = ref.watch(villaRepositoryProvider);
  return repository.getRecommendations(id, limit: 4);
});

/// Loads real nightly pricing from Backend API for selected date range.
typedef PricingParams = ({
  String villaId,
  BookingDate checkIn,
  BookingDate checkOut
});

final villaNightlyPricingProvider = FutureProvider.autoDispose
    .family<List<NightlyPrice>, PricingParams>((ref, params) async {
  final repository = ref.watch(villaRepositoryProvider);
  return repository.getNightlyPrices(
    villaId: params.villaId,
    checkIn: params.checkIn,
    checkOut: params.checkOut,
  );
});
