import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/app/theme/app_colors.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';
import 'package:hotel_booking_flutter/features/reviews/domain/entities/review_item.dart';
import 'package:hotel_booking_flutter/features/reviews/domain/repositories/review_repository.dart';
import 'package:hotel_booking_flutter/features/reviews/presentation/widgets/review_list_widget.dart';
import 'package:hotel_booking_flutter/features/villa_detail/presentation/widgets/property_faq_section.dart';
import 'package:hotel_booking_flutter/l10n/l10n.dart';

class _FakeReviewRepository implements ReviewRepository {
  @override
  Future<List<ReviewItem>> getListingReviews(
    String listingId, {
    int? page,
    int? limit,
    int? rating,
  }) async {
    return const [];
  }

  @override
  Future<ReviewItem> createReview({
    required String bookingId,
    required int rating,
    required String comment,
  }) =>
      throw UnimplementedError();
}

void main() {
  group('ReviewItem Domain Tests', () {
    test('ReviewItem.fromJson correctly parses review and host reply payload',
        () {
      final json = {
        'reviewId': 55,
        'rating': 5,
        'comment': 'Villa rất đẹp, hồ bơi nước mặn sạch sẽ và gần biển.',
        'reviewerName': 'Hoang Nam',
        'reviewerAvatar': 'https://example.com/avatar.jpg',
        'hostReply': 'Cảm ơn bạn đã lựa chọn The Palm Villa!',
        'createdAt': '2026-10-05T10:00:00.000Z',
      };

      final review = ReviewItem.fromJson(json);

      expect(review.id, '55');
      expect(review.rating, 5.0);
      expect(review.comment,
          'Villa rất đẹp, hồ bơi nước mặn sạch sẽ và gần biển.');
      expect(review.reviewerName, 'Hoang Nam');
      expect(review.reviewerAvatar, 'https://example.com/avatar.jpg');
      expect(review.hostReply, 'Cảm ơn bạn đã lựa chọn The Palm Villa!');
      expect(review.createdAt, isNotNull);
    });
  });

  group('ReviewListWidget Rating Filter Chip Styling', () {
    testWidgets(
        'renders rating filter chips with white background and semantic border colors without black fill',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reviewRepositoryProvider.overrideWithValue(_FakeReviewRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            locale: const Locale('vi'),
            supportedLocales: const [Locale('vi'), Locale('en'), Locale('ko')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Scaffold(
              body: ReviewListWidget(
                listingId: '101',
                averageRating: 5.0,
                totalReviews: 2,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final allChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Tất cả'),
      );
      final fiveStarChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, '5 sao'),
      );

      expect(allChip.selected, isTrue);
      expect(allChip.selectedColor, AppColors.primary);
      expect(allChip.backgroundColor, AppColors.surfaceBase);
      expect(allChip.side?.color, AppColors.primary);

      expect(fiveStarChip.selected, isFalse);
      expect(fiveStarChip.backgroundColor, AppColors.surfaceBase);
      expect(fiveStarChip.side?.color, AppColors.border);

      await tester.tap(find.widgetWithText(ChoiceChip, '5 sao'));
      await tester.pumpAndSettle();

      final updatedFiveStarChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, '5 sao'),
      );
      expect(updatedFiveStarChip.selected, isTrue);
      expect(updatedFiveStarChip.selectedColor, AppColors.primary);
      expect(updatedFiveStarChip.side?.color, AppColors.primary);
    });

    testWidgets('allows translating review comments and host replies and toggling back to original', (tester) async {
      final reviews = [
        ReviewItem(
          id: 'rev-1',
          rating: 5.0,
          comment: 'Không gian rộng rãi, tiện nghi cao cấp, phòng ốc thơm tho sạch sẽ. 10/10 điểm!',
          reviewerName: 'Nguyen Van A',
          reviewerAvatar: null,
          hostReply: 'Cảm ơn bạn Long và đoàn đã ghé thăm, rất hân hạnh được đón tiếp bạn lần sau nhé!',
          createdAt: DateTime(2026, 10, 27),
        ),
      ];

      final repo = _StaticReviewRepository(reviews);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reviewRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            locale: const Locale('en'),
            supportedLocales: const [Locale('en'), Locale('vi'), Locale('ko')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Scaffold(
              body: SingleChildScrollView(
                child: ReviewListWidget(
                  listingId: '101',
                  averageRating: 5.0,
                  totalReviews: 1,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In English locale, chip says 'All' and '5 stars'
      expect(find.text('All'), findsOneWidget);
      expect(find.text('5 stars'), findsOneWidget);

      // Initial state: original Vietnamese comment is visible
      expect(find.textContaining('Không gian rộng rãi'), findsOneWidget);
      expect(find.text('Translate review'), findsOneWidget);

      // Tap Translate review
      await tester.tap(find.text('Translate review'));
      await tester.pumpAndSettle();

      // Shows translated text and badge
      expect(find.text('Show original'), findsOneWidget);
      expect(find.text('(Automatically translated)'), findsOneWidget);
      expect(find.textContaining('Spacious'), findsOneWidget);

      // Tap Show original to revert
      await tester.tap(find.text('Show original'));
      await tester.pumpAndSettle();

      expect(find.text('Translate review'), findsOneWidget);
      expect(find.textContaining('Không gian rộng rãi'), findsOneWidget);
    });

    testWidgets('PropertyFaqSection dynamically localizes in Vietnamese, English, and Korean', (tester) async {
      Widget buildFaqApp(Locale locale) {
        return MaterialApp(
          theme: AppTheme.lightTheme,
          locale: locale,
          supportedLocales: const [Locale('vi'), Locale('en'), Locale('ko')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(
            body: SingleChildScrollView(
              child: PropertyFaqSection(),
            ),
          ),
        );
      }

      // 1. Vietnamese
      await tester.pumpWidget(buildFaqApp(const Locale('vi')));
      await tester.pumpAndSettle();
      expect(find.text('Quy định & Câu hỏi thường gặp'), findsOneWidget);
      expect(find.text('Thời gian nhận và trả villa như thế nào?'), findsOneWidget);
      expect(find.text('Quy định về tiếng ồn và sử dụng karaoke?'), findsOneWidget);

      // 2. English
      await tester.pumpWidget(buildFaqApp(const Locale('en')));
      await tester.pumpAndSettle();
      expect(find.text('House Rules & FAQ'), findsOneWidget);
      expect(find.text('What are the check-in and check-out times?'), findsOneWidget);
      expect(find.text('What are the noise and karaoke regulations?'), findsOneWidget);

      // 3. Korean
      await tester.pumpWidget(buildFaqApp(const Locale('ko')));
      await tester.pumpAndSettle();
      expect(find.text('이용 수칙 및 자주 묻는 질문'), findsOneWidget);
      expect(find.text('체크인 및 체크아웃 시간은 어떻게 되나요?'), findsOneWidget);
      expect(find.text('소음 및 노래방 이용 규정은 어떻게 되나요?'), findsOneWidget);
    });
  });
}

class _StaticReviewRepository implements ReviewRepository {
  final List<ReviewItem> items;
  _StaticReviewRepository(this.items);

  @override
  Future<List<ReviewItem>> getListingReviews(
    String listingId, {
    int? page,
    int? limit,
    int? rating,
  }) async {
    return items;
  }

  @override
  Future<ReviewItem> createReview({
    required String bookingId,
    required int rating,
    required String comment,
  }) =>
      throw UnimplementedError();
}
