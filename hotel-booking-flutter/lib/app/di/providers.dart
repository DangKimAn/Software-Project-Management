import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/date/booking_date.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/socket_service.dart';
import '../../core/notifications/device_token_repository.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../core/security/secure_storage_service.dart';
import '../../core/storage/preferences_service.dart';
export '../../core/currency/currency.dart';
import '../../features/auth/presentation/view_models/auth_notifier.dart';
import '../../features/favorites/data/repositories/wishlist_repository_impl.dart';
import '../../features/favorites/domain/repositories/wishlist_repository.dart';
import '../../features/villas/data/repositories/villa_repository_impl.dart';
import '../../features/villas/domain/entities/nightly_price.dart';
import '../../features/villas/domain/entities/villa.dart';
import '../../features/villas/domain/repositories/villa_repository.dart';

// --- Core Providers ---

/// Provider cung cấp dịch vụ lưu trữ bảo mật phần cứng (`Keychain` trên iOS / `EncryptedSharedPreferences` trên Android).
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return const SecureStorageService();
});

/// Provider cung cấp `DioClient` trung tâm tích hợp tự động đính kèm JWT, làm mới phiên đơn luồng và hủy kết nối khi giải phóng.
final dioClientProvider = Provider<DioClient>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  final client = DioClient(secureStorage: secureStorage);
  ref.onDispose(() {
    client.abortSession(clearStorage: false);
    client.dio.close(force: true);
  });
  return client;
});

/// Provider cung cấp dịch vụ kết nối thời gian thực `SocketService` tích hợp cơ chế ủy quyền làm mới token qua `dioClientProvider`.
final socketServiceProvider = Provider<SocketService>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  final service = SocketService(
    secureStorage: secureStorage,
    onTokenRefreshRequested: () =>
        ref.read(dioClientProvider).refreshAccessToken(),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Overridden in bootstrap when initialized; falls back to active or in-memory
/// PreferencesService in isolated widget/unit test containers.
/// Provider cung cấp `DeviceTokenRepository` để đăng ký và thu hồi mã thiết bị thông báo đẩy với máy chủ.
final deviceTokenRepositoryProvider = Provider<DeviceTokenRepository>((ref) {
  final client = ref.watch(dioClientProvider);
  return DeviceTokenRepositoryImpl(client);
});

/// Provider cung cấp dịch vụ điều phối thông báo đẩy `PushNotificationService` kết hợp FCM và Socket.IO.
final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) {
  final repo = ref.watch(deviceTokenRepositoryProvider);
  final socket = ref.watch(socketServiceProvider);
  final service = PushNotificationService(
    deviceTokenRepository: repo,
    socketService: socket,
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Provider cung cấp `PreferencesService` đã khởi tạo từ `bootstrap`, tự động dự phòng sang bộ nhớ tạm trong môi trường kiểm thử cô lập.
final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  return PreferencesService.activeInstance ?? PreferencesService.inMemory();
});

// --- Repository Provider (Production REST API - Zero Mock / Zero Seed) ---

/// Provider cung cấp `VillaRepository` kết nối trực tiếp tới REST API sản xuất.
final villaRepositoryProvider = Provider<VillaRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return VillaRepositoryImpl(dioClient);
});

// --- App State Providers ---

/// Locale Provider managing Vietnamese, English, and Korean language switching
/// Bộ quản lý trạng thái ngôn ngữ giao diện (`vi`, `en`, `ko`) đồng bộ bền vững với `PreferencesService`.
class LocaleNotifier extends StateNotifier<String> {
  final PreferencesService _prefs;

  LocaleNotifier(this._prefs) : super(_prefs.getLocale());

  /// Cập nhật mã ngôn ngữ hiển thị hiện hành và lưu trữ xuống bộ nhớ cục bộ.
  Future<void> setLocale(String languageCode) async {
    state = languageCode;
    await _prefs.setLocale(languageCode);
  }
}

/// Provider quản lý ngôn ngữ giao diện hiện hành (`vi`, `en`, `ko`) trên toàn ứng dụng.
final localeProvider = StateNotifierProvider<LocaleNotifier, String>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return LocaleNotifier(prefs);
});

/// Provider cung cấp `WishlistRepository` phục vụ đồng bộ danh sách yêu thích của khách và tài khoản đã đăng nhập.
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

