import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/errors/app_failure.dart';

import '../../../../l10n/l10n.dart';
import '../../../auth/presentation/view_models/auth_notifier.dart';
import '../view_models/support_view_model.dart';

// CONFLICT-RESOLVED: Tách biệt hoàn toàn giao tiếp dữ liệu qua `supportViewModelProvider`
// và chuẩn hóa đa ngôn ngữ `vi`/`en`/`ko` theo FLUTTER_RULES.md Mục 2 & Mục 15.

/// Biểu mẫu gửi báo cáo / khiếu nại trực tuyến kết nối API thật `POST /api/reports`
/// kèm hiển thị lịch sử báo cáo đã gửi (`GET /api/reports/mine`).
class FeedbackReportFormCard extends ConsumerStatefulWidget {
  const FeedbackReportFormCard({super.key});

  @override
  ConsumerState<FeedbackReportFormCard> createState() =>
      _FeedbackReportFormCardState();
}

class _FeedbackReportFormCardState
    extends ConsumerState<FeedbackReportFormCard> {
  final _formKey = GlobalKey<FormState>();
  final _targetIdCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _targetType = 'booking';
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _targetIdCtrl.dispose();
    _reasonCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Map<String, String> _targetLabels(AppLocalizations l10n) => {
        'booking': l10n.supportReportTargetBooking,
        'listing': l10n.supportReportTargetListing,
        'review': l10n.supportReportTargetReview,
        'user': l10n.supportReportTargetUser,
      };

  Future<void> _submitReport() async {
    if (_isSubmitting) return;
    final l10n = context.l10n;
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final parsedId = int.tryParse(_targetIdCtrl.text.trim()) ?? 0;
    setState(() => _isSubmitting = true);

    try {
      await ref.read(supportViewModelProvider).submitFeedbackReport(
            targetType: _targetType,
            targetId: parsedId,
            reason: _reasonCtrl.text.trim(),
            description: _descCtrl.text.trim(),
          );
      if (!mounted) return;
      _targetIdCtrl.clear();
      _reasonCtrl.clear();
      _descCtrl.clear();
      setState(() {
        _isSubmitting = false;
        _successMessage = l10n.supportReportSuccessMessage;
      });
    } catch (err) {
      if (!mounted) return;
      final msg =
          err is AppFailure ? err.message : l10n.supportReportErrorFallback;
      setState(() {
        _isSubmitting = false;
        _errorMessage = msg;
      });
    }
  }

  String _statusLabel(AppLocalizations l10n, String raw) {
    switch (raw.toLowerCase()) {
      case 'resolved':
        return l10n.supportReportStatusResolved;
      case 'rejected':
        return l10n.supportReportStatusRejected;
      default:
        return l10n.supportReportStatusOpen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = ref.watch(authNotifierProvider).valueOrNull;

    if (user == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surfaceBase,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.supportReportGuestCardTitle,
              style: AppTypography.sectionHeading.copyWith(fontSize: 18),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.supportReportGuestCardBody,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton(
                  key: const ValueKey('report-login-redirect-btn'),
                  onPressed: () => context.push(
                    '/dang-nhap?redirectTo=/ho-tro/khieu-nai-gop-y',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(48, 48),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(l10n.supportReportLoginAction),
                ),
                OutlinedButton(
                  onPressed: () => context.push('/lien-he'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textStrong,
                    minimumSize: const Size(48, 48),
                    shape: const StadiumBorder(),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Text(l10n.supportReportDirectContactAction),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final myReportsAsync = ref.watch(mySupportReportsProvider);
    final labels = _targetLabels(l10n);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.supportReportAuthCardTitle,
              style: AppTypography.sectionHeading.copyWith(fontSize: 18),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.supportReportAuthCardSubtitle,
              style: AppTypography.bodyMuted.copyWith(height: 1.45),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _targetType,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.supportReportTargetGroupLabel,
                border: const OutlineInputBorder(
                  borderRadius: AppRadii.roundedPill,
                ),
              ),
              items: labels.entries
                  .map(
                    (e) => DropdownMenuItem<String>(
                      value: e.key,
                      child: Text(
                        e.value,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _targetType = val);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: const ValueKey('report-target-id-input'),
              controller: _targetIdCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.supportReportTargetIdLabel,
                border: const OutlineInputBorder(
                  borderRadius: AppRadii.roundedPill,
                ),
              ),
              validator: (v) {
                final id = int.tryParse((v ?? '').trim());
                if (id == null || id < 1) {
                  return l10n.supportReportTargetIdError;
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: const ValueKey('report-reason-input'),
              controller: _reasonCtrl,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.supportReportReasonLabel,
                border: const OutlineInputBorder(
                  borderRadius: AppRadii.roundedPill,
                ),
              ),
              validator: (v) {
                final text = (v ?? '').trim();
                if (text.isEmpty) return l10n.supportReportReasonEmptyError;
                if (text.length > 255) return l10n.supportReportReasonMaxError;
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              key: const ValueKey('report-description-input'),
              controller: _descCtrl,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l10n.supportReportDescLabel,
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _errorMessage!,
                style: AppTypography.caption.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_successMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _successMessage!,
                style: AppTypography.caption.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const ValueKey('report-submit-btn'),
              onPressed: _isSubmitting ? null : _submitReport,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(LucideIcons.send, size: 16),
              label: Text(
                _isSubmitting
                    ? l10n.supportReportSubmittingLabel
                    : l10n.supportReportSubmitAction,
              ),
            ),
            myReportsAsync.when(
              data: (reports) {
                if (reports.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(color: AppColors.borderSoft),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.supportReportRecentTitle(reports.length),
                        style: AppTypography.cardTitle.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      for (final r in reports.take(3))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '• [#${r.targetId} - ${r.targetType}] ${r.reason} — ${_statusLabel(l10n, r.status)}',
                            style: AppTypography.bodyMuted.copyWith(
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.only(top: AppSpacing.md),
                child: LinearProgressIndicator(minHeight: 2),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bảng kiểm tra mã ưu đãi trực tuyến kết nối API thật `GET /api/coupons/validate`.
class MemberCouponCheckerCard extends ConsumerStatefulWidget {
  const MemberCouponCheckerCard({super.key});

  @override
  ConsumerState<MemberCouponCheckerCard> createState() =>
      _MemberCouponCheckerCardState();
}

class _MemberCouponCheckerCardState
    extends ConsumerState<MemberCouponCheckerCard> {
  final _codeCtrl = TextEditingController();
  final _amountCtrl = TextEditingController(text: '5000000');
  bool _isChecking = false;
  String? _statusText;
  bool _isValidResult = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkCoupon() async {
    final l10n = context.l10n;
    final code = _codeCtrl.text.trim().toUpperCase();
    final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (code.isEmpty) {
      setState(() {
        _isValidResult = false;
        _statusText = l10n.supportCouponEmptyError;
      });
      return;
    }

    setState(() {
      _isChecking = true;
      _statusText = null;
    });

    try {
      final res = await ref
          .read(supportViewModelProvider)
          .validateMemberCoupon(code: code, bookingAmount: amount);
      if (!mounted) return;
      final formatter = ref.read(moneyFormatterProvider);
      setState(() {
        _isChecking = false;
        _isValidResult = res.valid;
        _statusText = res.valid
            ? l10n.supportCouponValidStatus(
                res.code,
                formatter.formatDiscount(res.discountAmount),
              )
            : (res.message ?? l10n.supportCouponInvalidFallback);
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _isValidResult = false;
        _statusText =
            err is AppFailure ? err.message : l10n.supportCouponCheckError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = ref.watch(authNotifierProvider).valueOrNull;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.supportCouponCardTitle,
            style: AppTypography.sectionHeading.copyWith(fontSize: 18),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            user == null
                ? l10n.supportCouponGuestHint
                : l10n.supportCouponAuthHint,
            style: AppTypography.bodyMuted.copyWith(height: 1.5),
          ),
          const SizedBox(height: AppSpacing.md),
          if (user == null)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton(
                  key: const ValueKey('member-offers-login-btn'),
                  onPressed: () => context.push(
                    '/dang-nhap?redirectTo=/uu-dai-thanh-vien',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(48, 48),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(l10n.supportCouponLoginAction),
                ),
                OutlinedButton(
                  onPressed: () => context.push('/dang-ky'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textStrong,
                    minimumSize: const Size(48, 48),
                    shape: const StadiumBorder(),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Text(l10n.supportCouponRegisterAction),
                ),
              ],
            )
          else ...[
            TextField(
              key: const ValueKey('member-coupon-code-input'),
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: l10n.supportCouponCodeInputLabel,
                border: const OutlineInputBorder(
                  borderRadius: AppRadii.roundedPill,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('member-coupon-amount-input'),
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.supportCouponAmountInputLabel,
                border: const OutlineInputBorder(
                  borderRadius: AppRadii.roundedPill,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const ValueKey('member-coupon-check-btn'),
              onPressed: _isChecking ? null : _checkCoupon,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(LucideIcons.ticket, size: 16),
              label: Text(
                _isChecking
                    ? l10n.supportCouponCheckingLabel
                    : l10n.supportCouponCheckAction,
              ),
            ),
            if (_statusText != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _statusText!,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _isValidResult ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
