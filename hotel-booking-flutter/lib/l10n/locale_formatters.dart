import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import '../core/date/booking_date.dart';
import '../features/villas/domain/entities/villa.dart';
import 'generated/app_localizations.dart';

/// Structured localized copy for async error states, strictly separating
/// device/network offline errors from backend server errors (Rule 5).
class LocalizedErrorCopy {
  final String title;
  final String message;
  final String retryLabel;
  final bool isOffline;
  final bool isServerError;
  final int? statusCode;

  const LocalizedErrorCopy({
    required this.title,
    required this.message,
    required this.retryLabel,
    this.isOffline = false,
    this.isServerError = false,
    this.statusCode,
  });
}

/// Locale-aware formatting & domain localization utilities for `vi`, `en`, and `ko`.
///
/// Enforces The Palm business rules:
/// - Currency ALWAYS remains integer VND (`₫`) across all locales; never converts currency.
/// - Calendar dates ALWAYS use `Asia/Ho_Chi_Minh` pure dates (`BookingDate`, `YYYY-MM-DD`).
/// - Server errors (`ServerFailure` / HTTP 5xx) are NEVER misclassified as offline/network errors.
abstract final class LocaleFormatters {
  static final NumberFormat _vndNumberFormat = NumberFormat('#,###', 'vi_VN');

  static const List<String> _viWeekdays = <String>[
    'T2',
    'T3',
    'T4',
    'T5',
    'T6',
    'T7',
    'CN',
  ];

  static const List<String> _enWeekdays = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static const List<String> _koWeekdays = <String>[
    '월',
    '화',
    '수',
    '목',
    '금',
    '토',
    '일',
  ];

  static const List<String> _enMonths = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _enShortMonths = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Resolves [AppLocalizations] for a language code (`vi`, `en`, `ko`),
  /// defaulting to Vietnamese (`vi`) if an unsupported code is passed.
  static AppLocalizations resolveL10n([String localeCode = 'vi']) {
    final normalized = normalizeLanguageCode(localeCode);
    return lookupAppLocalizations(Locale(normalized));
  }

  /// Normalizes a locale string (e.g. `vi_VN`, `en-US`, `ko_KR`) to `vi`, `en`, or `ko`.
  static String normalizeLanguageCode(String? rawCode) {
    if (rawCode == null || rawCode.trim().isEmpty) return 'vi';
    final primary = rawCode.trim().toLowerCase().split(RegExp(r'[-_]')).first;
    if (primary == 'en' || primary == 'ko' || primary == 'vi') {
      return primary;
    }
    return 'vi';
  }

  /// Formats an integer VND amount (e.g. `3500000` -> `"3.500.000 ₫"`).
  /// Never converts currency when switching locale; localizes only the missing-price fallback.
  static String formatVnd(
    int? amount, {
    String localeCode = 'vi',
    AppLocalizations? l10n,
  }) {
    final effectiveL10n = l10n ?? resolveL10n(localeCode);
    if (amount == null || amount <= 0) {
      return effectiveL10n.contactForPrice;
    }
    return '${_vndNumberFormat.format(amount)} ₫';
  }

  /// Formats base nightly rate with localized prefix/unit while keeping VND `₫`:
  /// - `vi`: `"Từ 3.500.000 ₫ / đêm"`
  /// - `en`: `"From 3.500.000 ₫ / night"`
  /// - `ko`: `"1박당 3.500.000 ₫부터"`
  static String formatPriceFromPerNight(
    int? amount, {
    String localeCode = 'vi',
    AppLocalizations? l10n,
  }) {
    final effectiveL10n = l10n ?? resolveL10n(localeCode);
    if (amount == null || amount <= 0) {
      return effectiveL10n.contactForPrice;
    }
    final vnd = '${_vndNumberFormat.format(amount)} ₫';
    return effectiveL10n.priceFrom(vnd);
  }

  /// Formats Saturday rate with localized label while keeping VND `₫`:
  /// - `vi`: `"Thứ 7: 5.200.000 ₫"`
  /// - `en`: `"Sat: 5.200.000 ₫"`
  /// - `ko`: `"토요일: 5.200.000 ₫"`
  static String? formatSaturdayPrice(
    int? amount, {
    String localeCode = 'vi',
    AppLocalizations? l10n,
  }) {
    if (amount == null || amount <= 0) {
      return null;
    }
    final effectiveL10n = l10n ?? resolveL10n(localeCode);
    final vnd = '${_vndNumberFormat.format(amount)} ₫';
    return effectiveL10n.saturdayPrice(vnd);
  }