/// Provider tải chi tiết danh sách biệt thự yêu thích từ máy chủ sau khi đã đồng bộ và hợp nhất danh sách tạm của khách.
final wishlistDetailProvider =
    FutureProvider.autoDispose<WishlistResponse?>((ref) async {
  final user = ref.watch(authNotifierProvider).valueOrNull;
  if (user == null) return null;
  final repo = ref.watch(wishlistRepositoryProvider);
  await repo.getWishlistListingIds();
  return repo.getWishlistDetail();
});

/// Wishlist / Favorites Notifier
/// Bộ quản lý tập hợp mã biệt thự yêu thích, hỗ trợ hoạt động ngoại tuyến cho khách và đồng bộ hai chiều khi đăng nhập.
class FavoritesNotifier extends StateNotifier<Set<String>> {
  final PreferencesService _prefs;
  final WishlistRepository? _wishlistRepo;
  final bool _isAuthenticated;
  final VoidCallback? _onWishlistMutated;
  late final void Function() _sessionListener;
  final Set<String> _sessionRemovedIds = <String>{};
  bool _hasSyncedBackend = false;

  FavoritesNotifier(
    this._prefs,
    this._wishlistRepo,
    this._isAuthenticated, {
    VoidCallback? onWishlistMutated,
  })  : _onWishlistMutated = onWishlistMutated,
        super(_prefs.getFavorites().toSet()) {
    _sessionListener = () {
      if (mounted) {
        _sessionRemovedIds.clear();
        state = _prefs.getFavorites().toSet();
      }
    };
    _prefs.addSessionStateListener(_sessionListener);

    if (_isAuthenticated && _wishlistRepo != null) {
      _syncFromBackend();
    }
  }

  /// Cho biết danh sách yêu thích đã hoàn tất ít nhất một lần đồng bộ từ máy chủ trong phiên hiện tại hay chưa.
  bool get hasSyncedBackend => _hasSyncedBackend;

  /// Cho biết biệt thự có mã `villaId` vừa bị người dùng chủ động bỏ thích trong phiên hiện tại hay không.
  bool isRemovedInSession(String villaId) =>
      _sessionRemovedIds.contains(villaId);

  Future<void> _syncFromBackend() async {
    try {
      final backendIds = await _wishlistRepo!.getWishlistListingIds();
      if (!mounted) return;
      final synced =
          backendIds.where((id) => !_sessionRemovedIds.contains(id)).toSet();
      _hasSyncedBackend = true;
      state = synced;
      await _prefs.setFavorites(synced.toList());
    } catch (_) {
      // Keep offline preferences if network is unavailable
    }
  }

  // Giải thuật đồng bộ tức thời thao tác thả tim / bỏ tim (Optimistic Wishlist Sync):
  // Cập nhật ngay lập tức trạng thái cục bộ, ghi nhận danh sách vừa bỏ tim trong phiên để không bị dữ liệu cũ ghi đè,
  // đồng thời làm mới `wishlistDetailProvider` ngay trước và sau khi gọi API để thẻ trên màn hình Yêu thích biến mất tức thì.
  // CONFLICT-RESOLVED: Khắc phục lỗi thẻ biệt thự đã bỏ tim vẫn hiển thị trên `FavoritesScreen` do `wishlistDetailProvider` giữ cache cũ.
  /// Đảo trạng thái yêu thích của `villaId` theo cơ chế cập nhật lạc quan (Optimistic Update) và đồng bộ lên máy chủ nếu đã đăng nhập.
  Future<void> toggleFavorite(String villaId) async {
    final updated = Set<String>.from(state);
    final isAdding = !updated.contains(villaId);
    if (isAdding) {
      _sessionRemovedIds.remove(villaId);
      updated.add(villaId);
    } else {
      _sessionRemovedIds.add(villaId);
      updated.remove(villaId);
    }
    state = updated;
    await _prefs.setFavorites(updated.toList());

    if (_isAuthenticated && _wishlistRepo != null) {
      _onWishlistMutated?.call();
      try {
        if (isAdding) {
          await _wishlistRepo.addWishlistListing(villaId);
        } else {
          await _wishlistRepo.removeWishlistListing(villaId);
        }
        if (mounted) {
          _onWishlistMutated?.call();
        }
      } catch (_) {
        // Silently keep local state if offline
      }
    }
  }

  /// Kiểm tra xem biệt thự `villaId` có đang nằm trong danh sách yêu thích hay không.
  bool isFavorite(String villaId) => state.contains(villaId);

