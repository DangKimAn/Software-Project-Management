import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/app/theme/app_colors.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';
import 'package:hotel_booking_flutter/features/reviews/domain/entities/review_item.dart';
import 'package:hotel_booking_flutter/features/reviews/domain/repositories/review_repository.dart';
import 'package:hotel_booking_flutter/features/reviews/presentation/widgets/review_list_widget.dart';

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
      expect(allChip.selectedColor, AppColors.surfaceBase);
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
      expect(updatedFiveStarChip.selectedColor, AppColors.surfaceBase);
      expect(updatedFiveStarChip.side?.color, AppColors.primary);
    });
  });
}
