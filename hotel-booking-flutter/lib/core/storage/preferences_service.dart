import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

enum BookingQueueAddStatus { added, exists, full }

class BookingQueuePriceEstimate {
  final int nights;
  final int weekdayNights;
  final int weekendNights;
  final int roomSubtotal;
  final int weekendSurchargeTotal;
  final int extraGuests;
  final int surchargeAmount;
  final int extraGuestFeeAmount;
  final int cleaningFeeAmount;
  final int serviceFeeAmount;
  final int totalAmount;

  const BookingQueuePriceEstimate({
    required this.nights,
    required this.weekdayNights,
    required this.weekendNights,
    required this.roomSubtotal,
    required this.weekendSurchargeTotal,
    required this.extraGuests,
    required this.surchargeAmount,
    required this.extraGuestFeeAmount,
    required this.cleaningFeeAmount,
    required this.serviceFeeAmount,
    required this.totalAmount,
  });

  int get baseNightsAmount => roomSubtotal;
  int get cleaningFee => cleaningFeeAmount;
  int get serviceFee => serviceFeeAmount;
  int get estimatedTotal => totalAmount;
}

class BookingQueueItem {
  final String listingId;
  final String title;
  final String imageUrl;
  final int basePrice;
  final int pricePerNight;
  final int weekendPrice;
  final int weekendSurcharge;
  final int cleaningFee;
  final int serviceFee;
  final int surchargeAmount;
  final int extraGuestFee;
  final int includedGuests;
  final int maxGuests;
  final String location;
  final String? checkIn;
  final String? checkOut;
  final int? guests;
  final int guestsCount;
  final String? guestSummary;
  final bool instantBook;
  final String? couponCode;

  const BookingQueueItem({
    required this.listingId,
    required this.title,
    required this.imageUrl,
    int? basePrice,
    int? pricePerNight,
    this.weekendPrice = 0,
    this.weekendSurcharge = 0,
    this.cleaningFee = 0,
    this.serviceFee = 0,
    this.surchargeAmount = 0,
    this.extraGuestFee = 0,
    this.includedGuests = 10,
    this.maxGuests = 20,
    this.location = 'Vũng Tàu',
    this.checkIn,
    this.checkOut,
    int? guests,
    int? guestsCount,
    this.guestSummary,
    this.instantBook = false,
    this.couponCode,
  })  : basePrice = basePrice ?? pricePerNight ?? 0,
        pricePerNight = pricePerNight ?? basePrice ?? 0,
        guests = guests ?? guestsCount ?? 2,
        guestsCount = guestsCount ?? guests ?? 2;

  BookingQueueItem copyWith({
    String? title,
    String? imageUrl,
    int? basePrice,
    int? pricePerNight,
    int? weekendPrice,
    int? weekendSurcharge,
    int? cleaningFee,
    int? serviceFee,
    int? surchargeAmount,
    int? extraGuestFee,
    int? includedGuests,
    int? maxGuests,
    String? location,
    String? checkIn,
    String? checkOut,
    int? guests,
    int? guestsCount,
    String? guestSummary,
    bool? instantBook,
    String? couponCode,
    bool clearCouponCode = false,
  }) {
    final nextGuests = guestsCount ?? guests ?? this.guestsCount;
    return BookingQueueItem(
      listingId: listingId,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      basePrice: basePrice ?? this.basePrice,
      pricePerNight: pricePerNight ?? this.pricePerNight,
      weekendPrice: weekendPrice ?? this.weekendPrice,
      weekendSurcharge: weekendSurcharge ?? this.weekendSurcharge,
      cleaningFee: cleaningFee ?? this.cleaningFee,
      serviceFee: serviceFee ?? this.serviceFee,
      surchargeAmount: surchargeAmount ?? this.surchargeAmount,
      extraGuestFee: extraGuestFee ?? this.extraGuestFee,
      includedGuests: includedGuests ?? this.includedGuests,
      maxGuests: maxGuests ?? this.maxGuests,
      location: location ?? this.location,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      guests: nextGuests,
      guestsCount: nextGuests,
      guestSummary: guestSummary ?? this.guestSummary,
      instantBook: instantBook ?? this.instantBook,
      couponCode: clearCouponCode ? null : (couponCode ?? this.couponCode),
    );
  }

