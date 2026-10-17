import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../view_models/auth_notifier.dart';

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

  final _identifierController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(_otpLength, (_) => FocusNode());

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
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
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

  String get _currentOtp => _otpControllers.map((c) => c.text.trim()).join();

  bool get _isOtpComplete =>
      _otpControllers.every((c) => c.text.trim().isNotEmpty);

  void _onOtpDigitChanged(int index, String value) {
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length > 1) {
      // Handle paste of up to 6 digits
      for (var i = 0; i < _otpLength; i++) {
        _otpControllers[i].text = i < digitsOnly.length ? digitsOnly[i] : '';
      }
      final nextIndex = (digitsOnly.length - 1).clamp(0, _otpLength - 1);
      _otpFocusNodes[nextIndex].requestFocus();
      setState(() {});
      return;
    }

    _otpControllers[index].text = digitsOnly;
    if (digitsOnly.isNotEmpty && index < _otpLength - 1) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    setState(() {});
  }

  Future<void> _handleSendOtp() async {
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
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _handleResendOtp() async {
    if (_resendCountdown > 0 || _isLoading) return;
    await _handleSendOtp();
  }

  Future<void> _handleResetPassword() async {
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
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.iconStrong),
          onPressed: () {
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
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.s12),
                        margin: const EdgeInsets.only(bottom: AppSpacing.s16),
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
                    ],
                    if (_step == _ForgotStep.request) ...[
                      AppTextField(
                        controller: _identifierController,
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
                      Row(
                        children: List.generate(_otpLength, (idx) {
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  right: idx < _otpLength - 1 ? 8.0 : 0),
                              child: TextField(
                                controller: _otpControllers[idx],
                                focusNode: _otpFocusNodes[idx],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                style: AppTypography.sectionHeading,
                                decoration: InputDecoration(
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onChanged: (val) =>
                                    _onOtpDigitChanged(idx, val),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AppTextField(
                        controller: _newPasswordController,
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
                        onPressed: _isOtpComplete ? _handleResetPassword : null,
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.successSoft,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                AppColors.successGreen.withValues(alpha: 0.35),
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
    );
  }
}
