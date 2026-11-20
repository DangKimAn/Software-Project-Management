import 'package:flutter/material.dart';
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
import '../../../../shared/widgets/app_semantic_icons.dart';
import '../../../../shared/widgets/app_text_field.dart';

import '../../domain/entities/user.dart';
import '../view_models/auth_notifier.dart';
import '../validation/auth_validation.dart';

/// Màn hình đăng ký tài khoản mới (`/dang-ky`), tích hợp bộ đo độ mạnh mật khẩu trực quan 4 mức,
/// kiểm tra định dạng số điện thoại/email và hỗ trợ đăng ký nhanh bằng tài khoản Google.
class RegisterScreen extends ConsumerStatefulWidget {
  /// Đường dẫn nội bộ cần chuyển tiếp sau khi tạo tài khoản thành công (nếu có).
  final String? redirectTo;

  /// Khởi tạo `RegisterScreen`.
  const RegisterScreen({super.key, this.redirectTo});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;
  String? _termsError;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Giải thuật chấm điểm độ mạnh mật khẩu theo 4 tiêu chí: độ dài >= 8, có cả chữ hoa & thường, có chữ số và có ký tự đặc biệt.
  ({int score, String label, Color color}) _getPasswordStrength(
    String pwd,
    AppLocalizations l10n,
  ) {
    var score = 0;
    if (pwd.length >= 8) score++;
    if (RegExp(r'[a-z]').hasMatch(pwd) && RegExp(r'[A-Z]').hasMatch(pwd)) {
      score++;
    }
    if (RegExp(r'\d').hasMatch(pwd)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(pwd)) score++;

    if (score <= 1) {
      return (
        score: score,
        label: l10n.authStrengthWeak,
        color: AppColors.errorRed
      );
    } else if (score == 2) {
      return (
        score: score,
        label: l10n.authStrengthFair,
        color: AppColors.warningAmber
      );
    } else if (score == 3) {
      return (
        score: score,
        label: l10n.authStrengthGood,
        color: AppColors.successGreen
      );
    } else {
      return (
        score: score,
        label: l10n.authStrengthStrong,
        color: AppColors.successGreen
      );
    }
  }

