import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/features/reviews/domain/entities/review_item.dart';

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
}
