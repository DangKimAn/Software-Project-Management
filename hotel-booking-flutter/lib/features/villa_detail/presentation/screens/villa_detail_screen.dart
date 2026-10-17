import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/date/booking_date.dart';
import '../../../../core/storage/preferences_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/animations/animated_heart_button.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_header_footer.dart';
import '../../../../shared/widgets/app_image.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_semantic_icons.dart';
import '../../../auth/presentation/view_models/auth_notifier.dart';
import '../../../reviews/presentation/widgets/review_list_widget.dart';
import '../../../search/presentation/widgets/booking_date_range_picker.dart';
import '../../../trips/presentation/view_models/trips_view_model.dart';
import '../../../villas/domain/entities/villa.dart';
import '../../../villas/presentation/widgets/property_card.dart';
import '../../../villas/presentation/widgets/property_image_carousel.dart';
import '../widgets/booking_action_bar.dart';
import '../widgets/daily_price_breakdown.dart';
import '../widgets/mobile_spec_summary.dart';
import '../widgets/property_faq_section.dart';

/// Complete port of `Source goc/frontend/src/views/pages/ListingDetail/ListingDetailPage.tsx`.
class VillaDetailScreen extends ConsumerStatefulWidget {
  final String villaId;

  const VillaDetailScreen({super.key, required this.villaId});

  @override
  ConsumerState<VillaDetailScreen> createState() => _VillaDetailScreenState();
}

class _VillaDetailScreenState extends ConsumerState<VillaDetailScreen> {
  BookingDate? _checkIn;
  BookingDate? _checkOut;
  int _guestsCount = 2;
  final TextEditingController _couponCtrl = TextEditingController();
  final TextEditingController _specialRequestsCtrl = TextEditingController();
  int _couponDiscountVnd = 0;
  String? _appliedCouponCode;
  String? _couponMessage;
  bool _isValidatingCoupon = false;
  bool _isSubmittingBooking = false;
  String? _recordedVillaId;

  @override
  void initState() {
    super.initState();
    final filter = ref.read(villaFilterProvider);
    final today = BookingDate.todayVn();
    _checkIn = filter.checkIn ?? today.addDays(1);
    _checkOut = filter.checkOut ?? today.addDays(3);
    if (filter.effectiveGuests > 0) {
      _guestsCount = filter.effectiveGuests;
    }
  }

  @override
  void dispose() {
    _couponCtrl.dispose();
    _specialRequestsCtrl.dispose();
    super.dispose();
  }

  int _calculateNights() =>
      VillaDetailPricingCalculator.calculateNights(_checkIn, _checkOut);

  ({
    int nights,
    int weekendNights,
    int roomSubtotal,
    int extraGuestTotal,
    int cleaningFee,
    int serviceFee,
    int discount,
    int finalTotal,
  }) _calculatePricing(Villa villa) {
    return VillaDetailPricingCalculator.calculatePricing(
      villa: villa,
      checkIn: _checkIn,
      checkOut: _checkOut,
      guestsCount: _guestsCount,
      couponDiscountVnd: _couponDiscountVnd,
    );
  }