  /// Calculates temporary price estimate matching backend `booking-pricing.service.ts`.
  /// - Does NOT double-count weekend surcharge.
  /// - Does NOT multiply fixed `surchargeAmount` by nights.
  /// - Multiplies `extraGuestFee` by `extraGuests * nights`.
  BookingQueuePriceEstimate calculatePriceEstimate() {
    final inDate = DateTime.tryParse(checkIn ?? '');
    final outDate = DateTime.tryParse(checkOut ?? '');
    final hasValidDates =
        inDate != null && outDate != null && outDate.isAfter(inDate);

    final nights =
        hasValidDates ? outDate.difference(inDate).inDays.clamp(1, 365) : 1;

    int weekdayNights = 0;
    int weekendNights = 0;
    if (hasValidDates) {
      var cursor = DateTime.utc(inDate.year, inDate.month, inDate.day);
      final endUtc = DateTime.utc(outDate.year, outDate.month, outDate.day);
      while (cursor.isBefore(endUtc)) {
        // Backend `isWeekendDate` treats Saturday (6) and Sunday (7 in Dart / 0 in JS) as weekend.
        if (cursor.weekday == DateTime.saturday ||
            cursor.weekday == DateTime.sunday) {
          weekendNights++;
        } else {
          weekdayNights++;
        }
        cursor = cursor.add(const Duration(days: 1));
      }
    } else {
      weekdayNights = nights;
    }

    final effectiveWeekendNightPrice = weekendPrice > 0
        ? weekendPrice
        : (pricePerNight + (weekendSurcharge > 0 ? weekendSurcharge : 0));
    final perWeekendNightDelta =
        (effectiveWeekendNightPrice - pricePerNight).clamp(0, 1000000000);
    final weekendSurchargeTotal = weekendNights * perWeekendNightDelta;
    final roomSubtotal = weekdayNights * pricePerNight +
        weekendNights * effectiveWeekendNightPrice;

    final extraGuests = (guestsCount - includedGuests).clamp(0, 100);
    // Fixed surcharge is applied once when extraGuests > 0, NEVER multiplied by nights.
    final fixedSurcharge = extraGuests > 0 ? surchargeAmount : 0;
    final extraGuestFeeTotal = extraGuests * extraGuestFee * nights;

    final total = roomSubtotal +
        fixedSurcharge +
        extraGuestFeeTotal +
        cleaningFee +
        serviceFee;

    return BookingQueuePriceEstimate(
      nights: nights,
      weekdayNights: weekdayNights,
      weekendNights: weekendNights,
      roomSubtotal: roomSubtotal,
      weekendSurchargeTotal: weekendSurchargeTotal,
      extraGuests: extraGuests,
      surchargeAmount: fixedSurcharge,
      extraGuestFeeAmount: extraGuestFeeTotal,
      cleaningFeeAmount: cleaningFee,
      serviceFeeAmount: serviceFee,
      totalAmount: total < 0 ? 0 : total,
    );
  }

