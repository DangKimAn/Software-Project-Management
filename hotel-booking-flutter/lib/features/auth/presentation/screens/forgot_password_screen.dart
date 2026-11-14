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
import '../../../../core/errors/app_failure.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../view_models/forgot_password_view_model.dart';
import '../validation/auth_validation.dart';

/// Các bước tuần tự trong luồng khôi phục mật khẩu: nhập định danh (`request`), xác thực OTP (`otp`) và hoàn tất (`success`).
enum _ForgotStep { request, otp, success }

/// Màn hình khôi phục mật khẩu qua mã xác thực OTP 6 chữ số (`/quen-mat-khau`).
///
/// Quản lý máy trạng thái 3 bước kèm đồng hồ đếm ngược chống gửi lại OTP liên tục (`_otpResendSeconds`),
/// kiểm tra độ mạnh mật khẩu mới và xác nhận khớp mật khẩu nhập lại trước khi cập nhật lên máy chủ.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  /// Khởi tạo `ForgotPasswordScreen`.
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  static const int _otpLength = 6;
  static const int _otpResendSeconds = 60;

  final _formKey = GlobalKey<FormState>();
  Map<String, String> _fieldErrors = {};
  final _otpController = TextEditingController();
  final _identifierController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _ForgotStep _step = _ForgotStep.request;
  int _resendCountdown = _otpResendSeconds;
  Timer? _resendTimer;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _identifierController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String _resolveErrorMessage(Object error) {
    if (error is AppFailure) {
      return error.message;
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _startResendTimer([int initialSeconds = _otpResendSeconds]) {
    _resendTimer?.cancel();
    final safeSeconds = initialSeconds > 0 ? initialSeconds : _otpResendSeconds;
    setState(() {
      _resendCountdown = safeSeconds;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown <= 1) {
        timer.cancel();
        setState(() => _resendCountdown = 0);
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  String get _currentOtp => _otpController.text.trim();
  bool get _isOtpComplete => RegExp(r'^\d{6}$').hasMatch(_currentOtp);

  // Giải thuật yêu cầu gửi mã OTP và đồng bộ đồng hồ đếm ngược 60s hoặc `retryAfterSeconds` khi gặp 429 (`TC-017`).
  Future<void> _handleSendOtp() async {
    if (_isLoading) return;
    _fieldErrors = {};
    if (_step == _ForgotStep.request && !_formKey.currentState!.validate()) {
      return;
    }
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập email hoặc số điện thoại.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cooldownSeconds = await ref
          .read(forgotPasswordViewModelProvider)
          .requestPasswordResetOtp(identifier: identifier);
      if (mounted) {
        setState(() {
          _step = _ForgotStep.otp;
          _isLoading = false;
        });
        _startResendTimer(cooldownSeconds);
      }
    } catch (e) {
      if (mounted) {
        _fieldErrors = AuthValidation.fieldErrors(e);
        _formKey.currentState?.validate();
        int? retryAfter;
        if (e is RateLimitFailure &&
            e.retryAfterSeconds != null &&
            e.retryAfterSeconds! > 0) {
          retryAfter = e.retryAfterSeconds;
        } else if (e is AppFailure && e.details is Map) {
          final parsed =
              int.tryParse('${e.details['retryAfterSeconds'] ?? ''}');
          if (parsed != null && parsed > 0) retryAfter = parsed;
        }
        setState(() {
          _isLoading = false;
          _errorMessage = _resolveErrorMessage(e);
        });
        if (retryAfter != null && _step == _ForgotStep.otp) {
          _startResendTimer(retryAfter);
        }
      }
    }
  }

  Future<void> _handleResendOtp() async {
    if (_resendCountdown > 0 || _isLoading) return;
    await _handleSendOtp();
  }

  // Giải thuật thẩm định mã OTP 6 chữ số cùng mật khẩu mới và gửi xác nhận đặt lại mật khẩu (`_handleResetPassword`).
  Future<void> _handleResetPassword() async {
    if (_isLoading) return;
    _fieldErrors = {};
    if (!_formKey.currentState!.validate()) return;
    final otp = _currentOtp;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (otp.length < _otpLength) {
      setState(() => _errorMessage = 'Vui lòng nhập đủ 6 chữ số mã OTP.');
      return;
    }
    if (newPassword.length < 8) {
      setState(() => _errorMessage = 'Mật khẩu mới cần ít nhất 8 ký tự.');
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _errorMessage = 'Mật khẩu xác nhận không khớp.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(forgotPasswordViewModelProvider).confirmPasswordReset(
            identifier: _identifierController.text.trim(),
            otp: otp,
            newPassword: newPassword,
          );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _step = _ForgotStep.success;
        });
      }
    } catch (e) {
      if (mounted) {
        _fieldErrors = AuthValidation.fieldErrors(e);
        _formKey.currentState?.validate();
        setState(() {
          _isLoading = false;
          _errorMessage = _resolveErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeL10n =
        lookupAppLocalizations(Locale(ref.watch(localeProvider)));
    final countdownFormatted =
        '${(_resendCountdown ~/ 60).toString().padLeft(2, '0')}:${(_resendCountdown % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: activeL10n.ctaBack,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.iconStrong),
          onPressed: () {
            if (_isLoading) return;
            if (_step == _ForgotStep.otp) {
              setState(() => _step = _ForgotStep.request);
            } else if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dang-nhap');
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s20,
              vertical: AppSpacing.s16,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.s24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBase,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _step == _ForgotStep.request
                            ? activeL10n.authForgotQuestionTitle
                            : (_step == _ForgotStep.otp
                                ? activeL10n.authOtpVerifyTitle
                                : activeL10n.authPasswordChangedTitle),
                        style: AppTypography.display
                            .copyWith(color: AppColors.textStrong),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        _step == _ForgotStep.request
                            ? activeL10n.authForgotRequestSubtitle
                            : (_step == _ForgotStep.otp
                                ? activeL10n.authForgotOtpSubtitle
                                : activeL10n.authForgotSuccessSubtitle),
                        style: AppTypography.body
                            .copyWith(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: AppSpacing.s24),
                      if (_errorMessage != null) ...[
                        Semantics(
                          liveRegion: true,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.s12),
                            margin:
                                const EdgeInsets.only(bottom: AppSpacing.s16),
                            decoration: BoxDecoration(
                              color: AppColors.errorSoft,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.circleAlert,
                                  color: AppColors.iconStrong,
                                  size: 20,
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: AppTypography.caption
                                        .copyWith(color: AppColors.errorRed),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (_step == _ForgotStep.request) ...[
                        AppTextField(
                          controller: _identifierController,
                          readOnly: _isLoading,
                          onChanged: (_) {
                            if (_fieldErrors.containsKey('identifier')) {
                              setState(() {
                                _fieldErrors.remove('identifier');
                                _formKey.currentState?.validate();
                              });
                            }
                          },
                          validator: (v) =>
                              _fieldErrors['identifier'] ??
                              AuthValidation.loginIdentifier(v),
                          labelText: activeL10n.authIdentifierLabel,
                          hintText: activeL10n.authIdentifierHint,
                          prefixIcon: const Icon(
                            LucideIcons.userRound,
                            size: 20,
                            color: AppColors.iconMuted,
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: AppSpacing.s24),
                        AppButton(
                          text: activeL10n.authSendOtpButton,
                          isLoading: _isLoading,
                          onPressed: _handleSendOtp,
                        ),
                      ] else if (_step == _ForgotStep.otp) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            activeL10n.authOtpSentTo(
                              _identifierController.text.trim(),
                            ),
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textStrong,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextFormField(
                          controller: _otpController,
                          readOnly: _isLoading,
                          keyboardType: TextInputType.number,
                          enableSuggestions: false,
                          autocorrect: false,
                          enableIMEPersonalizedLearning: false,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(_otpLength)
                          ],
                          decoration: InputDecoration(
                              labelText: activeL10n.authOtpSixDigitsLabel,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24)),
                              errorMaxLines: 4),
                          validator: (v) =>
                              _fieldErrors['otp'] ??
                              (_isOtpComplete
                                  ? null
                                  : 'Vui lòng nhập đủ 6 chữ số OTP'),
                          onChanged: (_) {
                            if (_fieldErrors.containsKey('otp')) {
                              setState(() {
                                _fieldErrors.remove('otp');
                                _formKey.currentState?.validate();
                              });
                            } else {
                              setState(() {});
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        AppTextField(
                          controller: _newPasswordController,
                          readOnly: _isLoading,
                          onChanged: (_) {
                            if (_fieldErrors.containsKey('newPassword')) {
                              setState(() {
                                _fieldErrors.remove('newPassword');
                                _formKey.currentState?.validate();
                              });
                            }
                          },
                          validator: (v) =>
                              _fieldErrors['newPassword'] ??
                              AuthValidation.password(v),
                          labelText: activeL10n.authNewPasswordLabel,
                          hintText: activeL10n.authPasswordCreateHint,
                          obscureText: _obscureNewPassword,
                          prefixIcon: const Icon(
                            LucideIcons.lock,
                            size: 20,
                            color: AppColors.iconMuted,
                          ),
                          suffixIcon: IconButton(
                            tooltip: _obscureNewPassword
                                ? activeL10n.authShowPasswordTooltip
                                : activeL10n.authHidePasswordTooltip,
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            icon: Icon(
                              _obscureNewPassword
                                  ? LucideIcons.eyeOff
                                  : LucideIcons.eye,
                              size: 20,
                              color: AppColors.iconStrong,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureNewPassword = !_obscureNewPassword;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        AppTextField(
                          controller: _confirmPasswordController,
                          readOnly: _isLoading,
                          validator: (v) => v == _newPasswordController.text
                              ? null
                              : 'Mật khẩu xác nhận không khớp',
                          labelText: activeL10n.authConfirmPasswordLabel,
                          hintText: activeL10n.authConfirmPasswordHint,
                          obscureText: _obscureConfirmPassword,
                          prefixIcon: const Icon(
                            LucideIcons.lock,
                            size: 20,
                            color: AppColors.iconMuted,
                          ),
                          suffixIcon: IconButton(
                            tooltip: _obscureConfirmPassword
                                ? activeL10n.authShowPasswordTooltip
                                : activeL10n.authHidePasswordTooltip,
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? LucideIcons.eyeOff
                                  : LucideIcons.eye,
                              size: 20,
                              color: AppColors.iconStrong,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed:
                                _resendCountdown > 0 ? null : _handleResendOtp,
                            icon: const Icon(
                              LucideIcons.refreshCw,
                              size: 16,
                              color: AppColors.iconStrong,
                            ),
                            label: Text(
                              _resendCountdown > 0
                                  ? (ref.watch(localeProvider) == 'vi'
                                      ? 'Gửi lại sau $countdownFormatted'
                                      : activeL10n.authResendOtpCountdown(
                                          _resendCountdown.toString(),
                                        ))
                                  : activeL10n.authResendOtpButton,
                              style: AppTypography.caption.copyWith(
                                color: _resendCountdown > 0
                                    ? AppColors.textMuted
                                    : AppColors.textStrong,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        AppButton(
                          text: activeL10n.authConfirmOtpButton,
                          isLoading: _isLoading,
                          onPressed:
                              _isOtpComplete ? _handleResetPassword : null,
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.successSoft,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.successGreen
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.circleCheck,
                                size: 22,
                                color: AppColors.iconStrong,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  activeL10n.authOtpSuccessBanner,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.textStrong,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s24),
                        AppButton(
                          text: activeL10n.authBackToLoginButton,
                          onPressed: () => context.go('/dang-nhap'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
