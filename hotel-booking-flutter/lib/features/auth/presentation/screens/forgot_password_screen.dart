import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../view_models/auth_notifier.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _identifierController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _isOtpSent = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _identifierController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập email hoặc số điện thoại');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.forgotPassword(identifier: identifier);
      setState(() {
        _isOtpSent = true;
        _isLoading = false;
        _successMessage = 'Mã xác thực OTP đã được gửi đến $identifier.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _handleResetPassword() async {
    final otp = _otpController.text.trim();
    final newPassword = _newPasswordController.text;

    if (otp.isEmpty || newPassword.length < 6) {
      setState(() => _errorMessage =
          'Vui lòng nhập đúng mã OTP và mật khẩu từ 6 ký tự trở lên');
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Đặt lại mật khẩu thành công! Vui lòng đăng nhập.')),
        );
        context.pushReplacement('/login');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBase,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceBase,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textStrong),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.s16),
              Text(
                _isOtpSent ? 'Đặt lại mật khẩu' : 'Quên mật khẩu?',
                style:
                    AppTypography.display.copyWith(color: AppColors.textStrong),
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                _isOtpSent
                    ? 'Nhập mã OTP đã nhận và thiết lập mật khẩu mới cho tài khoản của bạn.'
                    : 'Nhập email hoặc số điện thoại đã đăng ký để nhận mã xác thực khôi phục mật khẩu.',
                style: AppTypography.body.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.s32),
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  margin: const EdgeInsets.only(bottom: AppSpacing.s16),
                  decoration: BoxDecoration(
                    color: AppColors.brandSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.circleAlert,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTypography.caption
                              .copyWith(color: AppColors.primaryPressed),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_successMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  margin: const EdgeInsets.only(bottom: AppSpacing.s16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.circleCheck,
                          color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: AppTypography.caption
                              .copyWith(color: const Color(0xFF065F46)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (!_isOtpSent) ...[
                AppTextField(
                  controller: _identifierController,
                  labelText: 'Email hoặc Số điện thoại',
                  hintText: 'name@example.com hoặc 0901234567',
                  prefixIcon: const Icon(LucideIcons.mail, size: 20),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSpacing.s32),
                AppButton(
                  text: 'Gửi mã xác thực OTP',
                  isLoading: _isLoading,
                  onPressed: _handleSendOtp,
                ),
              ] else ...[
                AppTextField(
                  controller: _otpController,
                  labelText: 'Mã OTP',
                  hintText: 'Nhập mã 6 chữ số',
                  prefixIcon: const Icon(LucideIcons.shieldCheck, size: 20),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.s16),
                AppTextField(
                  controller: _newPasswordController,
                  labelText: 'Mật khẩu mới',
                  hintText: 'Tối thiểu 6 ký tự',
                  obscureText: true,
                  prefixIcon: const Icon(LucideIcons.lock, size: 20),
                ),
                const SizedBox(height: AppSpacing.s32),
                AppButton(
                  text: 'Xác nhận đổi mật khẩu',
                  isLoading: _isLoading,
                  onPressed: _handleResetPassword,
                ),
                const SizedBox(height: AppSpacing.s16),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _isOtpSent = false),
                    child: Text(
                      'Gửi lại mã OTP',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