  factory BookingQueueItem.fromJson(Map<String, dynamic> json) {
    final price = (json['pricePerNight'] as num?)?.toInt() ??
        (json['basePrice'] as num?)?.toInt() ??
        0;
    final gCount = (json['guestsCount'] as num?)?.toInt() ??
        (json['guests'] as num?)?.toInt() ??
        2;
    return BookingQueueItem(
      listingId: json['listingId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      basePrice: price,
      pricePerNight: price,
      weekendPrice: (json['weekendPrice'] as num?)?.toInt() ?? 0,
      weekendSurcharge: (json['weekendSurcharge'] as num?)?.toInt() ?? 0,
      cleaningFee: (json['cleaningFee'] as num?)?.toInt() ?? 0,
      serviceFee: (json['serviceFee'] as num?)?.toInt() ?? 0,
      surchargeAmount: (json['surchargeAmount'] as num?)?.toInt() ?? 0,
      extraGuestFee: (json['extraGuestFee'] as num?)?.toInt() ?? 0,
      includedGuests: (json['includedGuests'] as num?)?.toInt() ?? 10,
      maxGuests: (json['maxGuests'] as num?)?.toInt() ?? 20,
      location: json['location']?.toString() ?? 'Vũng Tàu',
      checkIn: json['checkIn']?.toString(),
      checkOut: json['checkOut']?.toString(),
      guests: gCount,
      guestsCount: gCount,
      guestSummary: json['guestSummary']?.toString(),
      instantBook: json['instantBook'] == true,
      couponCode: json['couponCode']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'listingId': listingId,
        'title': title,
        'imageUrl': imageUrl,
        'basePrice': basePrice,
        'pricePerNight': pricePerNight,
        if (weekendPrice > 0) 'weekendPrice': weekendPrice,
        'weekendSurcharge': weekendSurcharge,
        'cleaningFee': cleaningFee,
        'serviceFee': serviceFee,
        if (surchargeAmount > 0) 'surchargeAmount': surchargeAmount,
        'extraGuestFee': extraGuestFee,
        'includedGuests': includedGuests,
        'maxGuests': maxGuests,
        'location': location,
        if (checkIn != null) 'checkIn': checkIn,
        if (checkOut != null) 'checkOut': checkOut,
        'guests': guestsCount,
        'guestsCount': guestsCount,
        if (guestSummary != null) 'guestSummary': guestSummary,
        'instantBook': instantBook,
        if (couponCode != null && couponCode!.isNotEmpty)
          'couponCode': couponCode,
      };
}

class RecentlyViewedItem {
  final String id;
  final String title;
  final String imageUrl;
  final String location;
  final int pricePerNight;
  final double rating;
  final int reviewCount;
  final int bedrooms;
  final int maxGuests;
  final String? viewedAtIso;

  const RecentlyViewedItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.location,
    required this.pricePerNight,
    required this.rating,
    this.reviewCount = 0,
    this.bedrooms = 0,
    this.maxGuests = 0,
    this.viewedAtIso,
  });

