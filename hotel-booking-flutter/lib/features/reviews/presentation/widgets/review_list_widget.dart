import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../data/repositories/review_repository_impl.dart';
import '../../domain/entities/review_item.dart';
import '../../domain/repositories/review_repository.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  final client = ref.watch(dioClientProvider);
  return ReviewRepositoryImpl(client);
});

final listingReviewsProvider = FutureProvider.autoDispose
    .family<List<ReviewItem>, String>((ref, listingId) async {
  final repo = ref.watch(reviewRepositoryProvider);
  return repo.getListingReviews(listingId);
});

class ReviewListWidget extends ConsumerWidget {
  final String listingId;
  final double averageRating;
  final int totalReviews;

  const ReviewListWidget({
    super.key,
    required this.listingId,
    required this.averageRating,
    required this.totalReviews,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(listingReviewsProvider(listingId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.star, size: 22, color: AppColors.starAmber),
            const SizedBox(width: AppSpacing.s8),
            Text(
              averageRating.toStringAsFixed(1),
              style: AppTypography.sectionHeading
                  .copyWith(color: AppColors.textStrong),
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              '($totalReviews đánh giá)',
              style: AppTypography.body.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        reviewsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.s16),
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2.5),
            ),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
            child: Text(
              'Không thể tải đánh giá vào lúc này.',
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
          ),
          data: (reviews) {
            if (reviews.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                child: Text(
                  'Chưa có đánh giá nào cho villa này. Hãy là vị khách đầu tiên trải nghiệm!',
                  style: AppTypography.body.copyWith(
                      color: AppColors.textMuted, fontStyle: FontStyle.italic),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reviews.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: AppSpacing.s24),
              itemBuilder: (context, index) {
                final review = reviews[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.brandSoft,
                          backgroundImage: review.reviewerAvatar != null &&
                                  review.reviewerAvatar!.isNotEmpty
                              ? NetworkImage(review.reviewerAvatar!)
                              : null,
                          child: review.reviewerAvatar == null ||
                                  review.reviewerAvatar!.isEmpty
                              ? Text(
                                  review.reviewerName.isNotEmpty
                                      ? review.reviewerName[0].toUpperCase()
                                      : 'K',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                review.reviewerName,
                                style: AppTypography.body
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                              if (review.createdAt != null)
                                Text(
                                  DateFormat('dd/MM/yyyy')
                                      .format(review.createdAt!),
                                  style: AppTypography.caption
                                      .copyWith(color: AppColors.textMuted),
                                ),
                            ],
                          ),
                        ),
                        Row(
                          children: List.generate(
                            5,
                            (starIndex) => Icon(
                              LucideIcons.star,
                              size: 14,
                              color: starIndex < review.rating.round()
                                  ? AppColors.starAmber
                                  : AppColors.borderStrong,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      review.comment,
                      style: AppTypography.body
                          .copyWith(color: AppColors.textStrong),
                    ),
                    if (review.hostReply != null &&
                        review.hostReply!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s8),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.s12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderSoft),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(LucideIcons.messageSquare,
                                    size: 14, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'Phản hồi từ chủ nhà',
                                  style: AppTypography.caption.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              review.hostReply!,
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textStrong),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}