  @override
  void dispose() {
    _prefs.removeSessionStateListener(_sessionListener);
    super.dispose();
  }
}

/// Provider quản lý tập hợp mã biệt thự yêu thích và tự động vô hiệu hóa bộ nhớ đệm `wishlistDetailProvider` khi có thay đổi.
final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  final wishlistRepo = ref.watch(wishlistRepositoryProvider);
  final authUserId = ref.watch(
    authNotifierProvider.select((state) => state.valueOrNull?.id),
  );
  return FavoritesNotifier(
    prefs,
    wishlistRepo,
    authUserId != null && authUserId.isNotEmpty,
    onWishlistMutated: () => ref.invalidate(wishlistDetailProvider),
  );
});

// Giải thuật phân giải đầy đủ danh sách biệt thự yêu thích cho khách chưa đăng nhập:
// Mở rộng truy vấn ngoài 12 mục của trang 1 (`limit: 100`) kết hợp tải bù từng ID còn thiếu qua `getVillaById`
// để các biệt thự yêu thích thuộc trang sau vẫn hiển thị đầy đủ trên màn hình Yêu thích.
/// Provider phân giải đầy đủ thông tin các biệt thự yêu thích cho khách chưa đăng nhập.
///
/// Giải thuật phân giải ba tầng (3-Tier Favorite Resolution):
/// 1. Tận dụng ngay dữ liệu trang đầu đang có sẵn trong `villaListProvider` để phản hồi tức thì.
/// 2. Nếu còn mã biệt thự chưa tìm thấy, mở rộng truy vấn danh mục (`limit: 100`) để gom hàng loạt.
/// 3. Với các mã vẫn còn thiếu (tối đa 20 mục), gọi song song `getVillaById` và bảo toàn đúng thứ tự ban đầu.
final resolvedFavoriteVillasProvider =
    FutureProvider.autoDispose<List<Villa>>((ref) async {
  final favorites = ref.watch(favoritesProvider);
  final validIds = favorites
      .where(PreferencesService.isValidListingId)
      .toList(growable: false);
  if (validIds.isEmpty) return const <Villa>[];

  final repo = ref.watch(villaRepositoryProvider);
  final byId = <String, Villa>{};

  final firstPageCached = ref.read(villaListProvider).valueOrNull;
  if (firstPageCached != null) {
    for (final v in firstPageCached) {
      if (favorites.contains(v.id)) {
        byId[v.id] = v;
      }
    }
  }

  var missingIds = validIds.where((id) => !byId.containsKey(id)).toList();
  if (missingIds.isNotEmpty) {
    try {
      final catalog = await repo.getVillas(page: 1, limit: 100);
      for (final v in catalog) {
        if (favorites.contains(v.id)) {
          byId[v.id] = v;
        }
      }
    } catch (_) {}
  }

  missingIds = validIds.where((id) => !byId.containsKey(id)).toList();
  if (missingIds.isNotEmpty) {
    final fetched = await Future.wait(
      missingIds.take(20).map(
            (id) => repo.getVillaById(id).catchError((_) => null),
          ),
    );
    for (final v in fetched) {
      if (v != null) {
        byId[v.id] = v;
      }
    }
  }

  return [
    for (final id in validIds)
      if (byId.containsKey(id)) byId[id]!,
  ];
});

/// Recently Viewed Notifier (max 8 items, synced to PreferencesService)
/// Bộ quản lý danh sách biệt thự vừa xem gần đây (tối đa 8 mục theo thứ tự mới nhất lên đầu).
class RecentlyViewedNotifier extends StateNotifier<List<RecentlyViewedItem>> {
  final PreferencesService _prefs;

  RecentlyViewedNotifier(this._prefs) : super(_prefs.getRecentlyViewed());

  /// Ghi nhận biệt thự `villa` vào đầu danh sách vừa xem gần đây và đồng bộ lưu trữ cục bộ.
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

/// Provider quản lý danh sách các biệt thự vừa xem gần đây của người dùng.
final recentlyViewedProvider =
    StateNotifierProvider<RecentlyViewedNotifier, List<RecentlyViewedItem>>(
        (ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return RecentlyViewedNotifier(prefs);
});

/// Search History Notifier (max 8 items)
/// Bộ quản lý lịch sử từ khóa tìm kiếm (tối đa 8 từ khóa, khử trùng lặp không phân biệt hoa thường).
class SearchHistoryNotifier extends StateNotifier<List<String>> {
  final PreferencesService _prefs;
  late final void Function() _sessionListener;