  factory RecentlyViewedItem.fromJson(Map<String, dynamic> json) {
    return RecentlyViewedItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      pricePerNight: (json['pricePerNight'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      bedrooms: (json['bedrooms'] as num?)?.toInt() ?? 0,
      maxGuests: (json['maxGuests'] as num?)?.toInt() ?? 0,
      viewedAtIso: json['viewedAtIso']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'imageUrl': imageUrl,
        'location': location,
        'pricePerNight': pricePerNight,
        'rating': rating,
        'reviewCount': reviewCount,
        'bedrooms': bedrooms,
        'maxGuests': maxGuests,
        if (viewedAtIso != null) 'viewedAtIso': viewedAtIso,
      };
}

class PreferencesService {
  static const String _keyRecentlyViewed = 'recently_viewed_listings';
  static const String _keySearchHistory = 'booking_search_history';
  static const String _keyBookingQueue = 'booking_queue_items';
  static const String _keyLastAiQuery = 'lastAiSearchQuery';
  static const String _keyPendingBookingIntent = 'pending_booking_intent';
  static const String _keyAccountProfile = 'account_profile_extra';
  static const String _keyGuestFavorites = 'guest_favorite_villa_ids';
  static const String _keyWishlistSynced = 'wishlist_guest_synced';
  static const String _keyWishlistSyncedUserId = 'wishlist_synced_user_id';
  static const String _keyWishlistInvalidIds = 'wishlist_invalid_listing_ids';

  static const int maxRecentlyViewed = 8;
  static const int maxSearchHistory = 8;
  static const int maxBookingQueue = 5;
  static const int maxBookingQueueSize = maxBookingQueue;

  /// Shared reference to the active PreferencesService instance so repositories
  /// constructed without direct PreferencesService injection can coordinate
  /// guest-to-authenticated wishlist migration and session cleanup safely.
  static PreferencesService? activeInstance;

  final SharedPreferences _prefs;
  bool _isAuthenticatedSession = false;
  List<String>? _justSyncedAuthoritativeIds;

  PreferencesService(this._prefs) {
    activeInstance = this;
    _isAuthenticatedSession = _prefs.getBool(_keyWishlistSynced) == true;
  }

  static Future<PreferencesService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService(prefs);
  }

  /// Normalizes and deduplicates listing IDs while preserving order.
  static List<String> normalizeListingIds(Iterable<String> rawIds) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in rawIds) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      if (seen.add(trimmed)) {
        result.add(trimmed);
      }
    }
    return result;
  }

  /// Checks whether a listing ID is a valid positive integer ID for backend wishlist APIs.
  static bool isValidListingId(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return false;
    final parsed = int.tryParse(trimmed);
    return parsed != null && parsed > 0;
  }

  // --- Locale ---
  String getLocale() {
    return _prefs.getString(AppConstants.storageLocaleKey) ?? 'vi';
  }

  Future<bool> setLocale(String languageCode) {
    return _prefs.setString(AppConstants.storageLocaleKey, languageCode);
  }

  // --- Favorites / Wishlist (with Guest -> Auth Migration & Account Isolation) ---
  List<String> getFavorites() {
    final raw =
        _prefs.getStringList(AppConstants.storageFavoritesKey) ?? const [];
    final invalid = getInvalidWishlistIds().toSet();
    return normalizeListingIds(raw)
        .where((id) => !invalid.contains(id))
        .toList(growable: false);
  }

  Future<bool> setFavorites(List<String> villaIds) async {
    if (_justSyncedAuthoritativeIds != null) {
      final authoritative = _justSyncedAuthoritativeIds!;
      _justSyncedAuthoritativeIds = null;
      return _prefs.setStringList(
          AppConstants.storageFavoritesKey, authoritative);
    }

    final invalid = _isAuthenticatedSession
        ? getInvalidWishlistIds().toSet()
        : const <String>{};
    final normalized = normalizeListingIds(villaIds)
        .where((id) => !invalid.contains(id))
        .toList(growable: false);

    if (!_isAuthenticatedSession) {
      await _prefs.setStringList(_keyGuestFavorites, normalized);
      await _prefs.setBool(_keyWishlistSynced, false);
    }
    return _prefs.setStringList(AppConstants.storageFavoritesKey, normalized);
  }

  /// Returns local guest favorites that have not yet been migrated to the server.
  List<String> getPendingGuestFavorites() {
    if (_prefs.getBool(_keyWishlistSynced) == true) {
      final guestList = _prefs.getStringList(_keyGuestFavorites) ?? const [];
      return normalizeListingIds(guestList)
          .where(isValidListingId)
          .toList(growable: false);
    }
    final guestExplicit = _prefs.getStringList(_keyGuestFavorites);
    final source = guestExplicit ??
        (_prefs.getString(_keyWishlistSyncedUserId) == null
            ? (_prefs.getStringList(AppConstants.storageFavoritesKey) ??
                const [])
            : const <String>[]);
    return normalizeListingIds(source)
        .where(isValidListingId)
        .toList(growable: false);
  }

  bool get isWishlistSynced => _prefs.getBool(_keyWishlistSynced) == true;

  String? get syncedWishlistUserId =>
      _prefs.getString(_keyWishlistSyncedUserId);

  List<String> getInvalidWishlistIds() {
    return _prefs.getStringList(_keyWishlistInvalidIds) ?? const [];
  }

  /// Called only after guest wishlist migration + backend GET /api/wishlist succeeds.
  /// Never called if the server request fails.
  Future<List<String>> markWishlistSynced({
    required List<String> backendIds,
    required List<String> migratedGuestIds,
    List<String> invalidIds = const [],
    String? userId,
  }) async {
    final previousUserId = _prefs.getString(_keyWishlistSyncedUserId);
    final isDifferentUser = userId != null &&
        userId.isNotEmpty &&
        previousUserId != null &&
        previousUserId.isNotEmpty &&
        previousUserId != userId;

    final invalidSet = normalizeListingIds(invalidIds).toSet();
    final validBackendIds = normalizeListingIds(backendIds)
        .where((id) => isValidListingId(id) && !invalidSet.contains(id))
        .toList();
    final validGuestIds = normalizeListingIds(migratedGuestIds)
        .where((id) => isValidListingId(id) && !invalidSet.contains(id))
        .toList();

    // Server list comes first, merged with valid guest IDs (guest never overwrites server,
    // and if switching accounts, previous user's session IDs are discarded).
    final merged = normalizeListingIds([
      ...validBackendIds,
      ...validGuestIds,
    ]);

    _isAuthenticatedSession = true;
    _justSyncedAuthoritativeIds = merged;
    await _prefs.setBool(_keyWishlistSynced, true);
    if (userId != null && userId.isNotEmpty) {
      await _prefs.setString(_keyWishlistSyncedUserId, userId);
    } else if (isDifferentUser) {
      await _prefs.remove(_keyWishlistSyncedUserId);
    }
    await _prefs.remove(_keyGuestFavorites);
    await _prefs.setStringList(
      _keyWishlistInvalidIds,
      invalidSet.toList(growable: false),
    );
    await _prefs.setStringList(AppConstants.storageFavoritesKey, merged);
    return merged;
  }

  /// Ensures failed server sync never marks guest favorites as synced.
  Future<void> markWishlistSyncFailed() async {
    await _prefs.setBool(_keyWishlistSynced, false);
  }

  // --- Recently Viewed Listings (max 8) ---
  List<RecentlyViewedItem> getRecentlyViewed() {
    final raw = _prefs.getString(_keyRecentlyViewed);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(RecentlyViewedItem.fromJson)
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<RecentlyViewedItem>> recordRecentlyViewed(
      RecentlyViewedItem item) async {
    if (item.id.isEmpty) return getRecentlyViewed();
    final current = getRecentlyViewed()
        .where((existing) => existing.id != item.id)
        .toList();
    final updated = [item, ...current].take(maxRecentlyViewed).toList();
    await _prefs.setString(
      _keyRecentlyViewed,
      jsonEncode(updated.map((e) => e.toJson()).toList()),
    );
    return updated;
  }

  Future<List<RecentlyViewedItem>> addRecentlyViewed(RecentlyViewedItem item) =>
      recordRecentlyViewed(item);

  Future<void> clearRecentlyViewed() async {
    await _prefs.remove(_keyRecentlyViewed);
  }

  // --- Search History (max 8) ---
  List<String> getSearchHistory() {
    return _prefs.getStringList(_keySearchHistory) ?? const [];
  }

  Future<List<String>> addSearchHistory(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return getSearchHistory();
    final current = getSearchHistory()
        .where((e) => e.toLowerCase() != trimmed.toLowerCase())
        .toList();
    final updated = [trimmed, ...current].take(maxSearchHistory).toList();
    await _prefs.setStringList(_keySearchHistory, updated);
    return updated;
  }

  Future<List<String>> removeSearchHistory(String query) async {
    final trimmed = query.trim();
    final updated = getSearchHistory()
        .where((e) => e.toLowerCase() != trimmed.toLowerCase())
        .toList();
    await _prefs.setStringList(_keySearchHistory, updated);
    return updated;
  }

  Future<void> clearSearchHistory() async {
    await _prefs.remove(_keySearchHistory);
  }

  // --- Booking Queue / MultiBooking (max 5) ---
  List<BookingQueueItem> getBookingQueue() {
    final raw = _prefs.getString(_keyBookingQueue);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(BookingQueueItem.fromJson)
          .where((item) => item.listingId.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<({List<BookingQueueItem> items, BookingQueueAddStatus status})>
      addBookingQueueItem(BookingQueueItem item) async {
    final current = List<BookingQueueItem>.from(getBookingQueue());
    if (current.any((e) => e.listingId == item.listingId)) {
      return (items: current, status: BookingQueueAddStatus.exists);
    }
    if (current.length >= maxBookingQueue) {
      return (items: current, status: BookingQueueAddStatus.full);
    }
    final updated = [...current, item];
    await _saveBookingQueue(updated);
    return (items: updated, status: BookingQueueAddStatus.added);
  }

  Future<String> addToBookingQueue(BookingQueueItem item) async {
    final res = await addBookingQueueItem(item);
    switch (res.status) {
      case BookingQueueAddStatus.added:
        return 'added';
      case BookingQueueAddStatus.exists:
        return 'exists';
      case BookingQueueAddStatus.full:
        return 'full';
    }
  }

  Future<List<BookingQueueItem>> updateBookingQueueItem(
      BookingQueueItem updatedItem) async {
    final updated = getBookingQueue()
        .map((e) => e.listingId == updatedItem.listingId ? updatedItem : e)
        .toList();
    await _saveBookingQueue(updated);
    return updated;
  }

  Future<List<BookingQueueItem>> removeBookingQueueItem(
      String listingId) async {
    final updated =
        getBookingQueue().where((e) => e.listingId != listingId).toList();
    await _saveBookingQueue(updated);
    return updated;
  }

  Future<List<BookingQueueItem>> removeFromBookingQueue(String listingId) =>
      removeBookingQueueItem(listingId);

  Future<void> clearBookingQueue() async {
    await _prefs.remove(_keyBookingQueue);
  }

  Future<void> _saveBookingQueue(List<BookingQueueItem> items) async {
    await _prefs.setString(
      _keyBookingQueue,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  // --- Account Profile Extra Fields (`accountProfileStorage.ts`) ---
  Map<String, dynamic> getAccountProfile([String? userId]) {
    final key = (userId != null && userId.isNotEmpty)
        ? '${_keyAccountProfile}_$userId'
        : _keyAccountProfile;
    final raw = _prefs.getString(key) ?? _prefs.getString(_keyAccountProfile);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  Future<void> saveAccountProfile(
    dynamic profileOrUserId, [
    Map<String, dynamic>? profileData,
  ]) async {
    if (profileOrUserId is String && profileData != null) {
      final key = profileOrUserId.isNotEmpty
          ? '${_keyAccountProfile}_$profileOrUserId'
          : _keyAccountProfile;
      await _prefs.setString(key, jsonEncode(profileData));
      await _prefs.setString(_keyAccountProfile, jsonEncode(profileData));
    } else if (profileOrUserId is Map<String, dynamic>) {
      await _prefs.setString(_keyAccountProfile, jsonEncode(profileOrUserId));
    }
  }

  // --- AI Search Last Query ---
  String getLastAiSearchQuery() {
    return _prefs.getString(_keyLastAiQuery) ?? '';
  }

  Future<void> setLastAiSearchQuery(String query) async {
    await _prefs.setString(_keyLastAiQuery, query.trim());
  }

  // --- Pending Booking Intent (when unauthenticated user clicks "Đặt ngay") ---
  Map<String, dynamic>? getPendingBookingIntent() {
    final raw = _prefs.getString(_keyPendingBookingIntent);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> setPendingBookingIntent(Map<String, dynamic> intent) async {
    await _prefs.setString(_keyPendingBookingIntent, jsonEncode(intent));
  }

  Future<void> clearPendingBookingIntent() async {
    await _prefs.remove(_keyPendingBookingIntent);
  }

  /// Clears session-scoped storage on logout matching `authService.ts`
  Future<void> clearSessionData() async {
    _isAuthenticatedSession = false;
    await _prefs.remove(AppConstants.storageFavoritesKey);
    await _prefs.remove(_keyGuestFavorites);
    await _prefs.remove(_keyWishlistSynced);
    await _prefs.remove(_keyWishlistSyncedUserId);
    await _prefs.remove(_keyWishlistInvalidIds);
    await _prefs.remove(_keyBookingQueue);
    await _prefs.remove(_keySearchHistory);
    await _prefs.remove(_keyLastAiQuery);
    await _prefs.remove(_keyPendingBookingIntent);
  }
}
