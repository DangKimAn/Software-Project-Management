import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/storage/preferences_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/domain/entities/user.dart';
import '../../domain/entities/booking.dart';
import '../../domain/repositories/booking_repository.dart';

/// Standalone, testable Payment Result verification widget used by `PaymentResultScreen`.
///
/// Guarantees BUG-03 security & business rules:
/// - Never trusts query string `status=paid` without verifying against `BookingRepository.getPaymentById` and `BookingRepository.getBookingById`.
/// - When network fails during verification, displays `"Chưa xác nhận được giao dịch"` (`unverified`) instead of fake success or failure.
/// - Re-verifies on `AppLifecycleState.resumed` without creating duplicate payment transactions.
/// - Supports `pending`, `paid`, `failed`, `cancelled`, `expired`, `refund_pending`, `refunded`, `unverified`.
class PaymentVerificationCard extends StatefulWidget {
  final BookingRepository repository;
  final String? bookingId;
  final String? paymentId;
  final String initialStatus;
  final String? method;
  final int? amount;
  final void Function(String resolvedStatus)? onStatusVerified;
  final VoidCallback? onRetryPayment;
  final VoidCallback? onViewTrips;
  final VoidCallback? onGoHome;

  const PaymentVerificationCard({
    super.key,
    required this.repository,
    this.bookingId,
    this.paymentId,
    this.initialStatus = 'pending',
    this.method,
    this.amount,
    this.onStatusVerified,
    this.onRetryPayment,
    this.onViewTrips,
    this.onGoHome,
  });

  @override
  State<PaymentVerificationCard> createState() =>
      _PaymentVerificationCardState();
}

