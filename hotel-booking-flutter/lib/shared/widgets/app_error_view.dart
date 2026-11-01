import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

import 'app_button.dart';

class AppErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryText;
  final IconData? icon;

  const AppErrorView({
    super.key,
    this.title = 'Đã có lỗi xảy ra',
    required this.message,
    this.onRetry,
    this.retryText = 'Thử lại',
    this.icon,
  });

  IconData _resolveContextualIcon() {
    if (icon != null) return icon!;
    final haystack = '$title $message'.toLowerCase();
    if (haystack.contains('mạng') ||
        haystack.contains('kết nối') ||
        haystack.contains('internet') ||
        haystack.contains('offline') ||
        haystack.contains('wifi')) {
      return LucideIcons.wifiOff;
    }
    if (haystack.contains('máy chủ') ||
        haystack.contains('server') ||
        haystack.contains('timeout') ||
        haystack.contains('quá thời gian') ||
        haystack.contains('500') ||
        haystack.contains('502') ||
        haystack.contains('503')) {
      return LucideIcons.cloudOff;
    }
    return LucideIcons.circleAlert;
  }

  @override
  Widget build(BuildContext context) {
    final resolvedIcon = _resolveContextualIcon();

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 344),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FB),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: const Color(0xFFE7E9EE),
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x090F172A),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x080F172A),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        resolvedIcon,
                        size: 21,
                        color: AppColors.iconStrong,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: AppTypography.primaryFontFamily,
                      fontFamilyFallback: AppTypography.fontFallbacks,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.35,
                      height: 1.28,
                      color: AppColors.textStrong,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: AppTypography.primaryFontFamily,
                        fontFamilyFallback: AppTypography.fontFallbacks,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.1,
                        height: 1.48,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 20),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 176),
                      child: FilledButtonTheme(
                        data: FilledButtonThemeData(
                          style: ButtonStyle(
                            minimumSize:
                                const WidgetStatePropertyAll(Size(48, 48)),
                            padding: const WidgetStatePropertyAll(
                              EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 11,
                              ),
                            ),
                            shape:
                                const WidgetStatePropertyAll(StadiumBorder()),
                            elevation: const WidgetStatePropertyAll(0),
                            backgroundColor: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.disabled)
                                  ? AppColors.surfaceMuted
                                  : const Color(0xFF18181B),
                            ),
                            foregroundColor: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.disabled)
                                  ? AppColors.textDisabled
                                  : Colors.white,
                            ),
                            overlayColor: const WidgetStatePropertyAll(
                              Colors.transparent,
                            ),
                            textStyle: const WidgetStatePropertyAll(
                              TextStyle(
                                fontFamily: AppTypography.primaryFontFamily,
                                fontFamilyFallback: AppTypography.fontFallbacks,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.15,
                              ),
                            ),
                          ),
                        ),
                        child: AppButton(
                          height: 48,
                          text: retryText,
                          onPressed: onRetry,
                          icon: const Icon(
                            LucideIcons.rotateCw,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