  /// Formats a [BookingDate] (`Asia/Ho_Chi_Minh` pure calendar date) according to locale:
  /// - `vi`: `15/10/2026`
  /// - `en`: `Oct 15, 2026` (or `15/10/2026` when [numeric] is true)
  /// - `ko`: `2026. 10. 15.`
  static String formatBookingDate(
    BookingDate date, {
    String localeCode = 'vi',
    bool numeric = false,
  }) {
    final lang = normalizeLanguageCode(localeCode);
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yyyy = date.year.toString();

    if (numeric || lang == 'vi') {
      return '$dd/$mm/$yyyy';
    }
    if (lang == 'ko') {
      return '$yyyy. $mm. $dd.';
    }
    final monthShort = _enShortMonths[(date.month - 1).clamp(0, 11)];
    return '$monthShort ${date.day}, $yyyy';
  }

  /// Formats a [BookingDate] for nightly price breakdown rows with localized weekday:
  /// - `vi`: `15/10 (T5)`
  /// - `en`: `15/10 (Thu)`
  /// - `ko`: `10/15 (목)`
  static String formatNightlyDateWithWeekday(
    BookingDate date, {
    String localeCode = 'vi',
  }) {
    final lang = normalizeLanguageCode(localeCode);
    final weekdayIndex = (date.toDateTimeUtc().weekday - 1).clamp(0, 6);
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');

    switch (lang) {
      case 'en':
        return '$dd/$mm (${_enWeekdays[weekdayIndex]})';
      case 'ko':
        return '$mm/$dd (${_koWeekdays[weekdayIndex]})';
      case 'vi':
      default:
        return '$dd/$mm (${_viWeekdays[weekdayIndex]})';
    }
  }

  /// Formats calendar month and year header:
  /// - `vi`: `Tháng 10, 2026`
  /// - `en`: `October 2026`
  /// - `ko`: `2026년 10월`
  static String formatMonthYear(
    int year,
    int month, {
    String localeCode = 'vi',
  }) {
    final lang = normalizeLanguageCode(localeCode);
    final safeMonth = month.clamp(1, 12);
    switch (lang) {
      case 'en':
        return '${_enMonths[safeMonth - 1]} $year';
      case 'ko':
        return '$year년 $safeMonth월';
      case 'vi':
      default:
        return 'Tháng $safeMonth, $year';
    }
  }

  /// Formats a half-open stay interval `[checkIn, checkOut)` with night count:
  /// - `vi`: `15/10/2026 – 17/10/2026 (2 đêm)`
  /// - `en`: `Oct 15, 2026 – Oct 17, 2026 (2 nights)`
  /// - `ko`: `2026. 10. 15. – 2026. 10. 17. (2박)`
  static String formatStayRange(
    BookingDate checkIn,
    BookingDate checkOut, {
    String localeCode = 'vi',
    AppLocalizations? l10n,
  }) {
    final effectiveL10n = l10n ?? resolveL10n(localeCode);
    final nights = checkIn.differenceInNights(checkOut).clamp(0, 366);
    final start = formatBookingDate(checkIn, localeCode: localeCode);
    final end = formatBookingDate(checkOut, localeCode: localeCode);
    if (nights <= 0) {
      return '$start – $end';
    }
    return '$start – $end (${effectiveL10n.nightsCount(nights)})';
  }

  /// Standardized time-of-day greeting with proper sentence casing:
  /// - 05:00..11:59 -> `"Chào buổi sáng!"` / `"Good morning!"` / `"좋은 아침입니다!"`
  /// - 12:00..17:59 -> `"Chào buổi chiều!"` / `"Good afternoon!"` / `"좋은 오후입니다!"`
  /// - 18:00..04:59 -> `"Chào buổi tối!"` / `"Good evening!"` / `"좋은 저녁입니다!"`
  static String greetingForHour(
    int hour, {
    String localeCode = 'vi',
    AppLocalizations? l10n,
  }) {
    final effectiveL10n = l10n ?? resolveL10n(localeCode);
    final normalizedHour = ((hour % 24) + 24) % 24;
    if (normalizedHour >= 5 && normalizedHour < 12) {
      return effectiveL10n.greetingMorning;
    }
    if (normalizedHour >= 12 && normalizedHour < 18) {
      return effectiveL10n.greetingAfternoon;
    }
    return effectiveL10n.greetingEvening;
  }

