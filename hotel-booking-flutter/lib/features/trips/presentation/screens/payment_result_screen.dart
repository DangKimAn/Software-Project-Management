import '../widgets/payment_result_card.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_header_footer.dart';
import '../../../../shared/widgets/app_semantic_icons.dart';
import '../../domain/entities/booking.dart';
import '../view_models/trips_view_model.dart';

/// Complete port of `Source goc/frontend/src/views/pages/GuestPayment/PaymentResultPage.tsx` (`/thanh-toan/ket-qua`).
///
/// Security & Business Rules (BUG-03):
/// - NEVER trusts query parameter `status=paid` without verifying against backend (`GET /api/payments/:paymentId` and/or `GET /api/bookings/:bookingId`).
/// - Handles callback latency by polling up to 10 times (every 3s) while status is `pending`.
/// - On network error during verification, displays `"Chưa xác nhận được giao dịch"` (`unverified`) instead of fake success or fake failure.
/// - Re-verifies on app resume (`AppLifecycleState.resumed`) without creating duplicate payment transactions.
class PaymentResultScreen extends ConsumerStatefulWidget {
  final String? bookingId;
  final String? paymentId;
  final String status;
  final String? method;
  final int? amount;

  const PaymentResultScreen({
    super.key,
    this.bookingId,
    this.paymentId,
    this.status = 'pending',
    this.method,
    this.amount,
  });

  @override
  ConsumerState<PaymentResultScreen> createState() =>
      _PaymentResultScreenState();
}

