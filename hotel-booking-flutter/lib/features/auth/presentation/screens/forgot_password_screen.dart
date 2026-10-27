import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../view_models/auth_notifier.dart';
import '../validation/auth_validation.dart';

enum _ForgotStep { request, otp, success }

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  static const int _otpLength = 6;
  static const int _otpResendSeconds = 23;

  final _formKey = GlobalKey<FormState>();
  Map<String, String> _fieldErrors = {};
  final _otpController = TextEditingController();
  final _identifierController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _ForgotStep _step = _ForgotStep.request;
  int _resendCountdown = _otpResendSeconds;
  Timer? _resendTimer;
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

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendCountdown = _otpResendSeconds;
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
      final repo = ref.read(authRepositoryProvider);
      await repo.forgotPassword(identifier: identifier);
      if (mounted) {
        setState(() {
          _step = _ForgotStep.otp;
          _isLoading = false;
        });
        _startResendTimer();
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

  Future<void> _handleResendOtp() async {
    if (_resendCountdown > 0 || _isLoading) return;
    await _handleSendOtp();
  }

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
      final repo = ref.read(authRepositoryProvider);
      await repo.resetPassword(
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Quay lại',
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
                            ? 'Quên mật khẩu?'
                            : (_step == _ForgotStep.otp
                                ? 'Xác thực mã OTP'
                                : 'Đổi mật khẩu thành công'),
                        style: AppTypography.display
                            .copyWith(color: AppColors.textStrong),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        _step == _ForgotStep.request
                            ? 'Nhập email hoặc số điện thoại đã đăng ký để nhận mã xác thực khôi phục mật khẩu.'
                            : (_step == _ForgotStep.otp
                                ? 'Nhập 6 chữ số OTP và thiết lập mật khẩu mới.'
                                : 'Mật khẩu của bạn đã được cập nhật an toàn.'),
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
                              AuthValidation.identifier(v),
                          labelText: 'Email hoặc số điện thoại',
                          hintText: 'Nhập email hoặc số điện thoại',
                          prefixIcon: const Icon(
                            LucideIcons.userRound,
                            size: 20,
                            color: AppColors.iconMuted,
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: AppSpacing.s24),
                        AppButton(
                          text: 'Gửi mã xác thực',
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
                            'Mã OTP đã gửi tới: ${_identifierController.text.trim()}',
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
                          autofillHints: const [AutofillHints.oneTimeCode],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(_otpLength)
                          ],
                          decoration: InputDecoration(
                              labelText: 'Mã OTP gồm 6 chữ số',
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
                          labelText: 'Mật khẩu mới',
                          hintText: 'Tối thiểu 8 ký tự',
                          obscureText: true,
                          prefixIcon: const Icon(
                            LucideIcons.lock,
                            size: 20,
                            color: AppColors.iconMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        AppTextField(
                          controller: _confirmPasswordController,
                          readOnly: _isLoading,
                          validator: (v) => v == _newPasswordController.text
                              ? null
                              : 'Mật khẩu xác nhận không khớp',
                          labelText: 'Xác nhận mật khẩu',
                          hintText: 'Nhập lại mật khẩu mới',
                          obscureText: true,
                          prefixIcon: const Icon(
                            LucideIcons.lock,
                            size: 20,
                            color: AppColors.iconMuted,
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
                                  ? 'Gửi lại sau 00:${_resendCountdown.toString().padLeft(2, '0')}'
                                  : 'Gửi lại mã OTP',
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
                          text: 'Xác nhận mã OTP',
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
                                  'Mã OTP đã được xác thực và mật khẩu mới đã sẵn sàng sử dụng.',
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
                          text: 'Quay lại đăng nhập',
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
