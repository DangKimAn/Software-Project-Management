import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/core/date/booking_date.dart';
import 'package:hotel_booking_flutter/features/search/presentation/widgets/booking_date_range_picker.dart';
import 'package:hotel_booking_flutter/l10n/l10n.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi', null);
    await initializeDateFormatting('en', null);
    await initializeDateFormatting('ko', null);
  });

  Widget buildCalendarApp(Locale locale, {DateTime? initialDate}) {
    final seed = initialDate != null
        ? BookingDate(year: initialDate.year, month: initialDate.month, day: initialDate.day)
        : const BookingDate(year: 2026, month: 11, day: 10);
    return MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: SingleChildScrollView(
          child: BookingDateRangePicker(
            initialCheckIn: seed,
            onRangeSelected: (_) {},
          ),
        ),
      ),
    );
  }

  group('Calendar Localization across vi, en, ko', () {
    testWidgets('renders Vietnamese calendar header and weekdays for vi locale', (tester) async {
      await tester.pumpWidget(buildCalendarApp(const Locale('vi')));
      await tester.pumpAndSettle();

      expect(find.text('THÁNG 11 2026'), findsOneWidget);
      expect(find.text('T2'), findsOneWidget);
      expect(find.text('T3'), findsOneWidget);
      expect(find.text('T4'), findsOneWidget);
      expect(find.text('T5'), findsOneWidget);
      expect(find.text('T6'), findsOneWidget);
      expect(find.text('T7'), findsOneWidget);
      expect(find.text('CN'), findsOneWidget);
    });

    testWidgets('renders English calendar header and weekdays for en locale', (tester) async {
      await tester.pumpWidget(buildCalendarApp(const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('NOVEMBER 2026'), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
    });

    testWidgets('renders Korean calendar header and weekdays for ko locale', (tester) async {
      await tester.pumpWidget(buildCalendarApp(const Locale('ko')));
      await tester.pumpAndSettle();

      expect(find.text('2026년 11월'), findsOneWidget);
      expect(find.text('월'), findsOneWidget);
      expect(find.text('화'), findsOneWidget);
      expect(find.text('수'), findsOneWidget);
      expect(find.text('목'), findsOneWidget);
      expect(find.text('금'), findsOneWidget);
      expect(find.text('토'), findsOneWidget);
      expect(find.text('일'), findsOneWidget);
    });
  });
}
