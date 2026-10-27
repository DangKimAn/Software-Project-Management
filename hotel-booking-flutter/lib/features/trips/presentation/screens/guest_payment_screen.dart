import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_header_footer.dart';
import '../../../../shared/widgets/app_image.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../domain/entities/booking.dart';
import '../view_models/trips_view_model.dart';

/// Complete port of `Source goc/frontend/src/views/pages/GuestPayment/index.tsx` (`/thanh-toan/:bookingId`).
class GuestPaymentScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final Future<bool> Function(Uri uri)? externalUrlLauncher;

  const GuestPaymentScreen({
    super.key,
    required this.bookingId,
    this.externalUrlLauncher,
  });

  @override
  ConsumerState<GuestPaymentScreen> createState() => _GuestPaymentScreenState();
}

class _GuestPaymentScreenState extends ConsumerState<GuestPaymentScreen>
    with WidgetsBindingObserver {
  String _selectedMethod = 'vnpay'; // 'vnpay' | 'momo'
  int _remainingSeconds = 0;
  Timer? _countdownTimer;
  String? _initializedForBookingKey;
  bool _isProcessing = false;
  bool _isVerifyingResume = false;
  String? _errorMessage;
  PaymentSessionResult? _activePaymentSession;

  // Coupon validation state (if guest validates a coupon code before payment)
  final TextEditingController _couponController = TextEditingController();
  bool _isValidatingCoupon = false;
  CouponValidationResult? _couponResult;
  String? _couponError;

  static const List<PaymentMethodAvailability> _defaultMethodAvailability = [
    PaymentMethodAvailability(
      method: 'vnpay',
      label: 'VNPay',
      available: true,
    ),
    PaymentMethodAvailability(
      method: 'momo',
      label: 'MoMo',
      available: false,
      unavailableReason:
          'MoMo chưa được cấu hình trên máy chủ. Vui lòng chọn VNPay.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _couponController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _activePaymentSession != null) {
      _verifyActivePaymentOnResume();
    }
  }

  Future<void> _verifyActivePaymentOnResume() async {
    final session = _activePaymentSession;
    if (session == null || _isVerifyingResume || !mounted) return;

    setState(() {
      _isVerifyingResume = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(bookingRepositoryProvider);
      final verifiedPayment = await repo.getPaymentById(session.paymentId);
      final verifiedBooking = await repo.getBookingById(widget.bookingId);

      if (!mounted) return;
      setState(() => _isVerifyingResume = false);

      final resolvedStatus = _resolveVerifiedStatus(
        payment: verifiedPayment,
        booking: verifiedBooking,
      );

      ref.invalidate(myBookingsProvider);
      ref.invalidate(bookingDetailProvider(widget.bookingId));

      context.go(
        '/thanh-toan/ket-qua?bookingId=${widget.bookingId}&paymentId=${session.paymentId}&method=${session.method}&status=$resolvedStatus&amount=${verifiedPayment?.amount ?? session.amount}',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isVerifyingResume = false;
        _errorMessage =
            'Chưa xác nhận được giao dịch. Vui lòng kiểm tra kết nối mạng và thử xác minh lại.';
      });
    }
  }

  String _resolveVerifiedStatus({
    PaymentSessionResult? payment,
    Booking? booking,
  }) {
    if (payment != null) {
      if (payment.isRefundPending) return 'refund_pending';
      if (payment.isRefunded) return 'refunded';
      if (payment.isPaid) return 'paid';
      if (payment.isExpired) return 'expired';
      if (payment.isCancelled) return 'cancelled';
      if (payment.isFailed) return 'failed';
    }
    if (booking != null) {
      if (booking.effectiveStatus == 'refund_pending') return 'refund_pending';
      if (booking.effectiveStatus == 'refunded') return 'refunded';
      if (booking.isPaid) return 'paid';
      if (booking.isExpired) return 'expired';
      if (booking.isCancelled) return 'cancelled';
    }
    return 'pending';
  }

  void _syncCountdown(Booking booking) {
    final bookingKey =
        '${booking.id}_${booking.status}_${booking.paymentStatus}_${booking.paymentDeadline?.toIso8601String()}_${booking.remainingPaymentSeconds}';
    if (_initializedForBookingKey == bookingKey) return;
    _initializedForBookingKey = bookingKey;

    _countdownTimer?.cancel();
    _remainingSeconds = booking.computeRemainingPaymentSeconds();

    if (_remainingSeconds <= 0) {
      _remainingSeconds = 0;
      return;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (booking.paymentDeadline != null) {
        final next = booking.computeRemainingPaymentSeconds();
        if (next <= 0) {
          timer.cancel();
          setState(() => _remainingSeconds = 0);
        } else {
          setState(() => _remainingSeconds = next);
        }
      } else {
        if (_remainingSeconds <= 1) {
          timer.cancel();
          setState(() => _remainingSeconds = 0);
        } else {
          setState(() => _remainingSeconds--);
        }
      }
    });
  }

  String _formatCountdown(int seconds) {
    final clamped = seconds > 0 ? seconds : 0;
    final m = (clamped ~/ 60).toString().padLeft(2, '0');
    final s = (clamped % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatDisplayDate(String raw) {
    final trimmed = raw.trim();
    final parts = trimmed.split('-');
    if (parts.length == 3 && parts[0].length == 4) {
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return trimmed;
  }

  Future<void> _handleValidateCoupon(Booking booking) async {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _couponResult = null;
        _couponError = 'Vui lòng nhập mã giảm giá.';
      });
      return;
    }

    setState(() {
      _isValidatingCoupon = true;
      _couponError = null;
    });

    try {
      final result = await ref.read(bookingRepositoryProvider).validateCoupon(
            code: code,
            bookingAmount: booking.subtotalAmount > 0
                ? booking.subtotalAmount
                : booking.totalAmount,
            listingId: booking.listingId,
          );
      if (!mounted) return;
      setState(() {
        _isValidatingCoupon = false;
        if (result.valid && result.discountAmount > 0) {
          _couponResult = result;
          _couponError = null;
        } else {
          _couponResult = null;
          _couponError = result.message ??
              CouponValidationResult.localizeRejectionReason(result.reason) ??
              'Mã giảm giá không hợp lệ.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isValidatingCoupon = false;
        _couponResult = null;
        _couponError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _submitPayment(
    Booking booking,
    List<PaymentMethodAvailability> methods,
  ) async {
    if (_isProcessing) return;

    if (booking.isPaid) {
      setState(() {
        _errorMessage = 'Đơn đặt phòng này đã được thanh toán.';
      });
      return;
    }

    if (booking.isCancelled && !booking.isExpired) {
      setState(() {
        _errorMessage =
            'Đơn đặt phòng đã bị hủy (${booking.statusDisplay}). Không thể tiếp tục thanh toán.';
      });
      return;
    }

    if (_remainingSeconds <= 0 || booking.isExpired || !booking.canPayNow) {
      setState(() {
        _errorMessage =
            'Thời gian giữ chỗ thanh toán đã hết hạn. Vui lòng tạo lại đơn đặt phòng mới.';
      });
      return;
    }

    final selectedMethodMeta = methods.firstWhere(
      (m) => m.method == _selectedMethod,
      orElse: () => PaymentMethodAvailability(
        method: _selectedMethod,
        label: _selectedMethod.toUpperCase(),
        available: true,
      ),
    );

    if (!selectedMethodMeta.available) {
      setState(() {
        _errorMessage = selectedMethodMeta.unavailableReason ??
            'Phương thức thanh toán này hiện không khả dụng.';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Reuse existing pending session if user already created one for this method and booking
      PaymentSessionResult paymentSession;
      if (_activePaymentSession != null &&
          _activePaymentSession!.bookingId == booking.id &&
          _activePaymentSession!.method == _selectedMethod &&
          _activePaymentSession!.isPending &&
          _activePaymentSession!.paymentUrl != null &&
          _activePaymentSession!.paymentUrl!.isNotEmpty) {
        paymentSession = _activePaymentSession!;
      } else {
        paymentSession =
            await ref.read(bookingRepositoryProvider).createPayment(
                  bookingId: booking.id,
                  method: _selectedMethod,
                );
        _activePaymentSession = paymentSession;
      }

      if (!mounted) return;

      final rawUrl = paymentSession.paymentUrl?.trim() ?? '';
      final uri = Uri.tryParse(rawUrl);
      final isValidGatewayUrl = uri != null &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;

      if (!isValidGatewayUrl) {
        setState(() {
          _isProcessing = false;
          _errorMessage =
              'Không nhận được đường dẫn cổng thanh toán hợp lệ từ máy chủ.';
        });
        return;
      }

      final launcher = widget.externalUrlLauncher ??
          ((Uri target) =>
              launchUrl(target, mode: LaunchMode.externalApplication));
      final launched = await launcher(uri).catchError((_) => false);

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (!launched) {
        setState(() {
          _errorMessage =
              'Không thể mở cổng thanh toán ngoài trình duyệt. Vui lòng thử lại.';
        });
        return;
      }

      ref.invalidate(myBookingsProvider);
      ref.invalidate(bookingDetailProvider(widget.bookingId));

      // CRITICAL BUG-03 FIX:
      // NEVER set status = 'paid' after launchUrl()!
      // Navigate with the real initial session status ('pending') so PaymentResultScreen
      // verifies the transaction via GET /api/payments/:paymentId and GET /api/bookings/:bookingId.
      final initialStatus = paymentSession.paymentStatus.toLowerCase() == 'paid'
          ? 'pending'
          : paymentSession.paymentStatus.toLowerCase();
      final effectiveAmount = paymentSession.amount > 0
          ? paymentSession.amount
          : booking.totalAmount;

      context.go(
        '/thanh-toan/ket-qua?bookingId=${booking.id}&paymentId=${paymentSession.paymentId}&method=${paymentSession.method}&status=$initialStatus&amount=$effectiveAmount',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(bookingDetailProvider(widget.bookingId));
    final methodsAsync = ref.watch(paymentMethodsProvider);
    final methods =
        methodsAsync.valueOrNull != null && methodsAsync.valueOrNull!.isNotEmpty
            ? methodsAsync.valueOrNull!
            : _defaultMethodAvailability;

    // Ensure _selectedMethod points to an available gateway if current selection is unavailable
    final selectedMeta = methods.firstWhere(
      (m) => m.method == _selectedMethod,
      orElse: () => methods.first,
    );
    if (!selectedMeta.available) {
      final firstAvailable = methods.where((m) => m.available).firstOrNull;
      if (firstAvailable != null && firstAvailable.method != _selectedMethod) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _selectedMethod = firstAvailable.method);
          }
        });
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const AppTopHeader(currentPath: '/account/trips'),
            Expanded(
              child: bookingAsync.when(
                loading: () => const AppLoading(
                  message: 'Đang tải thông tin thanh toán đặt phòng...',
                ),
                error: (err, _) => AppErrorView(
                  message: err.toString().replaceFirst('Exception: ', ''),
                  onRetry: () =>
                      ref.invalidate(bookingDetailProvider(widget.bookingId)),
                ),
                data: (booking) {
                  if (booking == null) {
                    return const AppErrorView(
                      title: 'Không tìm thấy đơn đặt phòng',
                      message: 'Đơn đặt phòng không tồn tại hoặc đã hết hạn.',
                    );
                  }

                  _syncCountdown(booking);
                  final pb = booking.priceBreakdown;
                  final isHoldExpired = !booking.isPaid &&
                      (_remainingSeconds <= 0 || booking.isExpired);
                  final canSubmit = booking.canPayNow &&
                      !isHoldExpired &&
                      selectedMeta.available &&
                      !_isProcessing &&
                      !_isVerifyingResume;

                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
                    ),
                    child: Column(
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 920),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 20,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Countdown Lock / Status Banner (Neutral icon, no decorative circle)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceBase,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: booking.isPaid
                                            ? AppColors.success
                                                .withValues(alpha: 0.35)
                                            : (isHoldExpired ||
                                                    booking.isCancelled
                                                ? AppColors.error
                                                    .withValues(alpha: 0.35)
                                                : AppColors.borderSoft),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Icon(
                                          booking.isPaid
                                              ? LucideIcons.circleCheck
                                              : (isHoldExpired ||
                                                      booking.isCancelled
                                                  ? LucideIcons.timerOff
                                                  : LucideIcons.clock),
                                          size: 18,
                                          color: AppColors.iconStrong,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            booking.isPaid
                                                ? 'Đơn đặt phòng đã được thanh toán thành công.'
                                                : (booking.isCancelled &&
                                                        !booking.isExpired
                                                    ? 'Đơn đặt phòng đã bị hủy (${booking.statusDisplay}).'
                                                    : (!isHoldExpired
                                                        ? 'Hệ thống đang giữ lịch phòng cho bạn. Hoàn tất thanh toán trong:'
                                                        : 'Thời gian giữ chỗ đã hết hạn.')),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              height: 1.35,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        if (!booking.isPaid &&
                                            (!booking.isCancelled ||
                                                booking.isExpired)) ...[
                                          const SizedBox(width: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.25),
                                              ),
                                            ),
                                            child: Text(
                                              _formatCountdown(
                                                _remainingSeconds,
                                              ),
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),

                                  const Text(
                                    'Xác nhận & Thanh toán kỳ nghỉ',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  // Booking Summary Card
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.borderSoft,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: SizedBox(
                                                width: 96,
                                                height: 76,
                                                child: AppImage(
                                                  url: booking.coverImageUrl ??
                                                      'assets/images/NDT05929-HDR1.jpg',
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    booking.propertyName,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      height: 1.3,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    'Mã đơn: #${booking.id} • ${booking.statusDisplay}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    '${_formatDisplayDate(booking.checkInDate)} → ${_formatDisplayDate(booking.checkOutDate)}',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${booking.nights} đêm • ${booking.guestCount} khách',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          child: Divider(
                                            height: 1,
                                            color: AppColors.divider,
                                          ),
                                        ),
                                        if (pb != null) ...[
                                          _PaymentDetailRow(
                                            label:
                                                'Tiền phòng (${booking.nights} đêm)',
                                            value: CurrencyFormatter.formatVnd(
                                              pb.baseNightsAmount,
                                            ),
                                          ),
                                          if (pb.weekendSurchargeAmount > 0)
                                            _PaymentDetailRow(
                                              label: 'Phụ thu cuối tuần',
                                              value:
                                                  CurrencyFormatter.formatVnd(
                                                pb.weekendSurchargeAmount,
                                              ),
                                            ),
                                          if (pb.surchargeAmount > 0)
                                            _PaymentDetailRow(
                                              label: 'Phụ thu vượt tiêu chuẩn',
                                              value:
                                                  CurrencyFormatter.formatVnd(
                                                pb.surchargeAmount,
                                              ),
                                            ),
                                          if (pb.extraGuestFeeAmount > 0)
                                            _PaymentDetailRow(
                                              label:
                                                  'Phụ thu khách vượt tiêu chuẩn',
                                              value:
                                                  CurrencyFormatter.formatVnd(
                                                pb.extraGuestFeeAmount,
                                              ),
                                            ),
                                          if (pb.cleaningFee > 0)
                                            _PaymentDetailRow(
                                              label: 'Phí vệ sinh',
                                              value:
                                                  CurrencyFormatter.formatVnd(
                                                pb.cleaningFee,
                                              ),
                                            ),
                                          if (pb.serviceFee > 0)
                                            _PaymentDetailRow(
                                              label: 'Phí dịch vụ',
                                              value:
                                                  CurrencyFormatter.formatVnd(
                                                pb.serviceFee,
                                              ),
                                            ),
                                          if (pb.discountAmount > 0)
                                            _PaymentDetailRow(
                                              label: booking.couponCode !=
                                                          null &&
                                                      booking.couponCode!
                                                          .isNotEmpty
                                                  ? 'Giảm giá (${booking.couponCode})'
                                                  : 'Giảm giá ưu đãi',
                                              value:
                                                  '-${CurrencyFormatter.formatVnd(pb.discountAmount)}',
                                            ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            child: Divider(
                                              height: 1,
                                              color: AppColors.divider,
                                            ),
                                          ),
                                        ],
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            const Flexible(
                                              child: Text(
                                                'Tổng cộng thanh toán',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              CurrencyFormatter.formatVnd(
                                                booking.totalAmount,
                                              ),
                                              style: const TextStyle(
                                                fontSize: 19,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Coupon check section (if guest wants to verify a coupon eligibility)
                                  if (booking.canPayNow && !isHoldExpired) ...[
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: AppColors.borderSoft,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Mã ưu đãi / Giảm giá',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                child: SizedBox(
                                                  height: 46,
                                                  child: TextField(
                                                    controller:
                                                        _couponController,
                                                    textCapitalization:
                                                        TextCapitalization
                                                            .characters,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    decoration: InputDecoration(
                                                      hintText:
                                                          'Nhập mã coupon...',
                                                      hintStyle:
                                                          const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        color:
                                                            AppColors.textMuted,
                                                      ),
                                                      filled: true,
                                                      fillColor:
                                                          AppColors.surfaceBase,
                                                      contentPadding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                        horizontal: 14,
                                                        vertical: 12,
                                                      ),
                                                      enabledBorder:
                                                          OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                        borderSide:
                                                            const BorderSide(
                                                          color:
                                                              AppColors.border,
                                                        ),
                                                      ),
                                                      focusedBorder:
                                                          OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                        borderSide:
                                                            const BorderSide(
                                                          color: AppColors
                                                              .textPrimary,
                                                          width: 1.4,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              SizedBox(
                                                height: 46,
                                                child: OutlinedButton(
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    minimumSize:
                                                        const Size(96, 46),
                                                    foregroundColor:
                                                        AppColors.textPrimary,
                                                    side: const BorderSide(
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    textStyle: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  onPressed: _isValidatingCoupon
                                                      ? null
                                                      : () =>
                                                          _handleValidateCoupon(
                                                            booking,
                                                          ),
                                                  child: Text(
                                                    _isValidatingCoupon
                                                        ? 'Đang kiểm tra...'
                                                        : 'Áp dụng',
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (_couponError != null) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              _couponError!,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.error,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                          if (_couponResult != null &&
                                              _couponResult!.valid) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              'Mã ${_couponResult!.code} hợp lệ: giảm ${CurrencyFormatter.formatVnd(_couponResult!.discountAmount)}${_couponResult!.description != null ? " (${_couponResult!.description})" : ""}.',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.success,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],

                                  // Payment Gateway Selector (`vnpay` | `momo`)
                                  const Text(
                                    'Chọn phương thức thanh toán',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  for (final methodMeta in methods) ...[
                                    _GatewayOptionTile(
                                      value: methodMeta.method,
                                      groupValue: _selectedMethod,
                                      available: methodMeta.available,
                                      title: methodMeta.method == 'vnpay'
                                          ? 'VNPay (QR Pay / Thẻ ATM nội địa / Visa / Master)'
                                          : 'Ví điện tử MoMo',
                                      subtitle: methodMeta.available
                                          ? (methodMeta.method == 'vnpay'
                                              ? 'Xác nhận qua cổng thanh toán VNPay chuẩn bảo mật ngân hàng'
                                              : 'Thanh toán qua ứng dụng MoMo hoặc quét mã QR MoMo')
                                          : (methodMeta.unavailableReason ??
                                              '${methodMeta.label} chưa được cấu hình trên máy chủ.'),
                                      onSelected: methodMeta.available
                                          ? (v) => setState(
                                                () => _selectedMethod = v,
                                              )
                                          : null,
                                    ),
                                    const SizedBox(height: 10),
                                  ],

                                  if (_activePaymentSession != null) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        const Icon(
                                          LucideIcons.refreshCw,
                                          size: 16,
                                          color: AppColors.iconStrong,
                                        ),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'Bạn đã mở cổng thanh toán? Kiểm tra kết quả giao dịch từ máy chủ:',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          style: TextButton.styleFrom(
                                            minimumSize: const Size(48, 48),
                                          ),
                                          onPressed: _isVerifyingResume
                                              ? null
                                              : _verifyActivePaymentOnResume,
                                          child: Text(
                                            _isVerifyingResume
                                                ? 'Đang xác minh...'
                                                : 'Kiểm tra trạng thái',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],

                                  if (_errorMessage != null) ...[
                                    const SizedBox(height: 14),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          LucideIcons.circleAlert,
                                          size: 18,
                                          color: AppColors.iconStrong,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: const TextStyle(
                                              color: AppColors.error,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],

                                  const SizedBox(height: 20),
                                  if (booking.isPaid)
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () =>
                                            context.go('/account/trips'),
                                        icon: const Icon(
                                          LucideIcons.check,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                        label: const Text(
                                          'Xem chuyến đi của tôi',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          elevation: 0,
                                          backgroundColor:
                                              AppColors.primary,
                                          foregroundColor: Colors.white,
                                          minimumSize:
                                              const Size.fromHeight(52),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: canSubmit
                                            ? () => _submitPayment(
                                                  booking,
                                                  methods,
                                                )
                                            : null,
                                        icon: const Icon(
                                          LucideIcons.shieldCheck,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                        label: Text(
                                          _isProcessing
                                              ? 'Đang kết nối cổng thanh toán...'
                                              : (isHoldExpired
                                                  ? 'Đã hết thời gian giữ chỗ'
                                                  : 'Thanh toán ${CurrencyFormatter.formatVnd(booking.totalAmount)} qua ${_selectedMethod.toUpperCase()}'),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          elevation: 0,
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          minimumSize:
                                              const Size.fromHeight(52),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const AppFooter(),
                      ],
                    ),
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

class _PaymentDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _PaymentDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _GatewayOptionTile extends StatelessWidget {
  final String value;
  final String groupValue;
  final bool available;
  final String title;
  final String subtitle;
  final ValueChanged<String>? onSelected;

  const _GatewayOptionTile({
    required this.value,
    required this.groupValue,
    this.available = true,
    required this.title,
    required this.subtitle,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = available && value == groupValue;
    return InkWell(
      onTap: available && onSelected != null ? () => onSelected!(value) : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderSoft,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                !available
                    ? LucideIcons.circleOff
                    : (isSelected
                        ? LucideIcons.circleCheck
                        : LucideIcons.circle),
                size: 20,
                color: !available
                    ? AppColors.iconMuted
                    : (isSelected ? AppColors.iconStrong : AppColors.iconMuted),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: !available
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
