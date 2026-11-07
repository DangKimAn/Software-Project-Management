import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/vietnam_banks.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../host/domain/host_models.dart';
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
    final formatter = ref.read(moneyFormatterProvider);

    final reasonController = TextEditingController();
    final bankNameController = TextEditingController();
    final accountNumberController = TextEditingController();
    final accountNameController = TextEditingController();
    VietnamBank? selectedBank;
    bool hasValidated = false;

    String? validateReason() {
      final text = reasonController.text.trim();
      if (text.isEmpty) {
        return isEn
            ? 'Cancellation reason is required'
            : (isKo ? '취소 사유를 입력해주세요' : 'Vui lòng nhập lý do hủy phòng');
      }
      if (text.length < 5) {
        return isEn
            ? 'Reason must be at least 5 characters'
            : (isKo ? '취소 사유는 5자 이상이어야 합니다' : 'Lý do hủy tối thiểu 5 ký tự');
      }
      return null;
    }

    String? validateBank() {
      if (!booking.isPaid) return null;
      if (selectedBank == null && bankNameController.text.trim().isEmpty) {
        return isEn
            ? 'Please select a receiving bank'
            : (isKo ? '입금받을 은행을 선택해주세요' : 'Vui lòng chọn ngân hàng nhận tiền');
      }
      return null;
    }

    String? validateAccountNumber() {
      if (!booking.isPaid) return null;
      final text = accountNumberController.text.trim();
      if (text.isEmpty) {
        return isEn
            ? 'Account number is required'
            : (isKo ? '계좌번호를 입력해주세요' : 'Vui lòng nhập số tài khoản');
      }
      if (!RegExp(r'^\d{10,12}$').hasMatch(text)) {
        return isEn
            ? 'Account number must be 10 to 12 digits'
            : (isKo ? '계좌번호는 10~12자리 숫자여야 합니다' : 'Số tài khoản phải gồm 10 đến 12 chữ số');
      }
      return null;
    }

    String? validateAccountName() {
      if (!booking.isPaid) return null;
      final text = accountNameController.text.trim();
      if (text.isEmpty) {
        return isEn
            ? 'Account owner name is required'
            : (isKo ? '예금주명을 입력해주세요' : 'Vui lòng nhập tên chủ tài khoản');
      }
      if (RegExp(r'[0-9]').hasMatch(text)) {
        return isEn
            ? 'Name cannot contain numbers'
            : (isKo ? '예금주명에 숫자를 포함할 수 없습니다' : 'Tên chủ tài khoản không được chứa chữ số');
      }
      if (text.length < 3) {
        return isEn
            ? 'Name must be at least 3 characters'
            : (isKo ? '예금주명은 3자 이상이어야 합니다' : 'Tên chủ tài khoản tối thiểu 3 ký tự');
      }
      return null;
    }

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          return AlertDialog(
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
                    maxLines: 2,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(250),
                    ],
                    onChanged: (_) {
                      if (hasValidated) setModalState(() {});
                    },
                    style: const TextStyle(fontSize: 13, height: 1.3),
                    decoration: InputDecoration(
                      labelText: isEn
                          ? 'Cancellation reason (required)'
                          : (isKo ? '취소 사유 (필수)' : 'Lý do hủy (bắt buộc)'),
                      hintText: isEn
                          ? 'Change of personal plans, work schedule...'
                          : (isKo ? '개인 일정 변경...' : 'Thay đổi kế hoạch cá nhân, bận việc...'),
                      isDense: true,
                      errorText: hasValidated ? validateReason() : null,
                      errorMaxLines: 2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.textStrong, width: 1.5),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.error),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  if (booking.isPaid) ...[
                    const SizedBox(height: AppSpacing.s16),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBase,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                isEn
                                    ? 'Refund amount:'
                                    : (isKo ? '환불 예상 금액:' : 'Số tiền hoàn dự kiến:'),
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    formatter.formatExactVnd(booking.totalAmount),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  if (formatter.effectiveCurrency.isForeign) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '≈ ${formatter.format(booking.totalAmount).formatted}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(height: 1, color: AppColors.border),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                LucideIcons.shieldCheck,
                                size: 16,
                                color: AppColors.textStrong,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isEn
                                      ? 'This booking was paid. Please provide your bank details so Admin can review and disburse your refund via Napas 24/7.'
                                      : (isKo
                                          ? '결제 완료된 예약입니다. 관리자가 검토 후 Napas 24/7로 송금할 수 있도록 계좌 정보를 입력해주세요.'
                                          : 'Đơn này đã thanh toán. Vui lòng cung cấp số tài khoản ngân hàng để Admin duyệt và hoàn tiền tự động qua Napas 24/7.'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textStrong,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    InkWell(
                      onTap: () async {
                        final picked = await _showBankPickerDialog(
                          context,
                          currentSelection: selectedBank,
                          isEn: isEn,
                        );
                        if (picked != null) {
                          setModalState(() {
                            selectedBank = picked;
                            bankNameController.text =
                                '${picked.shortName} (${picked.code})';
                          });
                          if (hasValidated) setModalState(() {});
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: IgnorePointer(
                        child: TextField(
                          controller: bankNameController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: isEn
                                ? 'Bank name (required)'
                                : 'Tên ngân hàng (bắt buộc)',
                            hintText: isEn
                                ? 'Select bank (e.g. MB, VCB, Techcombank...)'
                                : 'Chọn ngân hàng (VD: MB, VCB, Techcombank...)',
                            isDense: true,
                            errorText: hasValidated ? validateBank() : null,
                            errorMaxLines: 2,
                            prefixIcon: selectedBank != null
                                ? Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: _BankLogoWidget(
                                      bank: selectedBank!,
                                      size: 22,
                                    ),
                                  )
                                : const Icon(
                                    LucideIcons.building2,
                                    size: 18,
                                    color: AppColors.textMuted,
                                  ),
                            suffixIcon: bankNameController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(LucideIcons.x,
                                        size: 16, color: AppColors.textMuted),
                                    onPressed: () {
                                      setModalState(() {
                                        bankNameController.clear();
                                        selectedBank = null;
                                      });
                                      if (hasValidated) setModalState(() {});
                                    },
                                  )
                                : const Icon(
                                    LucideIcons.chevronDown,
                                    size: 18,
                                    color: AppColors.textMuted,
                                  ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: AppColors.textStrong, width: 1.5),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.error),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    TextField(
                      controller: accountNumberController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(12),
                      ],
                      onChanged: (_) {
                        if (hasValidated) setModalState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: isEn
                            ? 'Account number (10 - 12 digits)'
                            : 'Số tài khoản (10 - 12 số)',
                        hintText: isEn ? 'e.g. 0987654321' : 'VD: 0987654321',
                        helperText: isEn ? 'Required: 10 to 12 digits' : 'Bắt buộc: 10 đến 12 chữ số',
                        errorText: hasValidated ? validateAccountNumber() : null,
                        errorMaxLines: 2,
                        isDense: true,
                        prefixIcon: const Icon(
                          LucideIcons.creditCard,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.textStrong, width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.error),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    TextField(
                      controller: accountNameController,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
                        TextInputFormatter.withFunction(
                          (oldValue, newValue) => TextEditingValue(
                            text: newValue.text.toUpperCase(),
                            selection: newValue.selection,
                          ),
                        ),
                        LengthLimitingTextInputFormatter(50),
                      ],
                      onChanged: (_) {
                        if (hasValidated) setModalState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: isEn
                            ? 'Account owner name (no numbers)'
                            : 'Tên chủ tài khoản (không chứa số)',
                        hintText: isEn ? 'e.g. NGUYEN VAN A' : 'VD: NGUYEN VAN A',
                        helperText: isEn ? 'Required: Letters only (auto-uppercase)' : 'Bắt buộc: Chỉ chữ cái (tự động in hoa)',
                        errorText: hasValidated ? validateAccountName() : null,
                        errorMaxLines: 2,
                        isDense: true,
                        prefixIcon: const Icon(
                          LucideIcons.user,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.textStrong, width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.error),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(isEn ? 'Keep booking' : (isKo ? '예약 유지' : 'Giữ đặt phòng')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  setModalState(() {
                    hasValidated = true;
                  });
                  final hasError = validateReason() != null ||
                      validateBank() != null ||
                      validateAccountNumber() != null ||
                      validateAccountName() != null;
                  if (hasError) return;
                  Navigator.of(ctx).pop(true);
                },
                child: Text(isEn ? 'Confirm cancellation' : (isKo ? '취소 확인' : 'Xác nhận hủy')),
              ),
            ],
          );
        },
      ),
    );

    if (shouldCancel == true && mounted) {
      try {
        final repo = ref.read(bookingRepositoryProvider);
        await repo.cancelBooking(
          bookingId: booking.id,
          reason: reasonController.text.trim(),
          bankName: bankNameController.text.trim(),
          accountNumber: accountNumberController.text.trim(),
          accountName: accountNameController.text.trim(),
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
        booking.status == 'completed' ||
        booking.effectiveStatus == 'refunded') {
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

/// Compact widget that renders a bank logo with high reliability:
/// 1. Tries bundled local asset `assets/images/banks/{code}.png` (instant, offline)
/// 2. Falls back to VietQR CDN network URL with custom headers
/// 3. Falls back to vector `LucideIcons.building2` if unavailable
class _BankLogoWidget extends StatelessWidget {
  final VietnamBank bank;
  final double size;

  const _BankLogoWidget({
    required this.bank,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = 'assets/images/banks/${bank.code.toLowerCase()}.png';
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        if (bank.logo != null && bank.logo!.isNotEmpty) {
          return Image.network(
            bank.logo!,
            width: size,
            height: size,
            fit: BoxFit.contain,
            headers: const {'User-Agent': 'Mozilla/5.0'},
            errorBuilder: (_, __, ___) => Icon(
              LucideIcons.building2,
              size: size * 0.75,
              color: AppColors.textStrong,
            ),
          );
        }
        return Icon(
          LucideIcons.building2,
          size: size * 0.75,
          color: AppColors.textStrong,
        );
      },
    );
  }
}

/// Displays bank picker as a centered modal Dialog on the root navigator,
/// ensuring it renders directly ON TOP of the Cancel Booking dialog.
Future<VietnamBank?> _showBankPickerDialog(
  BuildContext context, {
  VietnamBank? currentSelection,
  required bool isEn,
}) {
  return showDialog<VietnamBank>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    builder: (modalCtx) => _BankPickerDialog(
      currentSelection: currentSelection,
      isEn: isEn,
    ),
  );
}

class _BankPickerDialog extends StatefulWidget {
  final VietnamBank? currentSelection;
  final bool isEn;

  const _BankPickerDialog({
    this.currentSelection,
    required this.isEn,
  });

  @override
  State<_BankPickerDialog> createState() => _BankPickerDialogState();
}

class _BankPickerDialogState extends State<_BankPickerDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEn = widget.isEn;
    final filteredBanks = kDefaultVietnamBanks.where((b) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return b.code.toLowerCase().contains(q) ||
          b.shortName.toLowerCase().contains(q) ||
          b.name.toLowerCase().contains(q) ||
          (b.bin != null && b.bin!.contains(q));
    }).toList();

    return Dialog(
      backgroundColor: AppColors.surfaceBase,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 440,
          maxHeight: 560,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isEn ? 'Select bank' : 'Chọn ngân hàng',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textStrong,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20, color: AppColors.textStrong),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: TextField(
                controller: _searchCtrl,
                autofocus: false,
                onChanged: (val) => setState(() => _query = val.trim()),
                decoration: InputDecoration(
                  hintText: isEn
                      ? 'Search bank (e.g. MB, VCB, Techcombank...)'
                      : 'Tìm ngân hàng (VD: MB, VCB, Techcombank...)',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.textMuted),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 16, color: AppColors.textMuted),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.textStrong, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: filteredBanks.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.searchX, size: 36, color: AppColors.textMuted),
                            const SizedBox(height: 10),
                            Text(
                              isEn
                                  ? 'No matching banks found'
                                  : 'Không tìm thấy ngân hàng phù hợp',
                              style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                            ),
                            if (_query.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  side: const BorderSide(color: AppColors.border),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop(VietnamBank(
                                    code: _query.toUpperCase(),
                                    name: _query,
                                    shortName: _query,
                                  ));
                                },
                                icon: const Icon(LucideIcons.check, size: 16, color: AppColors.textStrong),
                                label: Text(
                                  isEn ? 'Use "$_query"' : 'Sử dụng "$_query"',
                                  style: const TextStyle(color: AppColors.textStrong),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: filteredBanks.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 64, color: AppColors.border),
                        itemBuilder: (ctx, index) {
                          final bank = filteredBanks[index];
                          final isSelected = widget.currentSelection?.code == bank.code;
                          return InkWell(
                            onTap: () => Navigator.of(context).pop(bank),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceBase,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.border,
                                      ),
                                    ),
                                    child: _BankLogoWidget(bank: bank, size: 28),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${bank.shortName} (${bank.code})',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? AppColors.primary
                                                : AppColors.textStrong,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          bank.name,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMuted,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      LucideIcons.check,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
