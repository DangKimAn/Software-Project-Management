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
import '../../../../shared/widgets/app_loading.dart';
import '../../../auth/presentation/view_models/auth_notifier.dart';
import '../../domain/entities/booking.dart';
import '../view_models/trips_view_model.dart';

class TripsScreen extends ConsumerStatefulWidget {
  const TripsScreen({super.key});

  @override
  ConsumerState<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends ConsumerState<TripsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleCancelBooking(Booking booking) async {
    final reasonController = TextEditingController();
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy đặt phòng'),
        content: Column(
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
              decoration: const InputDecoration(
                labelText: 'Lý do hủy (bắt buộc)',
                hintText: 'Thay đổi kế hoạch cá nhân...',
              ),
              maxLines: 2,
            ),
          ],
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã hủy đặt phòng thành công.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể hủy: ${e.toString()}')),
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
        appBar: AppBar(
          backgroundColor: AppColors.surfaceBase,
          elevation: 0,
          title: Text(
            'Chuyến đi của bạn',
            style: AppTypography.sectionHeading
                .copyWith(color: AppColors.textStrong),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.calendarCheck,
                    size: 64, color: AppColors.primary),
                const SizedBox(height: AppSpacing.s16),
                const Text(
                  'Đăng nhập để xem chuyến đi',
                  style: AppTypography.sectionHeading,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  'Khi đăng nhập, bạn có thể theo dõi tình trạng đặt phòng, xem lịch trình và quản lý kỳ nghỉ của mình.',
                  style:
                      AppTypography.body.copyWith(color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.s24),
                AppButton(
                  text: 'Đăng nhập ngay',
                  onPressed: () => context.push('/login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bookingsAsync = ref.watch(myBookingsProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceBase,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceBase,
        elevation: 0,
        title: Text(
          'Chuyến đi của bạn',
          style: AppTypography.sectionHeading
              .copyWith(color: AppColors.textStrong),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle:
              AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Sắp tới'),
            Tab(text: 'Hoàn tất'),
            Tab(text: 'Đã hủy'),
          ],
        ),
      ),
      body: bookingsAsync.when(
        loading: () =>
            const Center(child: AppLoading(message: 'Đang tải lịch trình...')),
        error: (err, _) => Center(
          child: AppErrorView(
            message: err.toString().replaceFirst('Exception: ', ''),
            onRetry: () => ref.invalidate(myBookingsProvider),
          ),
        ),
        data: (bookings) {
          final activeBookings = bookings.where((b) => b.isActive).toList();
          final completedBookings =
              bookings.where((b) => b.isCompleted).toList();
          final cancelledBookings =
              bookings.where((b) => b.isCancelled).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildBookingList(
                bookings: activeBookings,
                emptyTitle: 'Chưa có chuyến đi sắp tới',
                emptyDescription:
                    'Bạn chưa có kỳ nghỉ nào sắp diễn ra. Hãy khám phá và đặt villa ngay!',
                canCancel: true,
              ),
              _buildBookingList(
                bookings: completedBookings,
                emptyTitle: 'Chưa có kỳ nghỉ đã hoàn tất',
                emptyDescription:
                    'Các chuyến đi đã qua sẽ được lưu giữ tại đây.',
                canCancel: false,
              ),
              _buildBookingList(
                bookings: cancelledBookings,
                emptyTitle: 'Không có đơn đặt đã hủy',
                emptyDescription: 'Không có chuyến đi nào bị hủy.',
                canCancel: false,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBookingList({
    required List<Booking> bookings,
    required String emptyTitle,
    required String emptyDescription,
    required bool canCancel,
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
          return _buildBookingCard(booking, canCancel);
        },
      ),
    );
  }

  Widget _buildBookingCard(Booking booking, bool canCancel) {
    Color badgeBg = const Color(0xFFFEF3C7);
    Color badgeText = const Color(0xFFB45309);
    if (booking.status == 'confirmed' || booking.status == 'checked_in') {
      badgeBg = const Color(0xFFECFDF5);
      badgeText = const Color(0xFF047857);
    } else if (booking.isCancelled) {
      badgeBg = const Color(0xFFFEE2E2);
      badgeText = const Color(0xFFB91C1C);
    }

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () {
        if (booking.listingId.isNotEmpty) {
          context.push('/villas/${booking.listingId}');
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image with status badge
          Stack(
            children: [
              Container(
                height: 140,
                width: double.infinity,
                color: AppColors.surfaceMuted,
                child: booking.coverImageUrl != null &&
                        booking.coverImageUrl!.isNotEmpty
                    ? Image.network(
                        booking.coverImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(LucideIcons.image,
                              size: 36, color: AppColors.textMuted),
                        ),
                      )
                    : const Center(
                        child: Icon(LucideIcons.building,
                            size: 36, color: AppColors.textMuted),
                      ),
              ),
              Positioned(
                top: AppSpacing.s12,
                left: AppSpacing.s12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    booking.statusDisplay,
                    style: AppTypography.caption.copyWith(
                      color: badgeText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.propertyName,
                  style: AppTypography.cardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (booking.address != null && booking.address!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(LucideIcons.mapPin,
                          size: 14, color: AppColors.textMuted),
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

                // Booking details row
                Row(
                  children: [
                    const Icon(LucideIcons.calendar,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      '${booking.checkInDate} → ${booking.checkOutDate}',
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Text(
                      '${booking.nights} đêm • ${booking.guestCount} khách',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.s24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tổng thanh toán',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textMuted),
                        ),
                        Text(
                          CurrencyFormatter.formatVnd(booking.totalAmount),
                          style: AppTypography.cardTitle
                              .copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                    if (canCancel && !booking.isCancelled)
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: () => _handleCancelBooking(booking),
                        child: const Text('Hủy phòng'),
                      ),
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