  Future<void> _applyCoupon(Villa villa) async {
    final code = _couponCtrl.text.trim().toUpperCase();
    if (code.isEmpty || _checkIn == null || _checkOut == null) return;
    final pricing = _calculatePricing(villa);

    setState(() {
      _isValidatingCoupon = true;
      _couponMessage = null;
    });

    try {
      final res = await ref.read(bookingRepositoryProvider).validateCoupon(
            code: code,
            listingId: villa.id,
            checkInDate: _checkIn!.toIsoDate(),
            checkOutDate: _checkOut!.toIsoDate(),
            guestsCount: _guestsCount,
            subtotalAmount: pricing.roomSubtotal,
          );
      if (!mounted) return;
      setState(() {
        _isValidatingCoupon = false;
        if (res.valid && res.discountAmount > 0) {
          _couponDiscountVnd = res.discountAmount;
          _appliedCouponCode = res.code;
          _couponMessage =
              'Đã áp dụng mã ${res.code} (-${CurrencyFormatter.formatVnd(res.discountAmount)})';
        } else {
          _couponDiscountVnd = 0;
          _appliedCouponCode = null;
          _couponMessage = res.message ?? 'Mã giảm giá không hợp lệ';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isValidatingCoupon = false;
        _couponDiscountVnd = 0;
        _appliedCouponCode = null;
        _couponMessage = e.toString();
      });
    }
  }

  Future<void> _handleAddToBookingQueue(Villa villa) async {
    final checkInIso = (_checkIn ?? BookingDate.today().addDays(1)).toIsoDate();
    final checkOutIso =
        (_checkOut ?? BookingDate.today().addDays(3)).toIsoDate();
    final item = BookingQueueItem(
      listingId: villa.id,
      title: villa.name,
      location: villa.address,
      imageUrl: villa.imageUrls.isNotEmpty
          ? villa.imageUrls.first
          : 'assets/images/NDT05929-HDR1.jpg',
      pricePerNight: villa.basePriceVnd ?? 0,
      weekendSurcharge: villa.surchargeAmountVnd,
      cleaningFee: villa.cleaningFeeVnd,
      serviceFee: villa.serviceFeeVnd,
      extraGuestFee: villa.extraGuestFeeVnd,
      includedGuests: villa.includedGuests,
      maxGuests: villa.specs.maxGuests > 0 ? villa.specs.maxGuests : 20,
      checkIn: checkInIso,
      checkOut: checkOutIso,
      guestsCount: _guestsCount,
      instantBook: villa.instantBook,
    );

    final status = await ref.read(bookingQueueProvider.notifier).addItem(item);
    if (!mounted) return;

    final message = switch (status) {
      'added' => 'Đã thêm "${villa.name}" vào giỏ chờ đặt phòng.',
      'exists' => 'Đã cập nhật thông tin "${villa.name}" trong giỏ chờ.',
      _ => 'Giỏ chờ đặt phòng tối đa 5 căn. Vui lòng kiểm tra giỏ chờ.',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Mở giỏ chờ',
          onPressed: () => context.push('/gio-cho-dat'),
        ),
      ),
    );
  }

  Future<void> _handleBookNow(Villa villa) async {
    if (_checkIn == null || _checkOut == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ngày nhận phòng và trả phòng.'),
        ),
      );
      return;
    }

    final nights = _calculateNights();
    if (nights < villa.minNights) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Chỗ nghỉ này yêu cầu tối thiểu ${villa.minNights} đêm.',
          ),
        ),
      );
      return;
    }
    if (nights > villa.maxNights) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Chỗ nghỉ này giới hạn tối đa ${villa.maxNights} đêm mỗi lần đặt.',
          ),
        ),
      );
      return;
    }

    final user = ref.read(authNotifierProvider).valueOrNull;
    if (user == null) {
      await ref.read(preferencesServiceProvider).setPendingBookingIntent({
        'listingId': villa.id,
        'checkInDate': _checkIn!.toIsoDate(),
        'checkOutDate': _checkOut!.toIsoDate(),
        'guestsCount': _guestsCount,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để hoàn tất đặt phòng.'),
        ),
      );
      await context.push('/dang-nhap');
      return;
    }

    setState(() => _isSubmittingBooking = true);
    try {
      final booking = await ref.read(bookingRepositoryProvider).createBooking(
            listingId: villa.id,
            checkInDate: _checkIn!.toIsoDate(),
            checkOutDate: _checkOut!.toIsoDate(),
            guestsCount: _guestsCount,
            specialRequests: _specialRequestsCtrl.text.trim(),
            couponCode: _appliedCouponCode,
          );
      ref.invalidate(myBookingsProvider);
      if (!mounted) return;
      setState(() => _isSubmittingBooking = false);

      if (villa.instantBook ||
          booking.status == 'approved' ||
          booking.status == 'awaiting_payment') {
        await context.push('/thanh-toan/${booking.id}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã gửi yêu cầu đặt phòng! Bạn có thể thanh toán ngay hoặc theo dõi tại Chuyến đi.',
            ),
          ),
        );
        await context.push('/thanh-toan/${booking.id}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmittingBooking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _openFullscreenGallery(BuildContext context, Villa villa) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) => _FullscreenGalleryModal(villa: villa),
    );
  }

  @override
  Widget build(BuildContext context) {
    final villaAsync = ref.watch(villaDetailProvider(widget.villaId));
    final favorites = ref.watch(favoritesProvider);
    final isFav = favorites.contains(widget.villaId);

    return villaAsync.when(
      data: (villa) {
        if (villa == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const AppErrorView(
              title: 'Không tìm thấy biệt thự',
              message:
                  'Biệt thự bạn tìm kiếm không tồn tại hoặc đã ngừng phục vụ.',
            ),
          );
        }

        // Record in Recently Viewed once
        if (_recordedVillaId != villa.id) {
          _recordedVillaId = villa.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.read(recentlyViewedProvider.notifier).recordVilla(villa);
            }
          });
        }

        final checkIn = _checkIn ?? BookingDate.today().addDays(1);
        final checkOut = _checkOut ?? checkIn.addDays(2);
        final pricingParams = (
          villaId: villa.id,
          checkIn: checkIn,
          checkOut: checkOut,
        );
        final pricingAsync =
            ref.watch(villaNightlyPricingProvider(pricingParams));
        final recommendationsAsync =
            ref.watch(villaRecommendationsProvider(villa.id));
        final calc = _calculatePricing(villa);

        return Scaffold(
          backgroundColor: AppColors.surfaceBase,
          body: CustomScrollView(
            slivers: [
              // SliverAppBar with monochrome stroke icons directly on UI (no CircleAvatar around icons!)
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                elevation: 0,
                backgroundColor: AppColors.surfaceBase,
                leading: Semantics(
                  button: true,
                  label: 'Quay lại',
                  child: InkWell(
                    onTap: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        context.go('/');
                      }
                    },
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: Icon(
                          LucideIcons.arrowLeft,
                          size: 22,
                          color: AppColors.iconStrong,
                        ),
                      ),
                    ),
                  ),
                ),
                actions: [
                  Semantics(
                    button: true,
                    label: 'Xem toàn bộ ảnh',
                    child: InkWell(
                      onTap: () => _openFullscreenGallery(context, villa),
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Icon(
                            LucideIcons.images,
                            size: 20,
                            color: AppColors.iconStrong,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Sao chép liên kết biệt thự',
                    child: InkWell(
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(
                            text: 'https://vungtaustay.vn/villa/${villa.id}',
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Đã sao chép liên kết vào bộ nhớ tạm'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Icon(
                            LucideIcons.share2,
                            size: 19,
                            color: AppColors.iconStrong,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: AnimatedHeartButton(
                      isFavorite: isFav,
                      onToggle: () {
                        ref
                            .read(favoritesProvider.notifier)
                            .toggleFavorite(villa.id);
                      },
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'villa_image_${villa.id}',
                        child: PropertyImageCarousel(
                          imageUrls: villa.imageUrls,
                          aspectRatio: 16 / 10,
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _openFullscreenGallery(context, villa),
                          icon: const Icon(
                            LucideIcons.grid2x2,
                            size: 15,
                            color: AppColors.iconStrong,
                          ),
                          label: Text(
                            'Xem tất cả ${villa.imageUrls.length} ảnh',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Detail Body
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: FadeSlideIn(
                      duration: const Duration(milliseconds: 400),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Villa Title & Code
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Expanded(
                                  child: Text(
                                    villa.name,
                                    style: AppTypography.displayMedium
                                        .copyWith(fontSize: 22),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  villa.code,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Address & Rating Summary
                            Wrap(
                              spacing: 16,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(LucideIcons.star,
                                        size: 16, color: AppColors.iconStrong),
                                    const SizedBox(width: 4),
                                    Text(
                                      villa.rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '(${villa.reviewCount} đánh giá)',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(LucideIcons.mapPin,
                                        size: 16, color: AppColors.iconMuted),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        villa.address,
                                        style: AppTypography.bodyMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // 2-Tier Specification Summary (Rule 8.1)
                            MobileSpecSummary(specs: villa.specs),

                            const SizedBox(height: 20),

                            // Host Card + Contact Host button (`HostMessagePage.tsx`)
                            _buildHostCard(context, villa),

                            const SizedBox(height: 20),

                            // Description
                            Text('Giới thiệu biệt thự',
                                style: AppTypography.sectionHeading
                                    .copyWith(fontSize: 18)),
                            const SizedBox(height: 8),
                            Text(
                              villa.description,
                              style:
                                  AppTypography.bodyLarge.copyWith(height: 1.6),
                            ),

                            const SizedBox(height: 24),

                            // Amenities List
                            if (villa.amenities.isNotEmpty) ...[
                              Text('Tiện nghi có sẵn',
                                  style: AppTypography.sectionHeading
                                      .copyWith(fontSize: 18)),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 20,
                                runSpacing: 12,
                                children: villa.amenities.map((item) {
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        AppSemanticIcons.resolveAmenityIcon(
                                          item,
                                        ),
                                        size: 16,
                                        color: AppColors.iconStrong,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(item,
                                          style: AppTypography.bodyMedium),
                                    ],
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Interactive Availability Calendar & Booking Configurator (`ListingDetailPage.tsx`)
                            _buildBookingConfiguratorCard(context, villa, calc),

                            const SizedBox(height: 24),

                            // Nightly Price Breakdown loaded from Real API (Constrained Box Height <= 220, Rule 10)
                            pricingAsync.when(
                              data: (prices) {
                                if (prices.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return DailyPriceBreakdown(
                                    nightlyPrices: prices);
                              },
                              loading: () => const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12.0),
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                              ),
                              error: (_, __) => const SizedBox.shrink(),
                            ),

                            const SizedBox(height: 24),

                            // House Rules & Cancellation Policy (`PoliciesCard`)
                            _buildPoliciesCard(villa),

                            const SizedBox(height: 24),

                            // Reviews Section (Rule 7 & 8)
                            ReviewListWidget(
                              listingId: villa.id,
                              averageRating: villa.rating,
                              totalReviews: villa.reviewCount,
                            ),

                            const SizedBox(height: 24),

                            // Nearby / Similar Recommendations (`GET /api/listings/:id/recommendations`)
                            recommendationsAsync.when(
                              data: (recs) {
                                if (recs.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Gợi ý chỗ nghỉ tương tự gần đây',
                                      style: AppTypography.sectionHeading
                                          .copyWith(fontSize: 18),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      height: 360,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: recs.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(width: 16),
                                        itemBuilder: (context, idx) {
                                          final rec = recs[idx];
                                          return SizedBox(
                                            width: 300,
                                            child: PropertyCard(
                                              villa: rec,
                                              isFavorite:
                                                  favorites.contains(rec.id),
                                              onFavoriteToggle: () {
                                                ref
                                                    .read(favoritesProvider
                                                        .notifier)
                                                    .toggleFavorite(rec.id);
                                              },
                                              onTap: () => context
                                                  .push('/villa/${rec.id}'),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                );
                              },
                              loading: () => const SizedBox.shrink(),
                              error: (_, __) => const SizedBox.shrink(),
                            ),

                            // FAQ Section (Rule 8.2)
                            const PropertyFaqSection(),

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: AppFooter()),
            ],
          ),

          // Sticky Bottom Action Bar with SafeArea (Rule 10 & 12)
          bottomNavigationBar: BookingActionBar(
            villa: villa,
            totalCalculatedVnd: calc.finalTotal,
            selectedNights: calc.nights,
            onBookNow:
                _isSubmittingBooking ? null : () => _handleBookNow(villa),
            onAddToQueue: () => _handleAddToBookingQueue(villa),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const AppLoading(
            message: 'Đang tải thông tin chi tiết biệt thự...'),
      ),
      error: (err, stack) => Scaffold(
        appBar: AppBar(),
        body: AppErrorView(
          message: err.toString(),
          onRetry: () => ref.invalidate(villaDetailProvider(widget.villaId)),
        ),
      ),
    );
  }

  Widget _buildHostCard(BuildContext context, Villa villa) {
    final rawName = villa.host?.fullName.trim() ?? '';
    final hostName = rawName.isNotEmpty ? rawName : 'Chủ nhà VungTauStay';
    final rawBio = villa.host?.bio?.trim() ?? '';
    final hostBio = rawBio.isNotEmpty
        ? rawBio
        : 'Chủ nhà tại Vũng Tàu, hỗ trợ thông tin lưu trú và nhận phòng.';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              LucideIcons.badgeCheck,
              size: 24,
              color: AppColors.iconStrong,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chủ nhà: $hostName',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hostBio,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    InkWell(
                      onTap: () =>
                          context.push('/villa/${villa.id}/nhan-tin-host'),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.messageCircle,
                                size: 16,
                                color: AppColors.iconStrong,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Nhắn tin cho Chủ nhà',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _handleAddToBookingQueue(villa),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.shoppingBag,
                                size: 16,
                                color: AppColors.iconStrong,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Thêm vào giỏ chờ đặt',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildBookingConfiguratorCard(
    BuildContext context,
    Villa villa,
    ({
      int nights,
      int weekendNights,
      int roomSubtotal,
      int extraGuestTotal,
      int cleaningFee,
      int serviceFee,
      int discount,
      int finalTotal,
    }) calc,
  ) {
    final maxGuests = villa.specs.maxGuests > 0 ? villa.specs.maxGuests : 30;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Chọn lịch lưu trú & Đặt phòng',
                style: AppTypography.sectionHeading.copyWith(fontSize: 18),
              ),
              Text(
                'Tối thiểu ${villa.minNights} đêm • Tối đa ${villa.maxNights} đêm',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          BookingDateRangePicker(
            initialCheckIn: _checkIn,
            initialCheckOut: _checkOut,
            bookedDatesIso: villa.bookedDatesIso,
            onRangeSelected: (range) {
              setState(() {
                _checkIn = range.$1;
                _checkOut = range.$2;
              });
            },
          ),
          const Divider(height: 28, color: AppColors.divider),

          // Guest Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Số lượng khách lưu trú',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Tiêu chuẩn ${villa.includedGuests} khách (Tối đa $maxGuests khách)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: _guestsCount > 1
                        ? () => setState(() => _guestsCount--)
                        : null,
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: Icon(
                          LucideIcons.minus,
                          size: 18,
                          color: AppColors.iconStrong,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '$_guestsCount khách',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _guestsCount < maxGuests
                        ? () => setState(() => _guestsCount++)
                        : null,
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: Icon(
                          LucideIcons.plus,
                          size: 18,
                          color: AppColors.iconStrong,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Coupon input (`GET /api/coupons/validate`)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'Mã giảm giá (VD: VUNGTAU10)',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed:
                    _isValidatingCoupon ? null : () => _applyCoupon(villa),
                child:
                    Text(_isValidatingCoupon ? 'Đang kiểm tra...' : 'Áp dụng'),
              ),
            ],
          ),
          if (_couponMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              _couponMessage!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _appliedCouponCode != null
                    ? AppColors.success
                    : AppColors.error,
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Special Requests
          TextField(
            controller: _specialRequestsCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Ghi chú cho chủ nhà (giờ nhận phòng dự kiến, BBQ...)',
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),

          // Price Breakdown Summary (Flat Minimal - no background, no card wrapper)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                _PriceLine(
                  label:
                      'Tiền phòng (${calc.nights} đêm${calc.weekendNights > 0 ? ', ${calc.weekendNights} đêm cuối tuần' : ''})',
                  value: CurrencyFormatter.formatVnd(calc.roomSubtotal),
                ),
                if (calc.extraGuestTotal > 0)
                  _PriceLine(
                    label: 'Phụ thu vượt khách tiêu chuẩn',
                    value: CurrencyFormatter.formatVnd(calc.extraGuestTotal),
                  ),
                if (calc.cleaningFee > 0)
                  _PriceLine(
                    label: 'Phí vệ sinh',
                    value: CurrencyFormatter.formatVnd(calc.cleaningFee),
                  ),
                if (calc.serviceFee > 0)
                  _PriceLine(
                    label: 'Phí dịch vụ',
                    value: CurrencyFormatter.formatVnd(calc.serviceFee),
                  ),
                if (calc.discount > 0)
                  _PriceLine(
                    label: 'Giảm giá ($_appliedCouponCode)',
                    value: '-${CurrencyFormatter.formatVnd(calc.discount)}',
                  ),
                const Divider(height: 16, color: AppColors.divider),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Tổng cộng thanh toán',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatVnd(calc.finalTotal),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
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

  Widget _buildPoliciesCard(Villa villa) {
    final rules = villa.rules ?? const VillaRules();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nội quy chỗ nghỉ & Chính sách hoàn hủy',
            style: AppTypography.sectionHeading.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              _PolicyItem(
                icon: LucideIcons.clock,
                label:
                    'Nhận phòng: ${rules.checkInFrom} – ${rules.checkInUntil}',
              ),
              _PolicyItem(
                icon: LucideIcons.logOut,
                label: 'Trả phòng: Trước ${rules.checkOutBefore}',
              ),
              if (rules.quietHours != null)
                _PolicyItem(
                  icon: LucideIcons.volumeX,
                  label: 'Giờ yên tĩnh: ${rules.quietHours}',
                ),
              _PolicyItem(
                icon: LucideIcons.pawPrint,
                label: rules.allowPets
                    ? 'Cho phép mang thú cưng'
                    : 'Không mang thú cưng',
              ),
              _PolicyItem(
                icon: LucideIcons.shieldCheck,
                label: villa.cancellationPolicyLabelVi,
              ),
            ],
          ),
          if (rules.additionalRules.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final r in rules.additionalRules)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $r',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  final String label;
  final String value;

  const _PriceLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PolicyItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.iconStrong),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _FullscreenGalleryModal extends StatefulWidget {
  final Villa villa;

  const _FullscreenGalleryModal({required this.villa});

  @override
  State<_FullscreenGalleryModal> createState() =>
      _FullscreenGalleryModalState();
}

class _FullscreenGalleryModalState extends State<_FullscreenGalleryModal> {
  String _selectedType = 'all';

  @override
  Widget build(BuildContext context) {
    final images = widget.villa.images.isNotEmpty
        ? widget.villa.images
        : widget.villa.imageUrls
            .map((u) => VillaImage(imageId: u, url: u))
            .toList();

    final availableTypes = <String>{
      for (final img in images)
        if (img.type != null && img.type!.isNotEmpty) img.type!,
    };

    final filtered = _selectedType == 'all'
        ? images
        : images.where((i) => i.type == _selectedType).toList();

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.villa.name} (${filtered.length} ảnh)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: Icon(
                          LucideIcons.x,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (availableTypes.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Tất cả không gian'),
                      selected: _selectedType == 'all',
                      onSelected: (_) => setState(() => _selectedType = 'all'),
                    ),
                    const SizedBox(width: 8),
                    for (final t in availableTypes)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            VillaImage(imageId: '', url: '', type: t)
                                    .typeLabelVi ??
                                t,
                          ),
                          selected: _selectedType == t,
                          onSelected: (_) => setState(() => _selectedType = t),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final img = filtered[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: AppImage(
                            url: img.url,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                      if (img.typeLabelVi != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Không gian: ${img.typeLabelVi}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