  /// Classifies an application error/exception into accurate, localized user-facing copy.
  ///
  /// CRITICAL RULE 5: Never converts a backend server error (`ServerFailure` / HTTP 5xx)
  /// into a device offline / network connection error.
  static LocalizedErrorCopy localizeFailure(
    Object error, {
    String localeCode = 'vi',
    AppLocalizations? l10n,
  }) {
    final effectiveL10n = l10n ?? resolveL10n(localeCode);
    final typeName = error.runtimeType.toString();
    final statusCode = _readIntProperty(error, (dynamic d) => d.statusCode);
    final code =
        (_readStringProperty(error, (dynamic d) => d.code) ?? '').toUpperCase();
    final message = _readStringProperty(error, (dynamic d) => d.message) ?? '';
    final isOfflineFlag =
        _readBoolProperty(error, (dynamic d) => d.isOffline) ?? false;
    final isServerErrorFlag =
        _readBoolProperty(error, (dynamic d) => d.isServerError) ?? false;

    final isServer = isServerErrorFlag ||
        typeName.contains('ServerFailure') ||
        code == 'SERVER_ERROR' ||
        (statusCode != null && statusCode >= 500);
    if (isServer) {
      return LocalizedErrorCopy(
        title: effectiveL10n.errorServerTitle,
        message: effectiveL10n.errorServerMessage,
        retryLabel: effectiveL10n.ctaRetry,
        isOffline: false,
        isServerError: true,
        statusCode: statusCode ?? 500,
      );
    }

    final isNetworkOrOffline = isOfflineFlag ||
        typeName.contains('NetworkFailure') ||
        typeName.contains('OfflineFailure') ||
        typeName.contains('TimeoutFailure') ||
        typeName.contains('DnsFailure') ||
        typeName.contains('ConnectionRefusedFailure') ||
        typeName.contains('CertificateFailure') ||
        typeName.contains('SocketException') ||
        code == 'NETWORK_ERROR' ||
        code == 'NETWORK_OFFLINE' ||
        code == 'DNS_FAILURE' ||
        code == 'CONNECTION_REFUSED' ||
        code.contains('TIMEOUT');
    if (isNetworkOrOffline) {
      return LocalizedErrorCopy(
        title: effectiveL10n.errorOfflineTitle,
        message: effectiveL10n.errorOfflineMessage,
        retryLabel: effectiveL10n.ctaRetry,
        isOffline: true,
        isServerError: false,
      );
    }

    final isAuthOrForbidden = typeName.contains('AuthFailure') ||
        typeName.contains('ForbiddenFailure') ||
        statusCode == 401 ||
        statusCode == 403 ||
        code == 'UNAUTHORIZED' ||
        code == 'FORBIDDEN';
    if (isAuthOrForbidden) {
      final isForbidden = statusCode == 403 ||
          typeName.contains('ForbiddenFailure') ||
          code == 'FORBIDDEN';
      return LocalizedErrorCopy(
        title: effectiveL10n.errorOccurred,
        message: isForbidden
            ? effectiveL10n.errorForbiddenMessage
            : effectiveL10n.errorUnauthorizedMessage,
        retryLabel: effectiveL10n.ctaRetry,
        statusCode: statusCode ?? (isForbidden ? 403 : 401),
      );
    }

    final isNotFound = typeName.contains('NotFoundFailure') ||
        statusCode == 404 ||
        code == 'NOT_FOUND';
    if (isNotFound) {
      return LocalizedErrorCopy(
        title: effectiveL10n.errorNotFoundTitle,
        message: effectiveL10n.errorNotFoundMessage,
        retryLabel: effectiveL10n.ctaRetry,
        statusCode: statusCode ?? 404,
      );
    }

    final isRateLimited = typeName.contains('RateLimitFailure') ||
        statusCode == 429 ||
        code == 'RATE_LIMITED';
    if (isRateLimited) {
      return LocalizedErrorCopy(
        title: effectiveL10n.errorOccurred,
        message: effectiveL10n.errorRateLimitMessage,
        retryLabel: effectiveL10n.ctaRetry,
        statusCode: statusCode ?? 429,
      );
    }

    final isValidationOrConflict = typeName.contains('ValidationFailure') ||
        typeName.contains('ConflictFailure') ||
        statusCode == 409 ||
        statusCode == 422 ||
        code == 'VALIDATION_ERROR' ||
        code == 'CONFLICT';
    if (isValidationOrConflict) {
      return LocalizedErrorCopy(
        title: effectiveL10n.errorOccurred,
        message: normalizeLanguageCode(localeCode) == 'vi' &&
                message.trim().isNotEmpty
            ? message
            : effectiveL10n.errorValidationMessage,
        retryLabel: effectiveL10n.ctaRetry,
        statusCode: statusCode,
      );
    }

    return LocalizedErrorCopy(
      title: effectiveL10n.errorOccurred,
      message: effectiveL10n.errorTryAgain,
      retryLabel: effectiveL10n.ctaRetry,
    );
  }

