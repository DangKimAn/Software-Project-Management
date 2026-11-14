import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_semantic_icons.dart';
import '../view_models/review_view_model.dart';

export '../view_models/review_view_model.dart';

/// Danh sách hiển thị điểm trung bình, bộ lọc theo hạng sao (`1..5`) và các nhận xét của khách lưu trú.
///
/// Giải thuật mở rộng cửa sổ hiển thị tăng dần kết hợp nạp trang máy chủ:
/// - Tính số trang API cần nạp `requiredPages = ceil(_visibleLimit / 20)` kẹp trong đoạn `[1, 50]`.
/// - Mỗi lần nhấn `Xem thêm đánh giá` tăng `_visibleLimit` thêm `6` mục và tự động nạp trang kế tiếp khi chạm ngưỡng dữ liệu đã tải.
class ReviewListWidget extends ConsumerStatefulWidget {
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
  ConsumerState<ReviewListWidget> createState() => _ReviewListWidgetState();
}

class _ReviewListWidgetState extends ConsumerState<ReviewListWidget> {
  static const int _pageSize = 6;
  static const int _apiPageLimit = 20;
  int? _selectedRating;
  int _visibleLimit = _pageSize;

  @override
  Widget build(BuildContext context) {
    final requiredPages =
        ((_visibleLimit + _apiPageLimit - 1) ~/ _apiPageLimit).clamp(1, 50);
    final query = (
      listingId: widget.listingId,
      rating: _selectedRating,
      pageCount: requiredPages,
    );
    final reviewsAsync = ref.watch(listingReviewsQueryProvider(query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.star,
                  size: 20,
                  color: AppColors.iconStrong,
                ),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  widget.averageRating.toStringAsFixed(1),
                  style: AppTypography.sectionHeading.copyWith(
                    fontSize: 19,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            Text(
              '· ${widget.totalReviews} đánh giá',
              style: AppTypography.bodyLarge.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        // Star rating filter chips (BUG-42)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildRatingFilterChip(label: 'Tất cả', ratingValue: null),
              for (final star in [5, 4, 3, 2, 1]) ...[
                const SizedBox(width: 8),
                _buildRatingFilterChip(
                  label: '$star sao',
                  ratingValue: star,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s20),
        reviewsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.s16),
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
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
                  _selectedRating != null
                      ? 'Chưa có đánh giá $_selectedRating sao nào cho chỗ nghỉ này.'
                      : 'Chưa có đánh giá nào cho villa này. Hãy là vị khách đầu tiên trải nghiệm!',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            }

            final visibleReviews = reviews.take(_visibleLimit).toList();
            final hasMoreLoaded = reviews.length > visibleReviews.length;
            final canFetchNextServerPage =
                reviews.length >= requiredPages * _apiPageLimit &&
                    (_selectedRating != null ||
                        reviews.length < widget.totalReviews);
            final hasMore = hasMoreLoaded || canFetchNextServerPage;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visibleReviews.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.s24),
                  itemBuilder: (context, index) {
                    final review = visibleReviews[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(
                              AppSemanticIcons.userProfile,
                              size: 28,
                              color: AppColors.iconStrong,
                            ),
                            const SizedBox(width: AppSpacing.s12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    review.reviewerName,
                                    style: AppTypography.bodyLarge.copyWith(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textStrong,
                                    ),
                                  ),
                                  if (review.createdAt != null)
                                    Text(
                                      DateFormat('dd/MM/yyyy')
                                          .format(review.createdAt!),
                                      style: AppTypography.caption.copyWith(
                                        fontSize: 12.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.star,
                                  size: 14,
                                  color: AppColors.iconStrong,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  review.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        Text(
                          review.comment,
                          style: AppTypography.bodyLarge.copyWith(
                            fontSize: 15,
                            height: 1.48,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (review.hostReply != null &&
                            review.hostReply!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.s12),
                          Container(
                            margin: const EdgeInsets.only(left: AppSpacing.s4),
                            padding: const EdgeInsets.only(
                              left: AppSpacing.s12,
                              top: 2,
                              bottom: 2,
                            ),
                            decoration: const BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: AppColors.border,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Phản hồi từ chủ nhà',
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textStrong,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  review.hostReply!,
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontSize: 13.5,
                                    height: 1.45,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                if (hasMore) ...[
                  const SizedBox(height: AppSpacing.s16),
                  Center(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _visibleLimit += _pageSize;
                        });
                      },
                      child: const Text('Xem thêm đánh giá'),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildRatingFilterChip({
    required String label,
    required int? ratingValue,
  }) {
    final isSelected = _selectedRating == ratingValue;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceBase,
      surfaceTintColor: Colors.transparent,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.border,
        width: isSelected ? 1.5 : 1.0,
      ),
      showCheckmark: false,
      onSelected: (_) {
        setState(() {
          _selectedRating = ratingValue;
          _visibleLimit = _pageSize;
        });
      },
    );
  }
}
