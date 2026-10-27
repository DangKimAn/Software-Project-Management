import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/core/date/booking_date.dart';
import 'package:hotel_booking_flutter/features/villas/domain/entities/villa.dart';
import 'package:hotel_booking_flutter/l10n/l10n.dart';

class _StubNetworkFailure {
  final String message = 'Không có kết nối mạng hoặc mạng không ổn định.';
  final int? statusCode = null;
  final String code = 'NETWORK_OFFLINE';
  final bool isOffline = true;
  final bool isServerError = false;

  const _StubNetworkFailure();
}

class _StubServerFailure {
  final String message;
  final int? statusCode;
  final String code = 'SERVER_ERROR';
  final bool isOffline = false;
  final bool isServerError = true;

  const _StubServerFailure(
    this.message, {
    this.statusCode = 500,
  });
}

class _StubAuthFailure {
  final String message;
  final String code;
  final int? statusCode;

  const _StubAuthFailure(
    this.message, [
    this.code = 'UNAUTHORIZED',
    this.statusCode = 401,
  ]);
}

Map<String, dynamic> _readArbFile(String fileName) {
  final candidates = <File>[
    File('lib/l10n/$fileName'),
    File('hotel-booking-flutter/lib/l10n/$fileName'),
  ];
  for (final file in candidates) {
    if (file.existsSync()) {
      final raw = file.readAsStringSync();
      return jsonDecode(raw) as Map<String, dynamic>;
    }
  }
  throw StateError('ARB file not found: $fileName');
}

Set<String> _extractMessageKeys(Map<String, dynamic> arb) {
  return arb.keys.where((k) => !k.startsWith('@')).toSet();
}

Set<String> _extractPlaceholders(String template) {
  final strippedPlurals = template.replaceAllMapped(
    RegExp(r'\{(\w+)\s*,\s*plural\s*,'),
    (m) => '{${m.group(1)}}',
  );
  final matches = RegExp(r'\{([a-zA-Z0-9_]+)\}').allMatches(strippedPlurals);
  return matches.map((m) => m.group(1)!).toSet();
}