  static int? _readIntProperty(
    Object target,
    Object? Function(dynamic) getter,
  ) {
    try {
      final value = getter(target);
      if (value is int) return value;
    } catch (_) {}
    return null;
  }

  static String? _readStringProperty(
    Object target,
    Object? Function(dynamic) getter,
  ) {
    try {
      final value = getter(target);
      if (value is String) return value;
    } catch (_) {}
    return null;
  }

  static bool? _readBoolProperty(
    Object target,
    Object? Function(dynamic) getter,
  ) {
    try {
      final value = getter(target);
      if (value is bool) return value;
    } catch (_) {}
    return null;
  }

  /// Localizes [VillaBadgeType] without altering the priority order
  /// (`featured > newVilla > nearBeach > saltwater > group`).
  static String localizeVillaBadge(
    VillaBadgeType badge, {
    String localeCode = 'vi',
    AppLocalizations? l10n,
  }) {
    final effectiveL10n = l10n ?? resolveL10n(localeCode);
    switch (badge) {
      case VillaBadgeType.featured:
        return effectiveL10n.badgeFeatured;
      case VillaBadgeType.newVilla:
        return effectiveL10n.badgeNew;
      case VillaBadgeType.nearBeach:
        return effectiveL10n.badgeNearBeach;
      case VillaBadgeType.saltwater:
        return effectiveL10n.badgeSaltwater;
      case VillaBadgeType.group:
        return effectiveL10n.badgeGroup;
    }
  }

  /// Localizes booking state machine status codes (`pending_payment`, `paid`, `confirmed`, etc.).
  static String localizeBookingStatus(
    String rawStatus, {
    String localeCode = 'vi',
    AppLocalizations? l10n,
  }) {
    final effectiveL10n = l10n ?? resolveL10n(localeCode);
    switch (rawStatus.trim().toLowerCase()) {
      case 'pending_payment':
      case 'pending':
        return effectiveL10n.bookingStatusPendingPayment;
      case 'payment_expired':
      case 'expired':
        return effectiveL10n.bookingStatusPaymentExpired;
      case 'paid':
        return effectiveL10n.bookingStatusPaid;
      case 'confirmed':
        return effectiveL10n.bookingStatusConfirmed;
      case 'checked_in':
        return effectiveL10n.bookingStatusCheckedIn;
      case 'checked_out':
        return effectiveL10n.bookingStatusCheckedOut;
      case 'completed':
        return effectiveL10n.bookingStatusCompleted;
      case 'cancelled_by_guest':
      case 'cancelled':
        return effectiveL10n.bookingStatusCancelledByGuest;
      case 'cancelled_by_host':
        return effectiveL10n.bookingStatusCancelledByHost;
      case 'cancelled_by_admin':
        return effectiveL10n.bookingStatusCancelledByAdmin;
      case 'rejected':
        return effectiveL10n.bookingStatusRejected;
      case 'refund_pending':
        return effectiveL10n.bookingStatusRefundPending;
      case 'refunded':
        return effectiveL10n.bookingStatusRefunded;
      default:
        return rawStatus;
    }
  }

  /// Localizes Host listing status codes (`draft`, `pending_approval`, `published`, `hidden`, `rejected`).
  static String localizeHostListingStatus(
    String rawStatus, {
    String localeCode = 'vi',
    AppLocalizations? l10n,
  }) {
    final effectiveL10n = l10n ?? resolveL10n(localeCode);
    switch (rawStatus.trim().toLowerCase()) {
      case 'draft':
        return effectiveL10n.hostListingDraft;
      case 'pending_approval':
      case 'pending':
        return effectiveL10n.hostListingPendingApproval;
      case 'published':
      case 'approved':
        return effectiveL10n.hostListingPublished;
      case 'hidden':
        return effectiveL10n.hostListingHidden;
      case 'rejected':
        return effectiveL10n.hostListingRejected;
      default:
        return rawStatus;
    }
  }

  /// Localizes Admin user account status codes (`active`, `suspended`, `inactive`).
  static String localizeAdminUserStatus(
    String rawStatus, {
    String localeCode = 'vi',
    AppLocalizations? l10n,
  }) {
    final effectiveL10n = l10n ?? resolveL10n(localeCode);
    switch (rawStatus.trim().toLowerCase()) {
      case 'active':
        return effectiveL10n.adminUserStatusActive;
      case 'suspended':
      case 'blocked':
        return effectiveL10n.adminUserStatusSuspended;
      case 'inactive':
        return effectiveL10n.adminUserStatusInactive;
      default:
        return rawStatus;
    }
  }
}
