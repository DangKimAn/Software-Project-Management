import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_header_footer.dart';
import '../../../../shared/widgets/app_image.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../auth/presentation/view_models/auth_notifier.dart';
import '../../../reviews/presentation/widgets/review_list_widget.dart';
import '../../domain/entities/booking.dart';
import '../view_models/trips_view_model.dart';
import '../widgets/global_pending_booking_banner.dart';

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

    final reasonController = TextEditingController();
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy đặt phòng'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bạn có chắc chắn muốn hủy đặt phòng tại "${booking.propertyName}"?',
                style: AppTypography.body,
              ),
              const SizedBox(height: AppSpacing.s16),
              TextField(
                controller: reasonController,
                maxLines: 1,
                style: const TextStyle(fontSize: 13, height: 1.2),
                decoration: const InputDecoration(
                  labelText: 'Lý do hủy (bắt buộc)',
                  hintText: 'Thay đổi kế hoạch cá nhân...',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Giữ đặt phòng'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Xác nhận hủy'),
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
            const SnackBar(content: Text('Đã hủy đặt phòng thành công.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Không thể hủy: ${e.toString().replaceFirst('Exception: ', '')}',
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _openReviewModal(Booking booking) async {
    int selectedRating = 5;
    final commentCtrl = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Đánh giá kỳ nghỉ tại ${booking.propertyName}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mức độ hài lòng của bạn:',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                      decoration: const InputDecoration(
                        labelText: 'Chia sẻ trải nghiệm thực tế của bạn *',
                        hintText:
                            'Không gian biệt thự, hồ bơi, sự hỗ trợ của chủ nhà...',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Đóng'),
                ),
                FilledButton(
                  onPressed: () {
                    if (commentCtrl.text.trim().length < 5) return;
                    Navigator.of(ctx).pop(true);
                  },
                  child: const Text('Gửi đánh giá'),
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
            const SnackBar(
              content: Text('Cảm ơn bạn đã gửi đánh giá kỳ nghỉ!'),
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

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.surfaceBase,
        body: Column(
          children: [
            const AppSearchHeader(
              currentPath: '/account/trips',
              hidePendingBanner: true,
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
                        const Text(
                          'Đăng nhập để xem chuyến đi',
                          style: AppTypography.sectionHeading,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        Text(
                          'Khi đăng nhập, bạn có thể theo dõi tình trạng đặt phòng, thanh toán và quản lý kỳ nghỉ của mình.',
                          style:
                              AppTypography.body.copyWith(color: AppColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.s24),
                        AppButton(
                          text: 'Đăng nhập ngay',
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
    final activeBooking = ref.watch(activePendingBookingProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceBase,
      body: Column(
        children: [
          const AppSearchHeader(
            currentPath: '/account/trips',
            hidePendingBanner: true,
          ),
          if (activeBooking != null)
            GlobalPendingBookingBanner(
              booking: activeBooking,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
              tabs: const [
                Tab(text: 'Sắp tới'),
                Tab(text: 'Hoàn tất'),
                Tab(text: 'Đã hủy'),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          Expanded(
            child: SafeArea(
              top: false,
              child: bookingsAsync.when(
                loading: () => const Center(
                    child: AppLoading(message: 'Đang tải lịch trình...')),
                error: (err, _) => Center(
                  child: AppErrorView(
                    message: err.toString().replaceFirst('Exception: ', ''),
                    onRetry: () => ref.invalidate(myBookingsProvider),
                  ),
                ),
                data: (bookings) {
                  final activeBookings =
                      bookings.where((b) => b.isActive).toList()
                        ..sort((a, b) {
                          final dateA = DateTime.tryParse(a.checkInDate) ??
                              DateTime(2099);
                          final dateB = DateTime.tryParse(b.checkInDate) ??
                              DateTime(2099);
                          final cmp = dateA.compareTo(dateB);
                          if (cmp != 0) return cmp;
                          return a.id.compareTo(b.id);
                        });
                  final completedBookings =
                      bookings.where((b) => b.isCompleted).toList()
                        ..sort((a, b) {
                          final dateA = DateTime.tryParse(a.checkInDate) ??
                              DateTime(1970);
                          final dateB = DateTime.tryParse(b.checkInDate) ??
                              DateTime(1970);
                          final cmp = dateB.compareTo(dateA);
                          if (cmp != 0) return cmp;
                          return b.id.compareTo(a.id);
                        });
                  final cancelledBookings =
                      bookings.where((b) => b.isCancelled).toList()
                        ..sort((a, b) {
                          final dateA = DateTime.tryParse(a.checkInDate) ??
                              DateTime(1970);
                          final dateB = DateTime.tryParse(b.checkInDate) ??
                              DateTime(1970);
                          final cmp = dateB.compareTo(dateA);
                          if (cmp != 0) return cmp;
                          return b.id.compareTo(a.id);
                        });

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBookingList(
                        bookings: activeBookings,
                        emptyTitle: 'Chưa có chuyến đi sắp tới',
                        emptyDescription:
                            'Bạn chưa có kỳ nghỉ nào sắp diễn ra. Hãy khám phá và đặt villa ngay!',
                      ),
                      _buildBookingList(
                        bookings: completedBookings,
                        emptyTitle: 'Chưa có kỳ nghỉ đã hoàn tất',
                        emptyDescription:
                            'Các chuyến đi đã qua sẽ được lưu giữ tại đây.',
                      ),
                      _buildBookingList(
                        bookings: cancelledBookings,
                        emptyTitle: 'Không có đơn đặt đã hủy',
                        emptyDescription: 'Không có chuyến đi nào bị hủy.',
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
  }) {
    if (bookings.isEmpty) {
      return AppEmptyView(
        title: emptyTitle,
        description: emptyDescription,
        actionText: 'Khám phá villa',
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
          return _buildBookingCard(booking);
        },
      ),
    );
  }

  Widget _buildBookingCard(Booking booking) {
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

    return AppCard(
      padding: EdgeInsets.zero,
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
                        booking.statusDisplay,
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
                    Text(
                      '${booking.nights} đêm • ${booking.guestCount} khách',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textMuted),
                    ),
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
                              ? 'Giữ chỗ còn: ${_formatHoldCountdown(remainingHoldSeconds)}'
                              : 'Đã hết thời gian giữ chỗ 15 phút',
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
                          'Chi tiết đơn đặt #${booking.id}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _DetailItemRow(
                          label: 'Tiền phòng (${booking.nights} đêm)',
                          value:
                              CurrencyFormatter.formatVnd(pb.baseNightsAmount),
                        ),
                        if (pb.weekendSurchargeAmount > 0)
                          _DetailItemRow(
                            label: 'Phụ thu cuối tuần',
                            value: CurrencyFormatter.formatVnd(
                                pb.weekendSurchargeAmount),
                          ),
                        if (pb.extraGuestFeeAmount > 0)
                          _DetailItemRow(
                            label: 'Phụ thu khách thêm',
                            value: CurrencyFormatter.formatVnd(
                                pb.extraGuestFeeAmount),
                          ),
                        if (pb.surchargeAmount > 0)
                          _DetailItemRow(
                            label: 'Phụ thu cố định',
                            value:
                                CurrencyFormatter.formatVnd(pb.surchargeAmount),
                          ),
                        if (pb.cleaningFee > 0)
                          _DetailItemRow(
                            label: 'Phí vệ sinh',
                            value: CurrencyFormatter.formatVnd(pb.cleaningFee),
                          ),
                        if (pb.serviceFee > 0)
                          _DetailItemRow(
                            label: 'Phí dịch vụ',
                            value: CurrencyFormatter.formatVnd(pb.serviceFee),
                          ),
                        if (pb.discountAmount > 0)
                          _DetailItemRow(
                            label: booking.couponCode != null &&
                                    booking.couponCode!.isNotEmpty
                                ? 'Giảm giá (${booking.couponCode})'
                                : 'Giảm giá',
                            value:
                                '-${CurrencyFormatter.formatVnd(pb.discountAmount)}',
                          ),
                        if (booking.specialRequests != null &&
                            booking.specialRequests!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Ghi chú: ${booking.specialRequests}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        if (booking.cancellationReasonDisplay != null &&
                            booking.cancellationReasonDisplay!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Lý do hủy: ${booking.cancellationReasonDisplay}',
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
                    Text('Tổng thanh toán',
                        style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w400)),
                    const SizedBox(height: 4),
                    Text(CurrencyFormatter.formatVnd(booking.totalAmount),
                        style: AppTypography.cardTitle
                            .copyWith(color: AppColors.primary)),
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
                              child: const Text('Thanh toán',
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
                                    isExpanded ? 'Ẩn chi tiết' : 'Chi tiết',
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
                              child: const Text('Hủy phòng',
                                  textAlign: TextAlign.center)),
                        if (booking.isCompleted && !booking.hasReview)
                          OutlinedButton(
                              style: secondaryStyle,
                              onPressed: () => _openReviewModal(booking),
                              child: const Text('Đánh giá',
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
