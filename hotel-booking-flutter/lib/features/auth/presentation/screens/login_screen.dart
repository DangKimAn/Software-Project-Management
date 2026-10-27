import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_semantic_icons.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../data/services/google_auth_service.dart';
import '../../domain/entities/user.dart';
import '../view_models/auth_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? redirectTo;

  const LoginScreen({super.key, this.redirectTo});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _resolveLoginErrorMessage(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '');
    final lower = raw.toLowerCase();
    if (lower.contains('invalid credentials')) {
      return 'Email/SĐT hoặc mật khẩu không đúng.';
    }
    if (lower.contains('temporarily locked') || lower.contains('423')) {
      return 'Tài khoản tạm thời bị khóa. Vui lòng thử lại sau.';
    }
    if (lower.contains('validation error')) {
      return 'Thông tin đăng nhập không hợp lệ.';
    }
    return raw;
  }

  void _navigateAfterAuth(User user) {
    final target = AuthNotifier.resolvePostAuthRedirectPath(
      user,
      redirectTo: widget.redirectTo,
    );
    context.go(target);
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await ref.read(authNotifierProvider.notifier).login(
            _identifierController.text.trim(),
            _passwordController.text,
          );
      if (mounted) {
        _navigateAfterAuth(user);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _resolveLoginErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user =
          await ref.read(authNotifierProvider.notifier).signInWithGoogle();
      if (mounted) {
        _navigateAfterAuth(user);
      }
    } on GoogleSignInCancelledException {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _resolveLoginErrorMessage(e);
          _isLoading = false;
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
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
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
                        'Chào mừng trở lại',
                        style: AppTypography.display
                            .copyWith(color: AppColors.textStrong),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        'Đăng nhập để xem kỳ nghỉ và quản lý chuyến đi của bạn tại The Palm Villa.',
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
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập email hoặc số điện thoại';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AppTextField(
                        controller: _passwordController,
                        labelText: 'Mật khẩu',
                        hintText: 'Nhập mật khẩu',
                        obscureText: _obscurePassword,
                        prefixIcon: const Icon(
                          LucideIcons.lock,
                          size: 20,
                          color: AppColors.iconMuted,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? LucideIcons.eyeOff
                                : LucideIcons.eye,
                            size: 20,
                            color: AppColors.iconStrong,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập mật khẩu';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push('/quen-mat-khau'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s8,
                            ),
                            minimumSize: const Size(48, 48),
                          ),
                          child: Text(
                            'Quên mật khẩu?',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textStrong,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AppButton(
                        text: _isLoading ? 'Đang đăng nhập...' : 'Đăng nhập',
                        isLoading: _isLoading,
                        icon: const Icon(
                          LucideIcons.arrowRight,
                          size: 18,
                          color: Colors.white,
                        ),
                        onPressed: _handleLogin,
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'HOẶC',
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textMuted),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AppButton.secondary(
                        text: 'Đăng nhập với Google',
                        icon: const AppBrandIcon.google(
                          size: 18,
                          color: AppColors.iconStrong,
                        ),
                        onPressed: _isLoading ? null : _handleGoogleLogin,
                      ),
                      const SizedBox(height: AppSpacing.s24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Chưa có tài khoản? ',
                            style: AppTypography.body
                                .copyWith(color: AppColors.textMuted),
                          ),
                          TextButton(
                            onPressed: () {
                              final redirect = widget.redirectTo?.trim();
                              if (redirect != null &&
                                  AuthNotifier.isSafeRedirectPath(redirect)) {
                                context.push(
                                  Uri(
                                    path: '/dang-ky',
                                    queryParameters: <String, String>{
                                      'redirectTo': redirect,
                                    },
                                  ).toString(),
                                );
                              } else {
                                context.push('/dang-ky');
                              }
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s8,
                              ),
                              minimumSize: const Size(48, 48),
                            ),
                            child: Text(
                              'Đăng ký',
                              style: AppTypography.body.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
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
