import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_header_footer.dart';
import '../../../../shared/widgets/app_image.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../auth/presentation/view_models/auth_notifier.dart';
import '../../../reviews/presentation/widgets/review_list_widget.dart';
import '../../domain/entities/booking.dart';
import '../view_models/trips_view_model.dart';

/// Complete port of `Source goc/frontend/src/views/pages/Trips/index.tsx` (`TripHistoryList`, `TripHistoryCard`, `ReviewModal`).
class TripsScreen extends ConsumerStatefulWidget {
  const TripsScreen({super.key});

  @override
  ConsumerState<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends ConsumerState<TripsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Set<String> _expandedBookingIds = {};
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // 60-second automatic refresh matching Source goc Trips/index.tsx
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) {
        ref.invalidate(myBookingsProvider);
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  String _formatHoldCountdown(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _handleCancelBooking(Booking booking) async {
    if (!booking.canCancel) return;

    final locale = ref.read(localeProvider);
    final isEn = locale.startsWith('en');
    final isKo = locale.startsWith('ko');

    final reasonController = TextEditingController();
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEn ? 'Cancel booking' : (isKo ? '예약 취소' : 'Hủy đặt phòng')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEn
                    ? 'Are you sure you want to cancel your booking at "${booking.propertyName}"?'
                    : (isKo
                        ? '"${booking.propertyName}" 예약을 취소하시겠습니까?'
                        : 'Bạn có chắc chắn muốn hủy đặt phòng tại "${booking.propertyName}"?'),
                style: AppTypography.body,
              ),
              const SizedBox(height: AppSpacing.s16),
              TextField(
                controller: reasonController,
                maxLines: 1,
                style: const TextStyle(fontSize: 13, height: 1.2),
                decoration: InputDecoration(
                  labelText: isEn
                      ? 'Cancellation reason (required)'
                      : (isKo ? '취소 사유 (필수)' : 'Lý do hủy (bắt buộc)'),
                  hintText: isEn
                      ? 'Change of personal plans...'
                      : (isKo ? '개인 일정 변경...' : 'Thay đổi kế hoạch cá nhân...'),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isEn ? 'Keep booking' : (isKo ? '예약 유지' : 'Giữ đặt phòng')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: Text(isEn ? 'Confirm cancellation' : (isKo ? '취소 확인' : 'Xác nhận hủy')),
          ),
        ],
      ),
    );

    if (shouldCancel == true && mounted) {
      try {
        final repo = ref.read(bookingRepositoryProvider);
        await repo.cancelBooking(
          bookingId: booking.id,
          reason: reasonController.text.trim(),
        );
        ref.invalidate(myBookingsProvider);
        ref.invalidate(bookingDetailProvider(booking.id));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEn
                  ? 'Booking cancelled successfully.'
                  : (isKo
                      ? '예약이 성공적으로 취소되었습니다.'
                      : 'Đã hủy đặt phòng thành công.')),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEn
                    ? 'Cannot cancel: ${e.toString().replaceFirst('Exception: ', '')}'
                    : (isKo
                        ? '취소 실패: ${e.toString().replaceFirst('Exception: ', '')}'
                        : 'Không thể hủy: ${e.toString().replaceFirst('Exception: ', '')}'),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _openReviewModal(Booking booking) async {
    final locale = ref.read(localeProvider);
    final isEn = locale.startsWith('en');
    final isKo = locale.startsWith('ko');

    int selectedRating = 5;
    final commentCtrl = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(isEn
                  ? 'Review your stay at ${booking.propertyName}'
                  : (isKo
                      ? '${booking.propertyName} 숙박 후기 작성'
                      : 'Đánh giá kỳ nghỉ tại ${booking.propertyName}')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn
                          ? 'Your rating:'
                          : (isKo ? '만족도 평가:' : 'Mức độ hài lòng của bạn:'),
                      style:
                          const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4,
                      children: List.generate(5, (index) {
                        final starVal = index + 1;
                        final isSelected = starVal <= selectedRating;
                        return InkWell(
                          onTap: () =>
                              setModalState(() => selectedRating = starVal),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    LucideIcons.star,
                                    size: 22,
                                    color: isSelected
                                        ? AppColors.iconStrong
                                        : AppColors.textMuted,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$starVal★',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: commentCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: isEn
                            ? 'Share your experience *'
                            : (isKo
                                ? '실제 이용 후기를 공유해 주세요 *'
                                : 'Chia sẻ trải nghiệm thực tế của bạn *'),
                        hintText: isEn
                            ? 'Villa space, swimming pool, host support...'
                            : (isKo
                                ? '숙소 공간, 수영장, 호스트의 응대 등...'
                                : 'Không gian biệt thự, hồ bơi, sự hỗ trợ của chủ nhà...'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(isEn ? 'Close' : (isKo ? '닫기' : 'Đóng')),
                ),
                FilledButton(
                  onPressed: () {
                    if (commentCtrl.text.trim().length < 5) return;
                    Navigator.of(ctx).pop(true);
                  },
                  child: Text(isEn
                      ? 'Submit review'
                      : (isKo ? '후기 등록' : 'Gửi đánh giá')),
                ),
              ],
            );
          },
        );
      },
    );

    if (submitted == true && mounted) {
      try {
        await ref.read(reviewRepositoryProvider).createReview(
              bookingId: booking.id,
              rating: selectedRating,
              comment: commentCtrl.text.trim(),
            );
        ref.invalidate(myBookingsProvider);
        if (booking.listingId.isNotEmpty) {
          ref.invalidate(listingReviewsProvider(booking.listingId));
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEn
                  ? 'Thank you for submitting your review!'
                  : (isKo
                      ? '소중한 후기를 남겨주셔서 감사합니다!'
                      : 'Cảm ơn bạn đã gửi đánh giá kỳ nghỉ!')),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.valueOrNull;
    final locale = ref.watch(localeProvider);
    final isEn = locale.startsWith('en');
    final isKo = locale.startsWith('ko');

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.surfaceBase,
        body: Column(
          children: [
            const AppSearchHeader(
              currentPath: '/account/trips',
            ),
            Expanded(
              child: SafeArea(
                top: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.s24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          LucideIcons.plane,
                          size: 64,
                          color: AppColors.iconStrong,
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        Text(
                          isEn
                              ? 'Log in to view trips'
                              : (isKo ? '로그인하여 여행 확인' : 'Đăng nhập để xem chuyến đi'),
                          style: AppTypography.sectionHeading,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        Text(
                          isEn
                              ? 'When logged in, you can track booking status, payment, and manage your stays.'
                              : (isKo
                                  ? '로그인하시면 예약 상태, 결제 내역 확인 및 여행 관리가 가능합니다.'
                                  : 'Khi đăng nhập, bạn có thể theo dõi tình trạng đặt phòng, thanh toán và quản lý kỳ nghỉ của mình.'),
                          style: AppTypography.body
                              .copyWith(color: AppColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.s24),
                        AppButton(
                          text: isEn
                              ? 'Log in now'
                              : (isKo ? '지금 로그인' : 'Đăng nhập ngay'),
                          onPressed: () => context.push('/dang-nhap'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final bookingsAsync = ref.watch(myBookingsProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceBase,
      body: Column(
        children: [
          const AppSearchHeader(
            currentPath: '/account/trips',
          ),
          Material(
            color: AppColors.surfaceBase,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.textPrimary,
              indicatorWeight: 2.5,
              labelStyle:
                  AppTypography.caption.copyWith(fontWeight: FontWeight.w700),
              tabs: [
                Tab(text: isEn ? 'Upcoming' : (isKo ? '예정된 여행' : 'Sắp tới')),
                Tab(text: isEn ? 'Completed' : (isKo ? '완료된 여행' : 'Hoàn tất')),
                Tab(text: isEn ? 'Cancelled' : (isKo ? '취소된 예약' : 'Đã hủy')),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          Expanded(
            child: SafeArea(
              top: false,
              child: bookingsAsync.when(
                loading: () => Center(
                    child: AppLoading(
                        message: isEn
                            ? 'Loading trips...'
                            : (isKo
                                ? '여행 일정을 불러오는 중...'
                                : 'Đang tải lịch trình...'))),
                error: (err, _) => Center(
                  child: AppErrorView(
                    message: err.toString().replaceFirst('Exception: ', ''),
                    onRetry: () => ref.invalidate(myBookingsProvider),
                  ),
                ),
                data: (bookings) {
                  final activeBookings = bookings
                      .where((b) => b.isActive)
                      .toList()
                    ..sort((a, b) {
                      final dateA =
                          DateTime.tryParse(a.checkInDate) ?? DateTime(2099);
                      final dateB =
                          DateTime.tryParse(b.checkInDate) ?? DateTime(2099);
                      final cmp = dateA.compareTo(dateB);
                      if (cmp != 0) return cmp;
                      return a.id.compareTo(b.id);
                    });
                  final completedBookings = bookings
                      .where((b) => b.isCompleted)
                      .toList()
                    ..sort((a, b) {
                      final dateA =
                          DateTime.tryParse(a.checkInDate) ?? DateTime(1970);
                      final dateB =
                          DateTime.tryParse(b.checkInDate) ?? DateTime(1970);
                      final cmp = dateB.compareTo(dateA);
                      if (cmp != 0) return cmp;
                      return b.id.compareTo(a.id);
                    });
                  final cancelledBookings = bookings
                      .where((b) => b.isCancelled)
                      .toList()
                    ..sort((a, b) {
                      final dateA =
                          DateTime.tryParse(a.checkInDate) ?? DateTime(1970);
                      final dateB =
                          DateTime.tryParse(b.checkInDate) ?? DateTime(1970);
                      final cmp = dateB.compareTo(dateA);
                      if (cmp != 0) return cmp;
                      return b.id.compareTo(a.id);
                    });

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBookingList(
                        bookings: activeBookings,
                        emptyTitle: isEn
                            ? 'No upcoming trips'
                            : (isKo
                                ? '예정된 여행이 없습니다'
                                : 'Chưa có chuyến đi sắp tới'),
                        emptyDescription: isEn
                            ? 'You have no upcoming vacations. Explore and book a villa now!'
                            : (isKo
                                ? '예정된 여행이 없습니다. 지금 빌라를 둘러보고 예약해보세요!'
                                : 'Bạn chưa có kỳ nghỉ nào sắp diễn ra. Hãy khám phá và đặt villa ngay!'),
                        locale: locale,
                      ),
                      _buildBookingList(
                        bookings: completedBookings,
                        emptyTitle: isEn
                            ? 'No completed trips'
                            : (isKo
                                ? '완료된 여행이 없습니다'
                                : 'Chưa có kỳ nghỉ đã hoàn tất'),
                        emptyDescription: isEn
                            ? 'Your past trips will be saved here.'
                            : (isKo
                                ? '지난 여행 기록이 여기에 표시됩니다.'
                                : 'Các chuyến đi đã qua sẽ được lưu giữ tại đây.'),
                        locale: locale,
                      ),
                      _buildBookingList(
                        bookings: cancelledBookings,
                        emptyTitle: isEn
                            ? 'No cancelled bookings'
                            : (isKo
                                ? '취소된 예약이 없습니다'
                                : 'Không có đơn đặt đã hủy'),
                        emptyDescription: isEn
                            ? 'No bookings have been cancelled.'
                            : (isKo
                                ? '취소된 내역이 없습니다.'
                                : 'Không có chuyến đi nào bị hủy.'),
                        locale: locale,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingList({
    required List<Booking> bookings,
    required String emptyTitle,
    required String emptyDescription,
    required String locale,
  }) {
    final isEn = locale.startsWith('en');
    final isKo = locale.startsWith('ko');

    if (bookings.isEmpty) {
      return AppEmptyView(
        title: emptyTitle,
        description: emptyDescription,
        actionText: isEn
            ? 'Explore villas'
            : (isKo ? '빌라 둘러보기' : 'Khám phá villa'),
        onAction: () => context.go('/'),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => ref.invalidate(myBookingsProvider),
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.s16),
        itemCount: bookings.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s16),
        itemBuilder: (context, index) {
          final booking = bookings[index];
          return _buildBookingCard(booking, locale);
        },
      ),
    );
  }

  Widget _buildBookingCard(Booking booking, String locale) {
    final isEn = locale.startsWith('en');
    final isKo = locale.startsWith('ko');
    final formatter = ref.watch(moneyFormatterProvider);
    final totalResult = formatter.format(
      booking.totalAmount,
      context: MoneyDisplayContext.breakdown,
    );
    final isRefundStatus = booking.effectiveStatus == 'refund_pending' ||
        booking.effectiveStatus == 'refunded';
    Color badgeText = const Color(0xFFB45309);
    if (booking.status == 'paid' ||
        booking.status == 'confirmed' ||
        booking.status == 'checked_in' ||
        booking.status == 'completed') {
      badgeText = const Color(0xFF047857);
    } else if (booking.isCancelled) {
      badgeText = AppColors.errorRed;
    }

    final isExpanded = _expandedBookingIds.contains(booking.id);
    final pb = booking.priceBreakdown;
    final remainingHoldSeconds = booking.computeRemainingPaymentSeconds();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (booking.listingId.isNotEmpty) {
          context.push('/villa/${booking.listingId}');
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: AppImage(
                url: booking.coverImageUrl ?? 'assets/images/NDT05929-HDR1.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        booking.propertyName,
                        style: AppTypography.cardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        booking.statusDisplayFor(locale),
                        textAlign: TextAlign.right,
                        style: AppTypography.caption.copyWith(
                          color: badgeText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (booking.address != null && booking.address!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(LucideIcons.mapPin,
                          size: 14, color: AppColors.iconMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          booking.address!,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.s12),

                // Responsive Booking details wrap (prevents Row overflow on 320px screens)
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.calendar,
                            size: 16, color: AppColors.iconStrong),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${booking.checkInDate} → ${booking.checkOutDate}',
                            style: AppTypography.body
                                .copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    () {
                      final nightsText = isEn
                          ? '${booking.nights} ${booking.nights == 1 ? "night" : "nights"}'
                          : (isKo ? '${booking.nights}박' : '${booking.nights} đêm');
                      final guestsText = isEn
                          ? '${booking.guestCount} ${booking.guestCount == 1 ? "guest" : "guests"}'
                          : (isKo ? '${booking.guestCount}명' : '${booking.guestCount} khách');
                      return Text(
                        '$nightsText • $guestsText',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted),
                      );
                    }(),
                  ],
                ),

                if (booking.status == 'pending_payment') ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.clock,
                        size: 14,
                        color: AppColors.iconStrong,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          remainingHoldSeconds > 0
                              ? (isEn
                                  ? 'Hold time remaining: ${_formatHoldCountdown(remainingHoldSeconds)}'
                                  : (isKo
                                      ? '예약 대기 시간: ${_formatHoldCountdown(remainingHoldSeconds)}'
                                      : 'Giữ chỗ còn: ${_formatHoldCountdown(remainingHoldSeconds)}'))
                              : (isEn
                                  ? '15-minute hold time expired'
                                  : (isKo
                                      ? '예약 대기 시간(15분) 만료'
                                      : 'Đã hết thời gian giữ chỗ 15 phút')),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: remainingHoldSeconds > 0
                                ? AppColors.textSecondary
                                : AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Expandable Price & Detail Drawer (`TripHistoryCard.tsx` - Flat Minimal)
                if (isExpanded && pb != null) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.divider),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEn
                              ? 'Booking details #${booking.id}'
                              : (isKo
                                  ? '예약 상세 내역 #${booking.id}'
                                  : 'Chi tiết đơn đặt #${booking.id}'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _DetailItemRow(
                          label: isEn
                              ? 'Room rate (${booking.nights} ${booking.nights == 1 ? "night" : "nights"})'
                              : (isKo
                                  ? '숙박 요금 (${booking.nights}박)'
                                  : 'Tiền phòng (${booking.nights} đêm)'),
                          value: formatter.format(
                            pb.baseNightsAmount,
                            context: MoneyDisplayContext.breakdown,
                          ).formatted,
                        ),
                        if (pb.weekendSurchargeAmount > 0)
                          _DetailItemRow(
                            label: isEn
                                ? 'Weekend surcharge'
                                : (isKo ? '주말 할증료' : 'Phụ thu cuối tuần'),
                            value: formatter.format(
                              pb.weekendSurchargeAmount,
                              context: MoneyDisplayContext.breakdown,
                            ).formatted,
                          ),
                        if (pb.extraGuestFeeAmount > 0)
                          _DetailItemRow(
                            label: isEn
                                ? 'Extra guest fee'
                                : (isKo ? '추가 인원 요금' : 'Phụ thu khách thêm'),
                            value: formatter.format(
                              pb.extraGuestFeeAmount,
                              context: MoneyDisplayContext.breakdown,
                            ).formatted,
                          ),
                        if (pb.surchargeAmount > 0)
                          _DetailItemRow(
                            label: isEn
                                ? 'Standard surcharge'
                                : (isKo ? '고정 추가 요금' : 'Phụ thu cố định'),
                            value: formatter.format(
                              pb.surchargeAmount,
                              context: MoneyDisplayContext.breakdown,
                            ).formatted,
                          ),
                        if (pb.cleaningFee > 0)
                          _DetailItemRow(
                            label: isEn
                                ? 'Cleaning fee'
                                : (isKo ? '청소비' : 'Phí vệ sinh'),
                            value: formatter.format(
                              pb.cleaningFee,
                              context: MoneyDisplayContext.breakdown,
                            ).formatted,
                          ),
                        if (pb.serviceFee > 0)
                          _DetailItemRow(
                            label: isEn
                                ? 'Service fee'
                                : (isKo ? '서비스 수수료' : 'Phí dịch vụ'),
                            value: formatter.format(
                              pb.serviceFee,
                              context: MoneyDisplayContext.breakdown,
                            ).formatted,
                          ),
                        if (pb.discountAmount > 0)
                          _DetailItemRow(
                            label: booking.couponCode != null &&
                                    booking.couponCode!.isNotEmpty
                                ? (isEn
                                    ? 'Discount (${booking.couponCode})'
                                    : (isKo
                                        ? '할인 (${booking.couponCode})'
                                        : 'Giảm giá (${booking.couponCode})'))
                                : (isEn
                                    ? 'Discount'
                                    : (isKo ? '할인' : 'Giảm giá')),
                            value: formatter.formatDiscount(
                              pb.discountAmount,
                              context: MoneyDisplayContext.breakdown,
                            ),
                          ),
                        if (booking.specialRequests != null &&
                            booking.specialRequests!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              isEn
                                  ? 'Note: ${booking.specialRequests}'
                                  : (isKo
                                      ? '요청 사항: ${booking.specialRequests}'
                                      : 'Ghi chú: ${booking.specialRequests}'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        if (booking.cancellationReasonDisplayFor(locale) != null &&
                            booking.cancellationReasonDisplayFor(locale)!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              isEn
                                  ? 'Cancellation reason: ${booking.cancellationReasonDisplayFor(locale)}'
                                  : (isKo
                                      ? '취소 사유: ${booking.cancellationReasonDisplayFor(locale)}'
                                      : 'Lý do hủy: ${booking.cancellationReasonDisplayFor(locale)}'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                const Divider(height: AppSpacing.s24),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isEn
                          ? 'Total payment'
                          : (isKo ? '총 결제 금액' : 'Tổng thanh toán'),
                      style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w400)),
                    const SizedBox(height: 4),
                    Text(totalResult.formatted,
                        style: AppTypography.cardTitle
                            .copyWith(color: AppColors.primary)),
                    if (totalResult.isForeignDisplayed) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${formatter.l10n.fxTotalPayableVnd(formatter.formatExactVnd(booking.totalAmount, withCode: true))} • ${formatter.l10n.fxHistoricalReferenceNote}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (formatter.effectiveCurrency.isForeign &&
                        isRefundStatus) ...[
                      const SizedBox(height: 2),
                      Text(
                        formatter.l10n.fxRefundInVndNotice,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (booking.canPayNow) ...[
                      ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  textStyle: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12))),
                              onPressed: () =>
                                  context.push('/thanh-toan/${booking.id}'),
                              child: Text(
                                  isEn
                                      ? 'Pay now'
                                      : (isKo ? '결제하기' : 'Thanh toán'),
                                  textAlign: TextAlign.center))),
                      const SizedBox(height: 10),
                    ],
                    LayoutBuilder(builder: (context, constraints) {
                      final secondaryStyle = OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textStrong,
                          side: const BorderSide(color: AppColors.borderSoft),
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          textStyle: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)));
                      final actions = <Widget>[
                        TextButton(
                            style: TextButton.styleFrom(
                                foregroundColor: AppColors.textStrong,
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                surfaceTintColor: Colors.transparent,
                                elevation: 0,
                                side: BorderSide.none,
                                minimumSize: const Size(0, 48),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                textStyle: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            onPressed: () => setState(() {
                                  if (isExpanded) {
                                    _expandedBookingIds.remove(booking.id);
                                  } else {
                                    _expandedBookingIds.add(booking.id);
                                  }
                                }),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    isExpanded
                                        ? (isEn
                                            ? 'Hide details'
                                            : (isKo ? '상세 숨기기' : 'Ẩn chi tiết'))
                                        : (isEn
                                            ? 'Details'
                                            : (isKo ? '상세 정보' : 'Chi tiết')),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  isExpanded
                                      ? LucideIcons.chevronUp
                                      : LucideIcons.chevronDown,
                                  size: 16,
                                  color: AppColors.iconStrong,
                                ),
                              ],
                            )),
                        if (booking.canCancel)
                          TextButton(
                              style: TextButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  minimumSize: const Size(0, 48),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  textStyle: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12))),
                              onPressed: () => _handleCancelBooking(booking),
                              child: Text(
                                  isEn
                                      ? 'Cancel booking'
                                      : (isKo ? '예약 취소' : 'Hủy phòng'),
                                  textAlign: TextAlign.center)),
                        if (booking.isCompleted && !booking.hasReview)
                          OutlinedButton(
                              style: secondaryStyle,
                              onPressed: () => _openReviewModal(booking),
                              child: Text(
                                  isEn
                                      ? 'Review'
                                      : (isKo ? '후기 작성' : 'Đánh giá'),
                                  textAlign: TextAlign.center)),
                      ];
                      if (constraints.maxWidth < 280 ||
                          MediaQuery.textScalerOf(context).scale(14) > 21) {
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < actions.length; i++) ...[
                                if (i > 0) const SizedBox(height: 8),
                                actions[i]
                              ]
                            ]);
                      }
                      return Row(children: [
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(child: actions[i])
                        ]
                      ]);
                    }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailItemRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailItemRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