  SearchHistoryNotifier(this._prefs) : super(_prefs.getSearchHistory()) {
    _sessionListener = () {
      if (mounted) {
        state = _prefs.getSearchHistory();
      }
    };
    _prefs.addSessionStateListener(_sessionListener);
  }

  /// Thêm từ khóa `term` vào đầu danh sách lịch sử tìm kiếm.
  Future<void> addTerm(String term) async {
    await _prefs.addSearchHistory(term);
    state = _prefs.getSearchHistory();
  }

  /// Xóa từ khóa `term` khỏi danh sách lịch sử tìm kiếm.
  Future<void> removeTerm(String term) async {
    await _prefs.removeSearchHistory(term);
    state = _prefs.getSearchHistory();
  }

  Future<void> clear() async {
    await _prefs.clearSearchHistory();
    state = const [];
  }

  @override
  void dispose() {
    _prefs.removeSessionStateListener(_sessionListener);
    super.dispose();
  }
}

/// Provider quản lý lịch sử tìm kiếm theo phiên đăng nhập hiện hành.
final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  ref.watch(authNotifierProvider.select((state) => state.valueOrNull?.id));
  return SearchHistoryNotifier(prefs);
});

/// Booking Queue (Giỏ chờ đặt — MultiBooking) Notifier (max 5 items)
/// Bộ quản lý giỏ chờ đặt nhiều căn (`BookingQueueItem`, tối đa 5 mục lưu trữ cục bộ).
class BookingQueueNotifier extends StateNotifier<List<BookingQueueItem>> {
  final PreferencesService _prefs;
  late final void Function() _sessionListener;

  BookingQueueNotifier(this._prefs) : super(_prefs.getBookingQueue()) {
    _sessionListener = () {
      if (mounted) {
        state = _prefs.getBookingQueue();
      }
    };
    _prefs.addSessionStateListener(_sessionListener);
  }

  /// Thêm một mục `item` vào giỏ chờ đặt và trả về mã kết quả (`added`, `exists` hoặc `full`).
  Future<String> addItem(BookingQueueItem item) async {
    final status = await _prefs.addToBookingQueue(item);
    state = _prefs.getBookingQueue();
    return status; // 'added' | 'exists' | 'full'
  }

  /// Cập nhật thông tin ngày lưu trú, số khách hoặc mã ưu đãi của mục `item` trong giỏ chờ đặt.
  Future<void> updateItem(BookingQueueItem item) async {
    await _prefs.updateBookingQueueItem(item);
    state = _prefs.getBookingQueue();
  }

  /// Xóa căn lưu trú có mã `listingId` khỏi giỏ chờ đặt.
  Future<void> removeItem(String listingId) async {
    await _prefs.removeFromBookingQueue(listingId);
    state = _prefs.getBookingQueue();
  }

  Future<void> clear() async {
    await _prefs.clearBookingQueue();
    state = const [];
  }

  @override
  void dispose() {
    _prefs.removeSessionStateListener(_sessionListener);
    super.dispose();
  }
}

/// Provider quản lý trạng thái giỏ chờ đặt nhiều căn theo phiên hiện hành.
final bookingQueueProvider =
    StateNotifierProvider<BookingQueueNotifier, List<BookingQueueItem>>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  ref.watch(authNotifierProvider.select((state) => state.valueOrNull?.id));
  return BookingQueueNotifier(prefs);
});

// --- Villa Feature ViewModels ---

