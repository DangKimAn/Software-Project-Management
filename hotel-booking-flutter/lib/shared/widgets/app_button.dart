import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../animations/pressable_scale.dart';

enum AppButtonVariant { primary, secondary, ghost }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final Widget? icon;
  final double? width;
  final double height;
  final String? semanticLabel;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height = 50.0,
    this.semanticLabel,
  });

  const AppButton.secondary({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height = 50.0,
    this.semanticLabel,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.ghost({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height = 48.0,
    this.semanticLabel,
  }) : variant = AppButtonVariant.ghost;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;

    Color backgroundColor;
    Color foregroundColor;
    BorderSide borderSide;

    switch (variant) {
      case AppButtonVariant.primary:
        backgroundColor = isDisabled
            ? AppColors.primary.withValues(alpha: 0.5)
            : AppColors.primary;
        foregroundColor = Colors.white;
        borderSide = BorderSide.none;
        break;
      case AppButtonVariant.secondary:
        backgroundColor =
            isDisabled ? AppColors.surfaceMuted : AppColors.surfaceBase;
        foregroundColor =
            isDisabled ? AppColors.textTertiary : AppColors.textStrong;
        borderSide = BorderSide(
          color: isDisabled ? AppColors.borderSoft : AppColors.borderStrong,
        );
        break;
      case AppButtonVariant.ghost:
        backgroundColor = Colors.transparent;
        foregroundColor =
            isDisabled ? AppColors.textTertiary : AppColors.textStrong;
        borderSide = BorderSide.none;
        break;
    }

    final buttonContent = SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: Material(
        color: backgroundColor,
        shape: StadiumBorder(side: borderSide),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isDisabled ? null : onPressed,
          splashColor: variant == AppButtonVariant.primary
              ? AppColors.primaryPressed
              : AppColors.brandSoft,
          highlightColor: variant == AppButtonVariant.primary
              ? AppColors.primaryPressed.withValues(alpha: 0.3)
              : AppColors.brandSoft.withValues(alpha: 0.5),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(foregroundColor),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        IconTheme(
                          data: IconThemeData(color: foregroundColor, size: 20),
                          child: icon!,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.buttonText.copyWith(
                            color: foregroundColor,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: semanticLabel ?? text,
      child: isDisabled
          ? buttonContent
          : PressableScale(scaleDown: 0.98, child: buttonContent),
    );
  }
}

/// Circular or rounded Icon-only button with minimum 48x48 hit target for accessibility.
class AppIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.backgroundColor,
    this.iconColor,
    this.size = 48.0,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: SizedBox(
          width: size,
          height: size,
          child: Material(
            color: backgroundColor ?? Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              splashColor: AppColors.brandSoft,
              child: Center(
                child: IconTheme(
                  data: IconThemeData(
                    color: iconColor ?? AppColors.textStrong,
                    size: 20,
                  ),
                  child: icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