void main() {
  group('ARB Localization Audit (vi / en / ko Parity & Integrity)', () {
    late Map<String, dynamic> viArb;
    late Map<String, dynamic> enArb;
    late Map<String, dynamic> koArb;

    setUpAll(() {
      viArb = _readArbFile('app_vi.arb');
      enArb = _readArbFile('app_en.arb');
      koArb = _readArbFile('app_ko.arb');
    });

    test(
        'All 3 ARB files declare correct @@locale metadata and non-empty key sets',
        () {
      expect(viArb['@@locale'], 'vi');
      expect(enArb['@@locale'], 'en');
      expect(koArb['@@locale'], 'ko');

      final viKeys = _extractMessageKeys(viArb);
      final enKeys = _extractMessageKeys(enArb);
      final koKeys = _extractMessageKeys(koArb);

      expect(viKeys.length, greaterThanOrEqualTo(140));
      expect(enKeys.difference(viKeys), isEmpty,
          reason: 'app_en.arb has extra keys not in app_vi.arb');
      expect(viKeys.difference(enKeys), isEmpty,
          reason: 'app_en.arb is missing keys from app_vi.arb');
      expect(koKeys.difference(viKeys), isEmpty,
          reason: 'app_ko.arb has extra keys not in app_vi.arb');
      expect(viKeys.difference(koKeys), isEmpty,
          reason: 'app_ko.arb is missing keys from app_vi.arb');

      for (final key in viKeys) {
        expect((viArb[key] as String).trim(), isNotEmpty,
            reason: 'vi[$key] must not be empty');
        expect((enArb[key] as String).trim(), isNotEmpty,
            reason: 'en[$key] must not be empty');
        expect((koArb[key] as String).trim(), isNotEmpty,
            reason: 'ko[$key] must not be empty');
      }
    });

    test(
        'Placeholder tokens match across vi, en, and ko for every parameterized key',
        () {
      final keys = _extractMessageKeys(viArb);
      for (final key in keys) {
        final viPlaceholders = _extractPlaceholders(viArb[key] as String);
        final enPlaceholders = _extractPlaceholders(enArb[key] as String);
        final koPlaceholders = _extractPlaceholders(koArb[key] as String);

        expect(
          enPlaceholders,
          equals(viPlaceholders),
          reason: 'Placeholder mismatch between vi and en for key "$key"',
        );
        expect(
          koPlaceholders,
          equals(viPlaceholders),
          reason: 'Placeholder mismatch between vi and ko for key "$key"',
        );
      }
    });

    test(
        'Vietnamese strings have valid UTF-8 diacritics without mojibake or unaccented copy',
        () {
      final keys = _extractMessageKeys(viArb);
      final forbiddenUnaccentedPatterns = <RegExp>[
        RegExp(r'\bChao buoi\b', caseSensitive: false),
        RegExp(r'\bKhong tim thay\b', caseSensitive: false),
        RegExp(r'\bDat phong\b', caseSensitive: false),
        RegExp(r'\bLien he\b', caseSensitive: false),
        RegExp(r'\bKham pha\b', caseSensitive: false),
        RegExp(r'\bYeu thich\b', caseSensitive: false),
        RegExp(r'\bCai dat\b', caseSensitive: false),
      ];

      for (final key in keys) {
        final value = viArb[key] as String;
        expect(
          value.contains('\uFFFD'),
          isFalse,
          reason: 'Replacement character (mojibake) found in vi[$key]: $value',
        );
        for (final pattern in forbiddenUnaccentedPatterns) {
          expect(
            pattern.hasMatch(value),
            isFalse,
            reason: 'Unaccented Vietnamese detected in vi[$key]: $value',
          );
        }
      }
    });

    test(
        'Korean strings contain authentic Hangul glyphs for all translated messages',
        () {
      final keys = _extractMessageKeys(koArb);
      final hangulRegex = RegExp(r'[\uAC00-\uD7AF]');
      const brandOnlyKeys = <String>{'navZalo'};

      for (final key in keys) {
        if (brandOnlyKeys.contains(key)) continue;
        final value = koArb[key] as String;
        expect(
          hangulRegex.hasMatch(value),
          isTrue,
          reason: 'Expected Hangul script in ko[$key], got: "$value"',
        );
      }
    });

    test(
        'Standardized casing for greetings, tab labels, and empty/error/retry copy',
        () {
      final vi = LocaleFormatters.resolveL10n('vi');
      final en = LocaleFormatters.resolveL10n('en');
      final ko = LocaleFormatters.resolveL10n('ko');

      // Greetings must use sentence casing with exclamation mark
      expect(vi.greetingMorning, 'Chào buổi sáng!');
      expect(vi.greetingAfternoon, 'Chào buổi chiều!');
      expect(vi.greetingEvening, 'Chào buổi tối!');
      expect(en.greetingMorning, 'Good morning!');
      expect(en.greetingAfternoon, 'Good afternoon!');
      expect(en.greetingEvening, 'Good evening!');
      expect(ko.greetingMorning, '좋은 아침입니다!');
      expect(ko.greetingAfternoon, '좋은 오후입니다!');
      expect(ko.greetingEvening, '좋은 저녁입니다!');

      // Guest, Host, and Admin tab labels
      expect(vi.navDiscover, 'Khám phá');
      expect(vi.navFavorites, 'Yêu thích');
      expect(vi.navTrips, 'Chuyến đi');
      expect(vi.navAccount, 'Tài khoản');
      expect(vi.navSettings, 'Cài đặt');
      expect(vi.hostTabOverview, 'Tổng quan');
      expect(vi.hostTabProperties, 'Chỗ nghỉ');
      expect(vi.hostTabBookings, 'Đặt phòng');
      expect(vi.hostTabCalendar, 'Lịch lưu trú');
      expect(vi.adminTabOverview, 'Tổng quan');
      expect(vi.adminTabUsers, 'Người dùng');
      expect(vi.adminTabModeration, 'Kiểm duyệt bài đăng');
      expect(vi.adminTabHostApplications, 'Duyệt hồ sơ Host');
      expect(vi.adminTabRoles, 'Phân quyền hệ thống');

      // Empty / Error / Retry
      expect(vi.ctaRetry, 'Thử lại');
      expect(en.ctaRetry, 'Retry');
      expect(ko.ctaRetry, '다시 시도');
      expect(vi.ctaResetFilter, 'Đặt lại bộ lọc');
      expect(vi.errorOfflineTitle, 'Không có kết nối mạng');
      expect(vi.errorServerTitle, 'Lỗi máy chủ');
    });
  });

  group('Pluralization, Currency VND & Locale-Aware Date Formatting', () {
    test(
        'Pluralization for guests, nights, bedrooms, beds, bathrooms, and reviews in vi/en/ko',
        () {
      final vi = LocaleFormatters.resolveL10n('vi');
      final en = LocaleFormatters.resolveL10n('en');
      final ko = LocaleFormatters.resolveL10n('ko');

      // English singular vs plural
      expect(en.nightsCount(1), '1 night');
      expect(en.nightsCount(3), '3 nights');
      expect(en.guestsCount(1), '1 guest');
      expect(en.guestsCount(8), '8 guests');
      expect(en.guestsCapacity(1), '1 guest');
      expect(en.guestsCapacity(15), '15 guests');
      expect(en.bedroomsCount(1), '1 bedroom');
      expect(en.bedroomsCount(5), '5 bedrooms');
      expect(en.bedsCount(1), '1 bed');
      expect(en.bedsCount(7), '7 beds');
      expect(en.bathroomsCount(1), '1 bath');
      expect(en.bathroomsCount(6), '6 baths');
      expect(en.reviewsCount(0), 'No reviews yet');
      expect(en.reviewsCount(1), '1 review');
      expect(en.reviewsCount(24), '24 reviews');
      expect(en.totalNightsWithFee(1), 'Total for 1 night • Fees included');
      expect(en.totalNightsWithFee(4), 'Total for 4 nights • Fees included');

      // Vietnamese
      expect(vi.nightsCount(1), '1 đêm');
      expect(vi.nightsCount(3), '3 đêm');
      expect(vi.guestsCount(1), '1 khách');
      expect(vi.guestsCount(12), '12 khách');
      expect(vi.reviewsCount(0), 'Chưa có đánh giá');
      expect(vi.reviewsCount(24), '24 đánh giá');
      expect(vi.totalNightsWithFee(2), 'Tổng 2 đêm • Đã gồm phí');

      // Korean
      expect(ko.nightsCount(1), '1박');
      expect(ko.nightsCount(3), '3박');
      expect(ko.guestsCount(10), '게스트 10명');
      expect(ko.guestsCapacity(15), '최대 15명');
      expect(ko.bedroomsCount(4), '침실 4개');
      expect(ko.reviewsCount(0), '리뷰 없음');
      expect(ko.reviewsCount(12), '리뷰 12개');
    });

    test(
        'Currency formatter preserves VND (₫) across all locales and localizes fallback',
        () {
      expect(
        LocaleFormatters.formatVnd(3500000, localeCode: 'vi'),
        '3.500.000 ₫',
      );
      expect(
        LocaleFormatters.formatVnd(3500000, localeCode: 'en'),
        '3.500.000 ₫',
      );
      expect(
        LocaleFormatters.formatVnd(3500000, localeCode: 'ko'),
        '3.500.000 ₫',
      );

      // Missing / zero price falls back to localized contactForPrice
      expect(
        LocaleFormatters.formatVnd(null, localeCode: 'vi'),
        'Liên hệ báo giá',
      );
      expect(
        LocaleFormatters.formatVnd(0, localeCode: 'en'),
        'Contact for pricing',
      );
      expect(
        LocaleFormatters.formatVnd(-100, localeCode: 'ko'),
        '가격 문의',
      );

      // Per-night price keeps VND amount while localizing surrounding label
      expect(
        LocaleFormatters.formatPriceFromPerNight(4500000, localeCode: 'vi'),
        'Từ 4.500.000 ₫ / đêm',
      );
      expect(
        LocaleFormatters.formatPriceFromPerNight(4500000, localeCode: 'en'),
        'From 4.500.000 ₫ / night',
      );
      expect(
        LocaleFormatters.formatPriceFromPerNight(4500000, localeCode: 'ko'),
        '1박당 4.500.000 ₫부터',
      );

      // Saturday price
      expect(
        LocaleFormatters.formatSaturdayPrice(6200000, localeCode: 'vi'),
        'Thứ 7: 6.200.000 ₫',
      );
      expect(
        LocaleFormatters.formatSaturdayPrice(6200000, localeCode: 'en'),
        'Sat: 6.200.000 ₫',
      );
      expect(
        LocaleFormatters.formatSaturdayPrice(6200000, localeCode: 'ko'),
        '토요일: 6.200.000 ₫',
      );
      expect(
        LocaleFormatters.formatSaturdayPrice(null, localeCode: 'vi'),
        isNull,
      );
    });

    test(
        'LocaleFormatters formats Asia/Ho_Chi_Minh BookingDate accurately per locale',
        () {
      const checkIn = BookingDate(year: 2026, month: 10, day: 15); // Thursday
      const checkOut = BookingDate(year: 2026, month: 10, day: 17); // Saturday

      expect(
        LocaleFormatters.formatBookingDate(checkIn, localeCode: 'vi'),
        '15/10/2026',
      );
      expect(
        LocaleFormatters.formatBookingDate(checkIn, localeCode: 'en'),
        'Oct 15, 2026',
      );
      expect(
        LocaleFormatters.formatBookingDate(checkIn, localeCode: 'ko'),
        '2026. 10. 15.',
      );

      expect(
        LocaleFormatters.formatNightlyDateWithWeekday(checkIn,
            localeCode: 'vi'),
        '15/10 (T5)',
      );
      expect(
        LocaleFormatters.formatNightlyDateWithWeekday(checkIn,
            localeCode: 'en'),
        '15/10 (Thu)',
      );
      expect(
        LocaleFormatters.formatNightlyDateWithWeekday(checkIn,
            localeCode: 'ko'),
        '10/15 (목)',
      );

      expect(
        LocaleFormatters.formatMonthYear(2026, 10, localeCode: 'vi'),
        'Tháng 10, 2026',
      );
      expect(
        LocaleFormatters.formatMonthYear(2026, 10, localeCode: 'en'),
        'October 2026',
      );
      expect(
        LocaleFormatters.formatMonthYear(2026, 10, localeCode: 'ko'),
        '2026년 10월',
      );

      expect(
        LocaleFormatters.formatStayRange(checkIn, checkOut, localeCode: 'vi'),
        '15/10/2026 – 17/10/2026 (2 đêm)',
      );
      expect(
        LocaleFormatters.formatStayRange(checkIn, checkOut, localeCode: 'en'),
        'Oct 15, 2026 – Oct 17, 2026 (2 nights)',
      );
      expect(
        LocaleFormatters.formatStayRange(checkIn, checkOut, localeCode: 'ko'),
        '2026. 10. 15. – 2026. 10. 17. (2박)',
      );
    });

    test(
        'LocaleFormatters.localizeFailure never misclassifies ServerFailure (5xx) as offline',
        () {
      const networkErr = _StubNetworkFailure();
      const serverErr = _StubServerFailure(
        'Internal Server Error',
        statusCode: 500,
      );
      const authErr = _StubAuthFailure('Expired', 'UNAUTHORIZED', 401);

      for (final lang in ['vi', 'en', 'ko']) {
        final netCopy = LocaleFormatters.localizeFailure(
          networkErr,
          localeCode: lang,
        );
        expect(netCopy.isOffline, isTrue);
        expect(netCopy.isServerError, isFalse);

        final srvCopy = LocaleFormatters.localizeFailure(
          serverErr,
          localeCode: lang,
        );
        expect(srvCopy.isOffline, isFalse);
        expect(srvCopy.isServerError, isTrue);
        expect(srvCopy.statusCode, 500);
        // Must NEVER blame the user's network connection for a 500 server error
        expect(
          srvCopy.message.toLowerCase().contains('kết nối mạng'),
          isFalse,
        );
        expect(
          srvCopy.message.toLowerCase().contains('internet connection'),
          isFalse,
        );

        final authCopy = LocaleFormatters.localizeFailure(
          authErr,
          localeCode: lang,
        );
        expect(authCopy.statusCode, 401);
      }
    });

    test(
        'Domain status & badge localizers preserve business semantics across vi/en/ko',
        () {
      expect(
        LocaleFormatters.localizeVillaBadge(
          VillaBadgeType.saltwater,
          localeCode: 'vi',
        ),
        'Hồ bơi nước mặn',
      );
      expect(
        LocaleFormatters.localizeVillaBadge(
          VillaBadgeType.saltwater,
          localeCode: 'en',
        ),
        'Saltwater Pool',
      );
      expect(
        LocaleFormatters.localizeVillaBadge(
          VillaBadgeType.saltwater,
          localeCode: 'ko',
        ),
        '해수 풀장',
      );

      expect(
        LocaleFormatters.localizeBookingStatus('pending_payment',
            localeCode: 'vi'),
        'Chờ thanh toán',
      );
      expect(
        LocaleFormatters.localizeBookingStatus('pending_payment',
            localeCode: 'en'),
        'Pending payment',
      );
      expect(
        LocaleFormatters.localizeBookingStatus('pending_payment',
            localeCode: 'ko'),
        '결제 대기 중',
      );

      expect(
        LocaleFormatters.localizeHostListingStatus('pending_approval',
            localeCode: 'en'),
        'Pending approval',
      );
      expect(
        LocaleFormatters.localizeAdminUserStatus('suspended', localeCode: 'ko'),
        '정지됨',
      );
    });

    testWidgets(
        'BuildContext.l10n resolves active locale with or without explicit delegate',
        (tester) async {
      late String greetingText;
      late String activeLang;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ko'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              greetingText = LocaleFormatters.greetingForHour(
                8,
                l10n: context.l10n,
              );
              activeLang = context.activeLanguageCode;
              return Text(greetingText);
            },
          ),
        ),
      );

      expect(activeLang, 'ko');
      expect(greetingText, '좋은 아침입니다!');
      expect(find.text('좋은 아침입니다!'), findsOneWidget);
    });
  });
}