class _PaymentResultScreenState extends ConsumerState<PaymentResultScreen>
    with WidgetsBindingObserver {
  static const int _maxPollAttempts = 10;
  static const Duration _pollInterval = Duration(seconds: 3);

  late String _effectiveStatus;
  PaymentSessionResult? _paymentRecord;
  Booking? _bookingRecord;
  bool _isVerifying = false;
  String? _verificationError;
  int _pollCount = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final rawInitial = widget.status.trim().toLowerCase();
    // Never trust query string `status=paid` until verified with backend
    if (rawInitial == 'paid' ||
        rawInitial == 'success' ||
        rawInitial == 'confirmed') {
      _effectiveStatus = 'pending';
    } else if (rawInitial.isEmpty) {
      _effectiveStatus = 'pending';
    } else {
      _effectiveStatus = rawInitial;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verifyTransaction(resetPollCount: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      if (_effectiveStatus == 'pending' || _effectiveStatus == 'unverified') {
        _verifyTransaction(resetPollCount: false);
      }
    }
  }

  Future<void> _verifyTransaction({bool resetPollCount = false}) async {
    if (_isVerifying || !mounted) return;
    _pollTimer?.cancel();
    if (resetPollCount) {
      _pollCount = 0;
    }

    final resolvedPaymentId = (_paymentRecord?.paymentId.isNotEmpty == true)
        ? _paymentRecord!.paymentId
        : (widget.paymentId?.trim() ?? '');
    final resolvedBookingId = (_bookingRecord?.id.isNotEmpty == true)
        ? _bookingRecord!.id
        : (widget.bookingId?.trim() ?? '');

    if (resolvedPaymentId.isEmpty && resolvedBookingId.isEmpty) {
      final rawInitial = widget.status.trim().toLowerCase();
      setState(() {
        _isVerifying = false;
        if (rawInitial == 'paid' ||
            rawInitial == 'success' ||
            rawInitial == 'confirmed') {
          _effectiveStatus = 'unverified';
          _verificationError =
              'Thiếu mã giao dịch hoặc mã đơn đặt phòng để đối chiếu với máy chủ.';
        } else {
          _effectiveStatus = rawInitial.isNotEmpty ? rawInitial : 'unverified';
        }
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _verificationError = null;
    });

    final repo = ref.read(bookingRepositoryProvider);
    PaymentSessionResult? fetchedPayment;
    Booking? fetchedBooking;
    Object? lastError;

    if (resolvedPaymentId.isNotEmpty) {
      try {
        fetchedPayment = await repo.getPaymentById(resolvedPaymentId);
      } catch (e) {
        lastError = e;
      }
    }

    final bookingIdToLookup =
        (fetchedPayment != null && fetchedPayment.bookingId.isNotEmpty)
            ? fetchedPayment.bookingId
            : resolvedBookingId;

    if (bookingIdToLookup.isNotEmpty) {
      try {
        fetchedBooking = await repo.getBookingById(bookingIdToLookup);
      } catch (e) {
        lastError ??= e;
      }
    }

    if (!mounted) return;

    if (fetchedPayment == null && fetchedBooking == null) {
      setState(() {
        _isVerifying = false;
        _effectiveStatus = 'unverified';
        _verificationError =
            lastError?.toString().replaceFirst('Exception: ', '') ??
                'Không thể kết nối máy chủ để xác minh trạng thái giao dịch.';
      });
      return;
    }

    final resolvedStatus = _deriveAuthoritativeStatus(
      payment: fetchedPayment ?? _paymentRecord,
      booking: fetchedBooking ?? _bookingRecord,
    );

    setState(() {
      _paymentRecord = fetchedPayment ?? _paymentRecord;
      _bookingRecord = fetchedBooking ?? _bookingRecord;
      _effectiveStatus = resolvedStatus;
      _isVerifying = false;
      _verificationError = null;
    });

    if (resolvedStatus == 'paid' ||
        resolvedStatus == 'refund_pending' ||
        resolvedStatus == 'refunded') {
      ref.invalidate(myBookingsProvider);
      if (bookingIdToLookup.isNotEmpty) {
        ref.invalidate(bookingDetailProvider(bookingIdToLookup));
      }
    } else if (resolvedStatus == 'pending' && _pollCount < _maxPollAttempts) {
      _pollCount += 1;
      _pollTimer = Timer(_pollInterval, () {
        if (mounted) {
          _verifyTransaction(resetPollCount: false);
        }
      });
    }
  }

  String _deriveAuthoritativeStatus({
    PaymentSessionResult? payment,
    Booking? booking,
  }) {
    if (payment != null) {
      final resultStatus = payment.paymentResultStatus;
      if (resultStatus == 'refund_pending' ||
          resultStatus == 'refunded' ||
          resultStatus == 'paid' ||
          resultStatus == 'failed' ||
          resultStatus == 'cancelled' ||
          resultStatus == 'expired') {
        if (resultStatus == 'pending' && booking != null) {
          // Fall through to check booking
        } else {
          return resultStatus;
        }
      }
    }

    if (booking != null) {
      final bStatus = booking.status;
      if (bStatus == 'paid' ||
          bStatus == 'confirmed' ||
          bStatus == 'checked_in' ||
          bStatus == 'checked_out' ||
          bStatus == 'completed') {
        return 'paid';
      }
      if (bStatus == 'refund_pending') return 'refund_pending';
      if (bStatus == 'refunded') return 'refunded';
      if (booking.isExpired ||
          (bStatus == 'pending_payment' &&
              booking.computeRemainingPaymentSeconds() <= 0)) {
        return 'expired';
      }
      if (booking.isCancelled) {
        return 'cancelled';
      }
      if (bStatus == 'pending_payment') {
        if (payment != null) {
          return payment.paymentResultStatus;
        }
        final initialHint = widget.status.trim().toLowerCase();
        if (initialHint == 'failed' || initialHint == 'cancelled') {
          return initialHint;
        }
        return 'pending';
      }
    }

    if (payment != null) {
      return payment.paymentResultStatus;
    }

    return 'unverified';
  }

  ({
    IconData icon,
    String title,
    String subtitle,
  }) _resolveStatusMeta() {
    switch (_effectiveStatus.toLowerCase()) {
      case 'paid':
      case 'success':
      case 'confirmed':
        return (
          icon: LucideIcons.circleCheck,
          title: 'Thanh toán đặt phòng thành công!',
          subtitle:
              'Đơn đặt phòng của bạn đã được máy chủ xác nhận. Chủ nhà đã nhận được thông báo và sẵn sàng đón tiếp bạn.',
        );
      case 'pending':
        return (
          icon: LucideIcons.clock,
          title: 'Giao dịch đang chờ xác nhận',
          subtitle:
              'Kết quả thanh toán sẽ tự động cập nhật sau khi được xác nhận.',
        );
      case 'unverified':
        return (
          icon: LucideIcons.wifiOff,
          title: 'Chưa xác nhận được giao dịch',
          subtitle: _verificationError ??
              'Tạm thời chưa thể xác minh trạng thái giao dịch với máy chủ. Vui lòng kiểm tra kết nối mạng và thử xác minh lại.',
        );
      case 'expired':
      case 'payment_expired':
        return (
          icon: LucideIcons.timerOff,
          title: 'Hết thời gian giữ chỗ thanh toán',
          subtitle:
              'Phiên giữ chỗ thanh toán đã hết hạn. Vui lòng tạo lại yêu cầu đặt phòng nếu bạn vẫn muốn giữ lịch.',
        );
      case 'refund_pending':
        return (
          icon: LucideIcons.refreshCw,
          title: 'Đang xử lý hoàn tiền',
          subtitle: _paymentRecord?.latePaymentReasonDisplay ??
              'Yêu cầu hoàn tiền cho đơn đặt phòng của bạn đang được xử lý về phương thức thanh toán ban đầu.',
        );
      case 'refunded':
        return (
          icon: LucideIcons.check,
          title: 'Đã hoàn tiền thành công',
          subtitle:
              'Khoản thanh toán của bạn đã được hoàn trả đầy đủ về phương thức thanh toán ban đầu.',
        );
      case 'cancelled':
        return (
          icon: LucideIcons.circleX,
          title: 'Giao dịch thanh toán đã hủy',
          subtitle:
              'Bạn đã hủy thao tác thanh toán hoặc đơn đặt phòng đã bị hủy. Nếu đơn vẫn còn thời hạn giữ chỗ, bạn có thể thanh toán lại.',
        );
      case 'failed':
      default:
        return (
          icon: AppSemanticIcons.errorAlert,
          title: 'Thanh toán không thành công',
          subtitle:
              'Giao dịch chưa thể hoàn tất. Bạn có thể thử thanh toán lại bằng VNPay hoặc MoMo.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = ref.watch(moneyFormatterProvider);
    final isForeign =
        formatter.featureEnabled && formatter.effectiveCurrency.isForeign;
    final isRefundStatus =
        _effectiveStatus == 'refund_pending' || _effectiveStatus == 'refunded';
    final meta = _resolveStatusMeta();
    final effectiveBookingId = (_bookingRecord?.id.isNotEmpty == true)
        ? _bookingRecord!.id
        : (widget.bookingId ?? '');
    final effectivePaymentId = (_paymentRecord?.paymentId.isNotEmpty == true)
        ? _paymentRecord!.paymentId
        : (widget.paymentId ?? '');
    final effectiveMethod = (_paymentRecord?.method.isNotEmpty == true)
        ? _paymentRecord!.method
        : (widget.method ?? '');
    final effectiveAmount =
        (_paymentRecord != null && _paymentRecord!.amount > 0)
            ? _paymentRecord!.amount
            : ((_bookingRecord != null && _bookingRecord!.totalAmount > 0)
                ? _bookingRecord!.totalAmount
                : (widget.amount ?? 0));

    final canRetryPayment = (_effectiveStatus == 'failed' ||
            _effectiveStatus == 'cancelled' ||
            _effectiveStatus == 'pending') &&
        effectiveBookingId.isNotEmpty &&
        (_bookingRecord == null || _bookingRecord!.canPayNow);

    final canReverify =
        _effectiveStatus == 'pending' || _effectiveStatus == 'unverified';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const AppTopHeader(
              currentPath: '/thanh-toan/ket-qua',
              hidePendingBanner: true,
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                          child: PaymentResultCard(
                            icon: meta.icon,
                            title: meta.title,
                            subtitle: meta.subtitle,
                            isVerifying: _isVerifying,
                            details: {
                              if (effectiveBookingId.isNotEmpty)
                                'Mã đặt phòng': '#$effectiveBookingId',
                              if (effectivePaymentId.isNotEmpty)
                                'Mã giao dịch': effectivePaymentId,
                              if (effectiveMethod.isNotEmpty)
                                'Phương thức': effectiveMethod.toUpperCase(),
                              if (_bookingRecord != null)
                                'Đơn đặt phòng': _bookingRecord!.statusDisplay,
                              if (effectiveAmount > 0)
                                'Số tiền': CurrencyFormatter.formatVnd(
                                    effectiveAmount),
                              if (isForeign &&
                                  (effectiveAmount > 0 || isRefundStatus))
                                'Lưu ý tiền tệ': isRefundStatus
                                    ? formatter.l10n.fxRefundInVndNotice
                                    : formatter.l10n.fxChargedInVndNotice,
                            },
                            onRecheck: canReverify
                                ? () => _verifyTransaction(resetPollCount: true)
                                : null,
                            onRetry: canRetryPayment
                                ? () => context
                                    .go('/thanh-toan/$effectiveBookingId')
                                : null,
                            onViewTrips: () => context.go('/account/trips'),
                            onGoHome: () => context.go('/'),
                          ),
                        ),
                      ),
                    ),
                    const AppFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