class _PaymentVerificationCardState extends State<PaymentVerificationCard>
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
    final rawInitial = widget.initialStatus.trim().toLowerCase();
    if (rawInitial == 'paid' ||
        rawInitial == 'success' ||
        rawInitial == 'confirmed' ||
        rawInitial.isEmpty) {
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
      final rawInitial = widget.initialStatus.trim().toLowerCase();
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

    PaymentSessionResult? fetchedPayment;
    Booking? fetchedBooking;
    Object? lastError;

    if (resolvedPaymentId.isNotEmpty) {
      try {
        fetchedPayment = await widget.repository.getPaymentById(
          resolvedPaymentId,
        );
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
        fetchedBooking = await widget.repository.getBookingById(
          bookingIdToLookup,
        );
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

    widget.onStatusVerified?.call(resolvedStatus);

    if (resolvedStatus == 'pending' && _pollCount < _maxPollAttempts) {
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
        final initialHint = widget.initialStatus.trim().toLowerCase();
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
              'Hệ thống đang đồng bộ kết quả từ cổng thanh toán. Trạng thái sẽ tự động cập nhật khi có phản hồi từ máy chủ.',
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
          subtitle: _paymentRecord?.latePaymentReason ??
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
          icon: LucideIcons.triangleAlert,
          title: 'Thanh toán không thành công',
          subtitle:
              'Giao dịch chưa thể hoàn tất. Bạn có thể thử thanh toán lại bằng VNPay hoặc MoMo.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
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

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        children: [
          Icon(
            meta.icon,
            size: 48,
            color: AppColors.iconStrong,
          ),
          const SizedBox(height: 16),
          Text(
            meta.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            meta.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          if (_isVerifying) ...[
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Đang kiểm tra trạng thái từ máy chủ...',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          const Divider(color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                if (effectiveBookingId.isNotEmpty)
                  _KvRow(
                    label: 'Mã đơn đặt phòng',
                    value: '#$effectiveBookingId',
                  ),
                if (effectivePaymentId.isNotEmpty)
                  _KvRow(
                    label: 'Mã giao dịch',
                    value: effectivePaymentId,
                  ),
                if (effectiveMethod.isNotEmpty)
                  _KvRow(
                    label: 'Phương thức',
                    value: effectiveMethod.toUpperCase(),
                  ),
                if (effectiveAmount > 0)
                  _KvRow(
                    label: 'Số tiền',
                    value: CurrencyFormatter.formatVnd(effectiveAmount),
                  ),
                if (_bookingRecord != null)
                  _KvRow(
                    label: 'Trạng thái đơn phòng',
                    value: _bookingRecord!.statusDisplay,
                  ),
              ],
            ),
          ),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              if (canReverify)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: OutlinedButton.icon(
                    onPressed: _isVerifying
                        ? null
                        : () => _verifyTransaction(resetPollCount: true),
                    icon: const Icon(
                      LucideIcons.refreshCw,
                      size: 16,
                      color: AppColors.iconStrong,
                    ),
                    label: const Text('Kiểm tra lại trạng thái'),
                  ),
                ),
              if (canRetryPayment && widget.onRetryPayment != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: ElevatedButton(
                    onPressed: widget.onRetryPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Thử thanh toán lại'),
                  ),
                ),
              if (widget.onViewTrips != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: ElevatedButton(
                    onPressed: widget.onViewTrips,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textPrimary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Xem chuyến đi của tôi'),
                  ),
                ),
              if (widget.onGoHome != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: OutlinedButton(
                    onPressed: widget.onGoHome,
                    child: const Text('Về Trang chủ'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Testable Profile Summary & Edit Form widget used for BUG-22 verification.
class ProfileAccountEditorCard extends StatefulWidget {
  final User user;
  final Future<User> Function({
    String? fullName,
    String? phone,
    String? bio,
    String? location,
    String? job,
    String? dreamDestination,
    String? school,
    List<String>? languages,
    String? avatarUrl,
  }) onUpdateProfile;
  final Future<User> Function({required String url, String? key})?
      onUpdateAvatar;

  const ProfileAccountEditorCard({
    super.key,
    required this.user,
    required this.onUpdateProfile,
    this.onUpdateAvatar,
  });

  @override
  State<ProfileAccountEditorCard> createState() =>
      _ProfileAccountEditorCardState();
}

class _ProfileAccountEditorCardState extends State<ProfileAccountEditorCard> {
  late User _currentUser;
  Map<String, String>? _draft;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
  }

  @override
  void didUpdateWidget(covariant ProfileAccountEditorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) {
      _currentUser = widget.user;
    }
  }

  String _val(String? v) =>
      (v != null && v.trim().isNotEmpty) ? v.trim() : 'Chưa cập nhật';

  Future<void> _openEditModal() async {
    final fullNameCtrl = TextEditingController(
      text: _draft?['fullName'] ?? _currentUser.fullName,
    );
    final phoneCtrl = TextEditingController(
      text: _draft?['phone'] ?? _currentUser.phone ?? '',
    );
    final locationCtrl = TextEditingController(
      text: _draft?['location'] ?? _currentUser.location ?? '',
    );
    final dreamCtrl = TextEditingController(
      text: _draft?['dreamDestination'] ?? _currentUser.dreamDestination ?? '',
    );
    final jobCtrl = TextEditingController(
      text: _draft?['job'] ?? _currentUser.job ?? '',
    );
    final schoolCtrl = TextEditingController(
      text: _draft?['school'] ?? _currentUser.school ?? '',
    );
    final languagesCtrl = TextEditingController(
      text: _draft?['languages'] ?? _currentUser.languages.join(', '),
    );
    final bioCtrl = TextEditingController(
      text: _draft?['bio'] ?? _currentUser.bio ?? '',
    );
    final avatarCtrl = TextEditingController(
      text: _draft?['avatarUrl'] ?? _currentUser.avatarUrl ?? '',
    );

    bool isSaving = false;
    String? errorMsg;

    void saveDraft() {
      _draft = {
        'fullName': fullNameCtrl.text,
        'phone': phoneCtrl.text,
        'location': locationCtrl.text,
        'dreamDestination': dreamCtrl.text,
        'job': jobCtrl.text,
        'school': schoolCtrl.text,
        'languages': languagesCtrl.text,
        'bio': bioCtrl.text,
        'avatarUrl': avatarCtrl.text,
      };
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> submit() async {
              saveDraft();
              setModalState(() {
                isSaving = true;
                errorMsg = null;
              });
              try {
                final newAvatar = avatarCtrl.text.trim();
                if (newAvatar.isNotEmpty &&
                    newAvatar != (_currentUser.avatarUrl ?? '') &&
                    widget.onUpdateAvatar != null) {
                  await widget.onUpdateAvatar!(url: newAvatar);
                }
                final langs = languagesCtrl.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                final updated = await widget.onUpdateProfile(
                  fullName: fullNameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  bio: bioCtrl.text.trim(),
                  location: locationCtrl.text.trim(),
                  job: jobCtrl.text.trim(),
                  dreamDestination: dreamCtrl.text.trim(),
                  school: schoolCtrl.text.trim(),
                  languages: langs,
                  avatarUrl: newAvatar.isNotEmpty ? newAvatar : null,
                );
                _draft = null;
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                if (mounted) {
                  setState(() => _currentUser = updated);
                }
              } catch (e) {
                if (!ctx.mounted) return;
                setModalState(() {
                  isSaving = false;
                  errorMsg = e.toString().replaceFirst('Exception: ', '');
                });
              }
            }

            return Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorMsg != null)
                      Text(
                        errorMsg!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    TextField(
                      controller: fullNameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Họ và tên *'),
                    ),
                    TextField(
                      controller: locationCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Nơi sinh sống'),
                    ),
                    TextField(
                      controller: dreamCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Nơi tôi luôn muốn đến'),
                    ),
                    TextField(
                      controller: jobCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Công việc / Nghề nghiệp'),
                    ),
                    TextField(
                      controller: schoolCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Trường học'),
                    ),
                    TextField(
                      controller: languagesCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Ngôn ngữ giao tiếp'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: isSaving ? null : submit,
                      child: const Text('Lưu thay đổi'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                _currentUser.fullName,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: OutlinedButton(
                  onPressed: _openEditModal,
                  child: const Text('Sửa hồ sơ'),
                ),
              ),
            ],
          ),
          _KvRow(label: 'Nơi sinh sống', value: _val(_currentUser.location)),
          _KvRow(label: 'Công việc của tôi', value: _val(_currentUser.job)),
          _KvRow(
            label: 'Nơi tôi luôn muốn đến',
            value: _val(_currentUser.dreamDestination),
          ),
          _KvRow(
            label: 'Nơi tôi từng theo học',
            value: _val(_currentUser.school),
          ),
          _KvRow(
            label: 'Ngôn ngữ của tôi',
            value: _currentUser.languages.isNotEmpty
                ? _currentUser.languages.join(', ')
                : 'Chưa cập nhật',
          ),
          _KvRow(
            label: 'Xác minh danh tính',
            value: _currentUser.isVerified ? 'Đã xác minh' : 'Chưa xác minh',
          ),
        ],
      ),
    );
  }
}

/// Testable responsive Trip card enforcing `booking.canCancel` & `booking.canPayNow`.
class ResponsiveTripBookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback? onCancel;
  final VoidCallback? onPay;

  const ResponsiveTripBookingCard({
    super.key,
    required this.booking,
    this.onCancel,
    this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  booking.propertyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(booking.statusDisplay),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Text('${booking.checkInDate} → ${booking.checkOutDate}'),
              Text('${booking.nights} đêm • ${booking.guestCount} khách'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(CurrencyFormatter.formatVnd(booking.totalAmount)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (booking.canPayNow)
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: FilledButton(
                        onPressed: onPay,
                        child: const Text('Thanh toán'),
                      ),
                    ),
                  if (booking.canCancel)
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: OutlinedButton(
                        onPressed: onCancel,
                        child: const Text('Hủy phòng'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Testable Multi-Booking Queue & Result view widget for BUG-19 verification.
class MultiBookingQueueEditor extends StatefulWidget {
  final PreferencesService prefs;
  final BookingRepository repository;

  const MultiBookingQueueEditor({
    super.key,
    required this.prefs,
    required this.repository,
  });

  @override
  State<MultiBookingQueueEditor> createState() =>
      _MultiBookingQueueEditorState();
}

class _MultiBookingQueueEditorState extends State<MultiBookingQueueEditor> {
  late List<BookingQueueItem> _queue;
  List<Booking> _createdBookings = [];
  Map<int, String> _itemErrors = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _queue = widget.prefs.getBookingQueue();
  }

  Future<void> _updateGuests(int index, BookingQueueItem item, int next) async {
    final updated = item.copyWith(guestsCount: next.clamp(1, item.maxGuests));
    final list = await widget.prefs.updateBookingQueueItem(updated);
    setState(() {
      _queue = list;
      _itemErrors.remove(index);
    });
  }

  Future<void> _submitBulk() async {
    try {
      final created = await widget.repository.createBulkBookings(
        items: _queue
            .map(
              (item) => {
                'listingId': int.tryParse(item.listingId) ?? item.listingId,
                'checkInDate': item.checkIn,
                'checkOutDate': item.checkOut,
                'guestsCount': item.guestsCount,
              },
            )
            .toList(),
      );
      await widget.prefs.clearBookingQueue();
      setState(() {
        _queue = [];
        _createdBookings = created;
        _errorMessage = null;
        _itemErrors = {};
      });
    } on BulkBookingException catch (e) {
      final map = <int, String>{};
      for (final err in e.itemErrors) {
        map[err.index] = err.message;
      }
      setState(() {
        _errorMessage = e.message;
        _itemErrors = map;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_createdBookings.isNotEmpty) {
      return SingleChildScrollView(
        child: Column(
          children: [
            for (int i = 0; i < _createdBookings.length; i++)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Căn #${i + 1} • Mã đơn #${_createdBookings[i].id}',
                    ),
                    Text(_createdBookings[i].propertyName),
                    if (_createdBookings[i].canPayNow)
                      const Text('Thanh toán đơn này'),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          if (_errorMessage != null) Text(_errorMessage!),
          for (int i = 0; i < _queue.length; i++)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_queue[i].title),
                  Text(
                    'Tạm tính: ${CurrencyFormatter.formatVnd(_queue[i].calculatePriceEstimate().estimatedTotal)}',
                  ),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Số khách:'),
                      IconButton(
                        onPressed: _queue[i].guestsCount > 1
                            ? () => _updateGuests(
                                  i,
                                  _queue[i],
                                  _queue[i].guestsCount - 1,
                                )
                            : null,
                        icon: const Icon(LucideIcons.minus, size: 16),
                      ),
                      Text('${_queue[i].guestsCount}/${_queue[i].maxGuests}'),
                      IconButton(
                        onPressed: _queue[i].guestsCount < _queue[i].maxGuests
                            ? () => _updateGuests(
                                  i,
                                  _queue[i],
                                  _queue[i].guestsCount + 1,
                                )
                            : null,
                        icon: const Icon(LucideIcons.plus, size: 16),
                      ),
                    ],
                  ),
                  if (_itemErrors[i] != null) Text(_itemErrors[i]!),
                ],
              ),
            ),
          ElevatedButton(
            onPressed: _submitBulk,
            child: Text('Xác nhận đặt ${_queue.length} căn'),
          ),
        ],
      ),
    );
  }
}

class _KvRow extends StatelessWidget {
  final String label;
  final String value;

  const _KvRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label)),
          const SizedBox(width: 8),
          Flexible(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