/// Trạng thái bộ lọc bất biến phục vụ tìm kiếm, lọc tiện ích, vị trí, ngày lưu trú và phân trang danh sách biệt thự.
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

  /// Tổng số khách tính sức chứa hiệu lực (`adults + children`), không tính trẻ sơ sinh (`infants`), hoặc rơi về `minGuests`.
  int get effectiveGuests {
    final fromCounters = adults + children;
    if (fromCounters > 0) return fromCounters;
    return minGuests ?? 0;
  }

  /// Đếm số lượng tiêu chí lọc nâng cao đang được kích hoạt khác với mặc định để hiển thị huy hiệu trên nút Bộ lọc.
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

  /// Sao chép và cập nhật từng phần trạng thái bộ lọc, tự động đồng bộ `minGuests` theo tổng `adults + children`.
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
      bedrooms:
          bedrooms != null ? (bedrooms > 0 ? bedrooms : null) : this.bedrooms,
      beds: beds != null ? (beds > 0 ? beds : null) : this.beds,
      bathrooms: bathrooms != null
          ? (bathrooms > 0 ? bathrooms : null)
          : this.bathrooms,
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VillaFilterState &&
        other.searchQuery == searchQuery &&
        other.locationGroup == locationGroup &&
        other.lat == lat &&
        other.lng == lng &&
        other.radius == radius &&
        other.propertyType == propertyType &&
        other.priceMin == priceMin &&
        other.priceMax == priceMax &&
        other.minGuests == minGuests &&
        other.adults == adults &&
        other.children == children &&
        other.infants == infants &&
        other.pets == pets &&
        other.bedrooms == bedrooms &&
        other.beds == beds &&
        other.bathrooms == bathrooms &&
        listEquals(other.amenities, amenities) &&
        other.checkIn == checkIn &&
        other.checkOut == checkOut &&
        other.sort == sort &&
        other.page == page &&
        other.limit == limit &&
        other.dateMode == dateMode &&
        listEquals(other.selectedMonths, selectedMonths) &&
        other.flexDuration == flexDuration &&
        other.exactnessDays == exactnessDays;
  }

  @override
  int get hashCode => Object.hashAll([
        searchQuery,
        locationGroup,
        lat,
        lng,
        radius,
        propertyType,
        priceMin,
        priceMax,
        minGuests,
        adults,
        children,
        infants,
        pets,
        bedrooms,
        beds,
        bathrooms,
        Object.hashAll(amenities),
        checkIn,
        checkOut,
        sort,
        page,
        limit,
        dateMode,
        Object.hashAll(selectedMonths),
        flexDuration,
        exactnessDays,
      ]);
}

/// Provider lưu giữ trạng thái bộ lọc tìm kiếm biệt thự hiện tại.
final villaFilterProvider = StateProvider<VillaFilterState>((ref) {
  return const VillaFilterState();
});

/// Loads villas live from Backend API.
/// Provider tải danh sách biệt thự trực tiếp từ REST API theo `villaFilterProvider`.
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
    pets: filter.pets > 0 ? true : null,
    amenities: filter.amenities,
    checkIn: filter.checkIn,
    checkOut: filter.checkOut,
    sort: filter.sort,
    page: filter.page,
    limit: filter.limit,
  );
});

/// Loads paginated villas with pagination metadata.
/// Provider tải danh sách biệt thự kèm siêu dữ liệu phân trang (`PaginatedResult<Villa>`) theo `villaFilterProvider`.
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
    pets: filter.pets > 0 ? true : null,
    amenities: filter.amenities,
    checkIn: filter.checkIn,
    checkOut: filter.checkOut,
    sort: filter.sort,
    page: filter.page,
    limit: filter.limit,
  );
});

/// Loads villa detail live from Backend API.
/// Provider tải chi tiết một căn biệt thự theo mã `id` trực tiếp từ REST API.
final villaDetailProvider =
    FutureProvider.autoDispose.family<Villa?, String>((ref, id) async {
  final repository = ref.watch(villaRepositoryProvider);
  return repository.getVillaById(id);
});

/// Loads nearby/similar recommendations for a villa.
/// Provider tải danh sách tối đa 4 biệt thự gợi ý tương tự hoặc lân cận theo mã `id`.
final villaRecommendationsProvider =
    FutureProvider.autoDispose.family<List<Villa>, String>((ref, id) async {
  final repository = ref.watch(villaRepositoryProvider);
  return repository.getRecommendations(id, limit: 4);
});

/// Loads real nightly pricing from Backend API for selected date range.
/// Bộ tham số định danh truy vấn bảng giá theo đêm cho khoảng nửa mở `[checkIn, checkOut)`.
typedef PricingParams = ({
  String villaId,
  BookingDate checkIn,
  BookingDate checkOut
});

/// Provider tải chi tiết giá từng đêm thực tế từ máy chủ cho khoảng ngày đã chọn trong `PricingParams`.
final villaNightlyPricingProvider = FutureProvider.autoDispose
    .family<List<NightlyPrice>, PricingParams>((ref, params) async {
  final repository = ref.watch(villaRepositoryProvider);
  return repository.getNightlyPrices(
    villaId: params.villaId,
    checkIn: params.checkIn,
    checkOut: params.checkOut,
  );
});