  String _resolveErrorMessage(Object error) {
    if (error is AppFailure) {
      return error.message;
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _navigateAfterAuth(User user) {
    final target = AuthNotifier.resolvePostAuthRedirectPath(
      user,
      redirectTo: widget.redirectTo,
    );
    context.go(target);
  }

  Future<void> _handleRegister() async {
    // Giải thuật kiểm tra đồng thời toàn bộ điều kiện đăng ký tài khoản (`TC-014`):
    // Kiểm tra biểu mẫu (họ tên, SĐT Việt Nam, email, độ mạnh mật khẩu, khớp xác nhận mật khẩu)
    // VÀ bắt buộc người dùng tích đồng ý Điều khoản dịch vụ trước khi gọi API `/api/auth/register`.
    if (_isLoading) return;
    final activeL10n = lookupAppLocalizations(Locale(ref.read(localeProvider)));
    _fieldErrors = {};
    final isFormValid = _formKey.currentState!.validate();
    if (!_acceptedTerms) {
      setState(() {
        _termsError = activeL10n.authTermsRequiredError;
      });
    } else if (_termsError != null) {
      setState(() {
        _termsError = null;
      });
    }
    if (!isFormValid || !_acceptedTerms) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final split = User.splitFullName(_fullNameController.text.trim());
    final firstName = split.firstName.isNotEmpty ? split.firstName : 'Khách';
    final lastName = split.lastName.isNotEmpty ? split.lastName : 'User';

    try {
      final user = await ref.read(authNotifierProvider.notifier).register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            firstName: firstName,
            lastName: lastName,
            phone: _phoneController.text.trim(),
          );
      if (mounted) {
        _navigateAfterAuth(user);
      }
    } catch (e) {
      if (mounted) {
        _fieldErrors = AuthValidation.fieldErrors(e);
        _formKey.currentState?.validate();
        setState(() {
          _errorMessage = _resolveErrorMessage(e);
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
          _errorMessage = _resolveErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeL10n =
        lookupAppLocalizations(Locale(ref.watch(localeProvider)));
    final pwd = _passwordController.text;
    final strength = _getPasswordStrength(pwd, activeL10n);

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
            if (context.canPop()) {
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
                        activeL10n.authCreateAccountTitle,
                        style: AppTypography.display
                            .copyWith(color: AppColors.textStrong),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        activeL10n.authRegisterSubtitle,
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
                      AppTextField(
                        controller: _fullNameController,
                        readOnly: _isLoading,
                        labelText: activeL10n.authFullNameLabel,
                        hintText: activeL10n.authFullNameHint,
                        prefixIcon: const Icon(
                          LucideIcons.userRound,
                          size: 20,
                          color: AppColors.iconMuted,
                        ),
                        onChanged: (_) {
                          if (_fieldErrors.containsKey('firstName') ||
                              _fieldErrors.containsKey('lastName')) {
                            setState(() {
                              _fieldErrors.remove('firstName');
                              _fieldErrors.remove('lastName');
                              _formKey.currentState?.validate();
                            });
                          }
                        },
                        validator: (v) {
                          final nameError = _fieldErrors['firstName'] ??
                              _fieldErrors['lastName'];
                          if (nameError != null) return nameError;
                          if (v == null || v.trim().isEmpty) {
                            return 'Vui lòng nhập họ và tên';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AppTextField(
                        controller: _phoneController,
                        readOnly: _isLoading,
                        labelText: activeL10n.authPhoneRequiredLabel,
                        hintText: activeL10n.authPhoneHint,
                        prefixIcon: const Icon(
                          LucideIcons.phone,
                          size: 20,
                          color: AppColors.iconMuted,
                        ),
                        keyboardType: TextInputType.phone,
                        onChanged: (_) {
                          if (_fieldErrors.containsKey('phone')) {
                            setState(() {
                              _fieldErrors.remove('phone');
                              _formKey.currentState?.validate();
                            });
                          }
                        },
                        validator: (v) =>
                            _fieldErrors['phone'] ??
                            AuthValidation.phone(v, required: true),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AppTextField(
                        controller: _emailController,
                        readOnly: _isLoading,
                        labelText: activeL10n.authEmailRequiredLabel,
                        hintText: activeL10n.authEmailHint,
                        prefixIcon: const Icon(
                          LucideIcons.mail,
                          size: 20,
                          color: AppColors.iconMuted,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (_) {
                          if (_fieldErrors.containsKey('email')) {
                            setState(() {
                              _fieldErrors.remove('email');
                              _formKey.currentState?.validate();
                            });
                          }
                        },
                        validator: (v) =>
                            _fieldErrors['email'] ?? AuthValidation.email(v),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AppTextField(
                        controller: _passwordController,
                        readOnly: _isLoading,
                        textInputAction: TextInputAction.next,
                        labelText: activeL10n.authPasswordLabel,
                        hintText: activeL10n.authPasswordCreateHint,
                        obscureText: _obscurePassword,
                        onChanged: (_) {
                          if (_fieldErrors.containsKey('password')) {
                            setState(() {
                              _fieldErrors.remove('password');
                              _formKey.currentState?.validate();
                            });
                          } else if (_confirmPasswordController
                              .text.isNotEmpty) {
                            _formKey.currentState?.validate();
                          }
                        },
                        prefixIcon: const Icon(
                          LucideIcons.lock,
                          size: 20,
                          color: AppColors.iconMuted,
                        ),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? activeL10n.authShowPasswordTooltip
                              : activeL10n.authHidePasswordTooltip,
                          constraints:
                              const BoxConstraints(minWidth: 48, minHeight: 48),
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
                        validator: (v) =>
                            _fieldErrors['password'] ??
                            AuthValidation.password(v),
                      ),
                      if (pwd.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: List.generate(4, (idx) {
                            final active = idx < strength.score;
                            return Expanded(
                              child: Container(
                                height: 5,
                                margin: EdgeInsets.only(right: idx < 3 ? 6 : 0),
                                decoration: BoxDecoration(
                                  color: active
                                      ? strength.color
                                      : AppColors.borderSoft,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          activeL10n.authPasswordStrengthLabel(strength.label),
                          style: AppTypography.caption.copyWith(
                            color: strength.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.s16),
                      AppTextField(
                        controller: _confirmPasswordController,
                        readOnly: _isLoading,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _handleRegister(),
                        labelText: activeL10n.authConfirmPasswordLabel,
                        hintText: activeL10n.authConfirmPasswordHint,
                        obscureText: _obscureConfirmPassword,
                        onChanged: (_) {
                          if (_confirmPasswordController.text.isNotEmpty) {
                            _formKey.currentState?.validate();
                          }
                        },
                        prefixIcon: const Icon(
                          LucideIcons.lock,
                          size: 20,
                          color: AppColors.iconMuted,
                        ),
                        suffixIcon: IconButton(
                          tooltip: _obscureConfirmPassword
                              ? activeL10n.authShowPasswordTooltip
                              : activeL10n.authHidePasswordTooltip,
                          constraints:
                              const BoxConstraints(minWidth: 48, minHeight: 48),
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
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Vui lòng nhập xác nhận mật khẩu';
                          }
                          if (v != _passwordController.text) {
                            return 'Mật khẩu xác nhận không khớp';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _acceptedTerms = !_acceptedTerms;
                                  if (_acceptedTerms) {
                                    _termsError = null;
                                  }
                                });
                              },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  key: const Key('register_terms_checkbox'),
                                  value: _acceptedTerms,
                                  activeColor: AppColors.primary,
                                  onChanged: _isLoading
                                      ? null
                                      : (val) {
                                          setState(() {
                                            _acceptedTerms = val ?? false;
                                            if (_acceptedTerms) {
                                              _termsError = null;
                                            }
                                          });
                                        },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  activeL10n.authTermsAgreement,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textStrong,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_termsError != null) ...[
                        const SizedBox(height: 6),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _termsError!,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.errorRed,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.s24),
                      AppButton(
                        text: _isLoading
                            ? activeL10n.authCreatingAccount
                            : activeL10n.authRegisterBtn,
                        isLoading: _isLoading,
                        icon: const Icon(
                          LucideIcons.arrowRight,
                          size: 18,
                          color: Colors.white,
                        ),
                        onPressed: _handleRegister,
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              activeL10n.authAlreadyHaveAccount,
                              style: AppTypography.body
                                  .copyWith(color: AppColors.textMuted),
                            ),
                            TextButton(
                              onPressed: () {
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  final redirect = widget.redirectTo?.trim();
                                  if (redirect != null &&
                                      AuthNotifier.isSafeRedirectPath(
                                          redirect)) {
                                    context.go(
                                      Uri(
                                        path: '/dang-nhap',
                                        queryParameters: <String, String>{
                                          'redirectTo': redirect,
                                        },
                                      ).toString(),
                                    );
                                  } else {
                                    context.go('/dang-nhap');
                                  }
                                }
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                minimumSize: const Size(48, 48),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                activeL10n.authLoginTitle,
                                style: AppTypography.body.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              activeL10n.authOrDivider,
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textMuted),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      AppButton.secondary(
                        text: activeL10n.authGoogleLoginBtn,
                        icon: const AppBrandIcon.googleLogo(size: 20),
                        onPressed: _isLoading ? null : _handleGoogleLogin,
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
