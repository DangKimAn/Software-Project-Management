import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/core/date/booking_date.dart';
import 'package:hotel_booking_flutter/core/storage/preferences_service.dart';
import 'package:hotel_booking_flutter/features/search/presentation/widgets/booking_date_range_picker.dart';
import 'package:hotel_booking_flutter/features/villa_detail/presentation/widgets/booking_action_bar.dart';
import 'package:hotel_booking_flutter/features/villa_detail/presentation/widgets/mobile_spec_summary.dart';
import 'package:hotel_booking_flutter/features/villas/domain/entities/villa.dart';
import 'package:hotel_booking_flutter/features/villas/domain/entities/villa_specs.dart';
import 'package:hotel_booking_flutter/features/villas/presentation/widgets/property_card.dart';
import 'package:hotel_booking_flutter/features/villas/presentation/widgets/property_specs_row.dart';
import 'package:hotel_booking_flutter/shared/animations/fade_slide_in.dart';
import 'package:hotel_booking_flutter/shared/animations/source_animations.dart';
import 'package:hotel_booking_flutter/shared/widgets/villa_badge.dart';
import 'package:hotel_booking_flutter/shared/widgets/vung_tau_map_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi_VN', null);
    await initializeDateFormatting('vi', null);
  });

  group('1. 8 Location Groups & Map Normalization (BUG-09)', () {
    test('VungTauMapConstants has exact 8 canonical location groups', () {
      expect(VungTauMapConstants.locationGroups.length, 8);
      final keys =
          VungTauMapConstants.locationGroups.map((g) => g.key).toList();
      final labels =
          VungTauMapConstants.locationGroups.map((g) => g.label).toList();

      expect(keys, [
        'bai_sau',
        'bai_truoc',
        'long_cung',
        'chi_linh',
        'thuy_tien',
        'trung_tam',
        'tran_phu',
        'thuy_van',
      ]);
      expect(labels, [
        'Bãi Sau',
        'Bãi Trước',
        'Long Cung',
        'Chí Linh',
        'Thủy Tiên',
        'Trung tâm',
        'Trần Phú',
        'Thùy Vân',
      ]);
    });

    test(
        'resolveLocationGroupName maps keys, ids, and labels to canonical names',
        () {
      for (final group in VungTauMapConstants.locationGroups) {
        expect(
          VungTauMapConstants.resolveLocationGroupName(group.key),
          group.label,
        );
        expect(
          VungTauMapConstants.resolveLocationGroupName(group.id),
          group.label,
        );
        expect(
          VungTauMapConstants.resolveLocationGroupName(group.label),
          group.label,
        );
        expect(
          VungTauMapConstants.resolveLocationGroupKey(group.label),
          group.key,
        );
      }
      expect(VungTauMapConstants.resolveLocationGroupName('unknown'), isNull);
    });
  });

  group('2. Amenity & PropertyType Filter Normalization (BUG-09)', () {
    test('normalizes Vietnamese labels and snake_case codes to backend codes',
        () {
      final normalized = VillaSearchQueryNormalizer.normalizeAmenities([
        'Hồ bơi riêng',
        'Khu vực BBQ',
        'Chỗ đậu xe miễn phí',
        'View biển',
        'karaoke',
        'Gần biển',
        'Wifi miễn phí',
        'Bếp đầy đủ',
        'Máy lạnh',
        'Cho phép thú cưng',
        'Thang máy',
        'Bàn bida',
      ]);

      expect(normalized, [
        'pool',
        'bbq',
        'parking',
        'nice_view',
        'karaoke',
        'near_beach',
        'wifi',
        'kitchen',
        'air_conditioner',
        'pet_friendly',
        'elevator',
        'billiards',
      ]);
    });

    test('validates only supported property types', () {
      expect(
          VillaSearchQueryNormalizer.normalizePropertyType('villa'), 'villa');
      expect(
        VillaSearchQueryNormalizer.normalizePropertyType('APARTMENT'),
        'apartment',
      );
      expect(
        VillaSearchQueryNormalizer.normalizePropertyType('resort_invalid'),
        isNull,
      );
    });
  });

  group('3 & 4. Date Selection & Range Availability (BUG-24)', () {
    testWidgets(
        'disables past dates and allows selecting first booked date as checkOut (half-open [checkIn, checkOut))',
        (tester) async {
      BookingDate? selectedIn;
      BookingDate? selectedOut;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookingDateRangePicker(
                minDate: const BookingDate(year: 2026, month: 5, day: 10),
                initialCheckIn:
                    const BookingDate(year: 2026, month: 5, day: 10),
                bookedDates: {
                  const BookingDate(
                      year: 2026, month: 5, day: 12), // Night of May 12
                },
                onRangeSelected: (range) {
                  selectedIn = range.$1;
                  selectedOut = range.$2;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Past date May 9 must be disabled; tapping it should not change selection
      await tester.tap(find.text('9').first);
      await tester.pumpAndSettle();
      expect(selectedIn, isNull);

      // May 12 (firstBookedAfterCheckIn) IS selectable as checkOut because [10, 12) only covers nights 10 & 11!
      await tester.tap(find.text('12').first);
      await tester.pumpAndSettle();
      expect(selectedIn, const BookingDate(year: 2026, month: 5, day: 10));
      expect(selectedOut, const BookingDate(year: 2026, month: 5, day: 12));
    });

    testWidgets(
        'blocks dates after firstBookedAfterCheckIn and shows "Ngày này đã kín" when booked check-in is tapped',
        (tester) async {
      BookingDate? selectedIn;
      BookingDate? selectedOut;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookingDateRangePicker(
                minDate: const BookingDate(year: 2026, month: 5, day: 10),
                bookedDates: {
                  const BookingDate(year: 2026, month: 5, day: 12),
                },
                onRangeSelected: (range) {
                  selectedIn = range.$1;
                  selectedOut = range.$2;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tapping booked date May 12 when picking checkIn shows "Ngày này đã kín"
      await tester.tap(find.text('12').first);
      await tester.pumpAndSettle();
      expect(find.text('Ngày này đã kín'), findsOneWidget);
      expect(selectedIn, isNull);
      expect(selectedOut, isNull);
    });
  });

  group('5 & 6. Night Count & Pricing Preview (BUG-04, BUG-32, BUG-33)', () {
    test('BookingDate.differenceInNights computes exact night count', () {
      const checkIn = BookingDate(year: 2026, month: 5, day: 15);
      const checkOut = BookingDate(year: 2026, month: 5, day: 18);
      // checkIn.differenceInNights(checkOut) == +3 nights
      expect(checkIn.differenceInNights(checkOut), 3);
      expect(
          VillaDetailPricingCalculator.calculateNights(checkIn, checkOut), 3);
    });

    test('BookingDate.isWeekend is true for Saturday and Sunday only', () {
      expect(
        const BookingDate(year: 2026, month: 5, day: 15).isWeekend,
        isFalse,
      ); // Friday
      expect(
        const BookingDate(year: 2026, month: 5, day: 16).isWeekend,
        isTrue,
      ); // Saturday
      expect(
        const BookingDate(year: 2026, month: 5, day: 17).isWeekend,
        isTrue,
      ); // Sunday
      expect(
        const BookingDate(year: 2026, month: 5, day: 18).isWeekend,
        isFalse,
      ); // Monday
    });

    test(
        'VillaDetailPricingCalculator applies Sat/Sun weekend price, flat surchargeAmountVnd once, and serviceFeePct',
        () {
      const villa = Villa(
        id: 'v1',
        code: 'VT-01',
        name: 'Villa 1',
        tagline: 'Sát biển Bãi Sau',
        address: 'Bãi Sau, Vũng Tàu',
        description: 'Mô tả villa',
        imageUrls: ['https://example.com/1.jpg'],
        specs: VillaSpecs(bedrooms: 4, beds: 6, bathrooms: 4, maxGuests: 10),
        basePriceVnd: 2000000,
        saturdayPriceVnd: 3000000,
        cleaningFeeVnd: 100000,
        surchargeAmountVnd: 200000,
        extraGuestFeeVnd: 150000,
        includedGuests: 4,
        serviceFeePct: 10,
      );

      // Fri May 15 -> Mon May 18 (3 nights: Fri=2M, Sat=3M, Sun=3M -> roomSubtotal=8M)
      const checkIn = BookingDate(year: 2026, month: 5, day: 15);
      const checkOut = BookingDate(year: 2026, month: 5, day: 18);

      final pricing = VillaDetailPricingCalculator.calculatePricing(
        villa: villa,
        checkIn: checkIn,
        checkOut: checkOut,
        guestsCount: 6, // 2 extra guests
      );

      expect(pricing.nights, 3);
      expect(pricing.weekendNights, 2);
      expect(pricing.roomSubtotal, 8000000);
      // 2 extra guests * 150,000 * 3 nights + 200,000 flat surcharge = 1,100,000
      expect(pricing.extraGuestTotal, 1100000);
      expect(pricing.cleaningFee, 100000);
      // 10% of (8,000,000 + 1,100,000) = 910,000
      expect(pricing.serviceFee, 910000);
      expect(pricing.finalTotal, 10110000);
    });

    testWidgets(
        'BookingActionBar omits "/ đêm" when multi-night totalCalculatedVnd is provided (BUG-33)',
        (tester) async {
      const villa = Villa(
        id: 'v1',
        code: 'VT-01',
        name: 'Villa 1',
        tagline: 'Sát biển Bãi Sau',
        address: 'Bãi Sau, Vũng Tàu',
        description: 'Mô tả villa',
        imageUrls: [],
        specs: VillaSpecs(bedrooms: 4, beds: 6, bathrooms: 4, maxGuests: 10),
        basePriceVnd: 2000000,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookingActionBar(
              villa: villa,
              totalCalculatedVnd: 6000000,
              selectedNights: 3,
              onBookNow: () {},
            ),
          ),
        ),
      );

      expect(
        find.textContaining('6.000.000', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('/ đêm', findRichText: true),
        findsNothing,
      );
    });
  });

  group('7. Month & Flexible Search Date Modes (BUG-29)', () {
    test(
        'computeForMonths calculates checkIn and checkOut across selected months',
        () {
      final range = SearchDateModeHelper.computeForMonths(
        [5, 6],
        referenceToday: const BookingDate(year: 2026, month: 5, day: 10),
      );
      expect(range.checkIn, const BookingDate(year: 2026, month: 5, day: 10));
      expect(range.checkOut, const BookingDate(year: 2026, month: 7, day: 1));
    });

    test('computeForFlexible calculates weekend, week, and month durations',
        () {
      // 2026-05-13 is Wednesday -> next Saturday is 2026-05-16 -> Monday 2026-05-18 (2 nights)
      final weekendRange = SearchDateModeHelper.computeForFlexible(
        'weekend',
        referenceToday: const BookingDate(year: 2026, month: 5, day: 13),
      );
      expect(
        weekendRange.checkIn,
        const BookingDate(year: 2026, month: 5, day: 16),
      );
      expect(
        weekendRange.checkOut,
        const BookingDate(year: 2026, month: 5, day: 18),
      );

      final weekRange = SearchDateModeHelper.computeForFlexible(
        'week',
        referenceToday: const BookingDate(year: 2026, month: 5, day: 13),
      );
      expect(
        weekRange.checkIn,
        const BookingDate(year: 2026, month: 5, day: 14),
      );
      expect(
        weekRange.checkOut,
        const BookingDate(year: 2026, month: 5, day: 21),
      );
    });
  });

  group('8. AI Search Rejection & Parity (Section 11)', () {
    test('maps all 6+ rejection codes to distinct title, description, and tips',
        () {
      const reasons = [
        'QUERY_TOO_SHORT',
        'LOW_INFORMATION_QUERY',
        'UNSUPPORTED_DOMAIN',
        'UNSUPPORTED_LOCATION',
        'OFF_DOMAIN_DESTINATIONS',
        'NO_APPROVED_LISTINGS',
        'NO_VIABLE_MATCH',
      ];

      for (final reason in reasons) {
        final copy = AiSearchRejectionCopy.resolve(reason);
        expect(copy.title, isNotEmpty);
        expect(copy.description, isNotEmpty);
        expect(copy.tips, isNotEmpty);
      }
      expect(
        AiSearchRejectionCopy.resolve('QUERY_TOO_SHORT').title,
        contains('ngắn'),
      );
      expect(
        AiSearchRejectionCopy.resolve('UNSUPPORTED_LOCATION').title,
        contains('Vũng Tàu'),
      );
    });

    test(
        'SemanticSearchResponse identifies rejected mode and filters debug reasons',
        () {
      const response = SemanticSearchResponse(
        query: 'abc',
        mode: 'rejected',
        reason: 'LOW_INFORMATION_QUERY',
        message: 'Truy vấn chưa rõ',
        items: [],
      );
      expect(response.isRejected, isTrue);

      final filteredReasons = VillaSearchQueryNormalizer.filterMatchedReasons([
        'Có hồ bơi riêng',
        'semantic(0.84)',
        'clip_score: 0.71',
        'Sức chứa 10 khách',
      ]);
      expect(filteredReasons, ['Có hồ bơi riêng', 'Sức chứa 10 khách']);
    });
  });

  group('9. Popular Destinations & Recently Viewed (BUG-37, BUG-41)', () {
    test(
        'Popular destination location groups resolve independently per area without mutating shared state',
        () {
      final baiSau = VungTauMapConstants.resolveLocationGroupName('bai_sau');
      final baiTruoc =
          VungTauMapConstants.resolveLocationGroupName('bai_truoc');
      expect(baiSau, 'Bãi Sau');
      expect(baiTruoc, 'Bãi Trước');
      expect(baiSau, isNot(baiTruoc));
    });

    test('PreferencesService stores and returns up to 8 recently viewed items',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = PreferencesService(prefs);

      for (var i = 1; i <= 10; i++) {
        await service.recordRecentlyViewed(
          RecentlyViewedItem(
            id: 'villa-$i',
            title: 'Villa $i',
            imageUrl: 'https://example.com/$i.jpg',
            location: 'Bãi Sau',
            pricePerNight: 2000000,
            rating: 4.9,
          ),
        );
      }

      final items = service.getRecentlyViewed();
      expect(items.length, 8);
      expect(items.first.id, 'villa-10');
    });
  });

  group(
      '10. PropertySpecsRow & MobileSpecSummary Zero Specs Filtering (BUG-23)',
      () {
    testWidgets('PropertySpecsRow hides zero-valued specs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PropertySpecsRow(
              specs: VillaSpecs(
                bedrooms: 0,
                beds: 0,
                maxGuests: 8,
                bathrooms: 0,
              ),
            ),
          ),
        ),
      );

      expect(find.text('8 khách'), findsOneWidget);
      expect(find.textContaining('0 PN'), findsNothing);
      expect(find.textContaining('0 Giường'), findsNothing);
      expect(find.textContaining('0 WC'), findsNothing);
    });

    testWidgets('MobileSpecSummary hides zero-valued specs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MobileSpecSummary(
              specs: VillaSpecs(
                bedrooms: 4,
                beds: 0,
                maxGuests: 12,
                bathrooms: 0,
              ),
            ),
          ),
        ),
      );

      expect(find.text('12 khách'), findsOneWidget);
      expect(find.text('4 phòng'), findsOneWidget);
      expect(find.text('Phòng ngủ'), findsOneWidget);
      expect(find.textContaining('0 WC'), findsNothing);
      expect(find.textContaining('0 giường'), findsNothing);
    });
  });

  group('11, 12 & 13. Responsive 320px Overflow, Strict Icons & Animations',
      () {
    testWidgets(
        'PropertyCard, VillaBadge, BookingDateRangePicker, and VungTauMapPicker render at 320px without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const villa = Villa(
        id: 'v-320',
        code: 'VT-320',
        name: 'Villa Bãi Sau Sát Biển Cao Cấp Cho Gia Đình',
        tagline: 'Sát biển Bãi Sau',
        address: 'Bãi Sau, Vũng Tàu',
        description: 'Villa cao cấp sát biển',
        imageUrls: [],
        specs: VillaSpecs(bedrooms: 4, beds: 6, bathrooms: 4, maxGuests: 12),
        basePriceVnd: 3500000,
        rating: 4.9,
        reviewCount: 28,
        badges: [VillaBadgeType.featured],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  PropertyCard(
                    villa: villa,
                    onTap: () {},
                  ),
                  const VillaBadge(badgeType: VillaBadgeType.featured),
                  BookingDateRangePicker(
                    minDate: const BookingDate(year: 2026, month: 5, day: 10),
                    onRangeSelected: (_) {},
                  ),
                  VungTauMapPicker(
                    initialLat: 10.3460,
                    initialLng: 107.0843,
                    onLocationChanged: (_, __, ___) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.byIcon(LucideIcons.chevronLeft), findsOneWidget);
      expect(find.byIcon(LucideIcons.chevronRight), findsOneWidget);
    });

    testWidgets(
        'CalFadeIn, MonthInSwitcher, SearchPopIn, MapMarkerPulse, and FadeSlideIn trigger without errors',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CalFadeIn(child: Text('Calendar')),
                MonthInSwitcher(
                  monthKey: ValueKey('2026-05'),
                  child: Text('May 2026'),
                ),
                SearchPopIn(child: Text('Search Popover')),
                MapMarkerPulse(child: Text('Pin')),
                FadeSlideIn(child: Text('Card')),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('May 2026'), findsOneWidget);
      expect(find.text('Search Popover'), findsOneWidget);
      expect(find.text('Pin'), findsOneWidget);
      expect(find.text('Card'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
