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

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authNotifierProvider.notifier).register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            phone: _phoneController.text.trim().isNotEmpty
                ? _phoneController.text.trim()
                : null,
          );
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.s16),
                Text(
                  'Tạo tài khoản mới',
                  style: AppTypography.display
                      .copyWith(color: AppColors.textStrong),
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  'Trải nghiệm đặt phòng villa nghỉ dưỡng đẳng cấp và nhận ưu đãi độc quyền.',
                  style:
                      AppTypography.body.copyWith(color: AppColors.textMuted),
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
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _firstNameController,
                        labelText: 'Họ',
                        hintText: 'Nguyễn',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Vui lòng nhập họ'
                            : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: AppTextField(
                        controller: _lastNameController,
                        labelText: 'Tên',
                        hintText: 'Thành',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Vui lòng nhập tên'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
                AppTextField(
                  controller: _emailController,
                  labelText: 'Email',
                  hintText: 'name@example.com',
                  prefixIcon: const Icon(LucideIcons.mail, size: 20),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Vui lòng nhập email';
                    if (!v.contains('@') || !v.contains('.'))
                      return 'Email không hợp lệ';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s16),
                AppTextField(
                  controller: _phoneController,
                  labelText: 'Số điện thoại (tùy chọn)',
                  hintText: '0901234567',
                  prefixIcon: const Icon(LucideIcons.phone, size: 20),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppSpacing.s16),
                AppTextField(
                  controller: _passwordController,
                  labelText: 'Mật khẩu',
                  hintText: 'Tối thiểu 6 ký tự',
                  obscureText: _obscurePassword,
                  prefixIcon: const Icon(LucideIcons.lock, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  validator: (v) {
                    if (v == null || v.length < 6) {
                      return 'Mật khẩu phải có ít nhất 6 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s32),
                AppButton(
                  text: 'Đăng ký tài khoản',
                  isLoading: _isLoading,
                  onPressed: _handleRegister,
                ),
                const SizedBox(height: AppSpacing.s24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Đã có tài khoản? ',
                      style: AppTypography.body
                          .copyWith(color: AppColors.textMuted),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.pushReplacement('/login');
                        }
                      },
                      child: Text(
                        'Đăng nhập',
                        style: AppTypography.body.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
