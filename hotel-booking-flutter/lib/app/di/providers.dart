import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/date/booking_date.dart';
import '../../core/network/dio_client.dart';
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
  return DioClient(secureStorage: secureStorage);
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
  return WishlistRepositoryImpl(client);
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

// --- Villa Feature ViewModels ---

class VillaFilterState {
  final String searchQuery;
  final int? minGuests;
  final BookingDate? checkIn;
  final BookingDate? checkOut;

  const VillaFilterState({
    this.searchQuery = '',
    this.minGuests,
    this.checkIn,
    this.checkOut,
  });

  VillaFilterState copyWith({
    String? searchQuery,
    int? minGuests,
    BookingDate? checkIn,
    BookingDate? checkOut,
  }) {
    return VillaFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      minGuests: minGuests ?? this.minGuests,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
    );
  }
}

final villaFilterProvider = StateProvider<VillaFilterState>((ref) {
  return const VillaFilterState();
});

/// Loads villas live from Backend API.
/// If server is unreachable or offline, returns AppFailure cleanly caught by UI state.
final villaListProvider = FutureProvider.autoDispose<List<Villa>>((ref) async {
  final repository = ref.watch(villaRepositoryProvider);
  final filter = ref.watch(villaFilterProvider);

  return repository.getVillas(
    searchQuery: filter.searchQuery,
    minGuests: filter.minGuests,
    checkIn: filter.checkIn,
    checkOut: filter.checkOut,
  );
});

/// Loads villa detail live from Backend API.
final villaDetailProvider =
    FutureProvider.autoDispose.family<Villa?, String>((ref, id) async {
  final repository = ref.watch(villaRepositoryProvider);
  return repository.getVillaById(id);
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
