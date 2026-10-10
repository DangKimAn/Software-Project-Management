import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_typography.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String? hintText;
  final String? labelText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool obscureText;
  final bool readOnly;
  final VoidCallback? onTap;
  final int maxLines;
  final bool autofocus;

  const AppTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.obscureText = false,
    this.readOnly = false,
    this.onTap,
    this.maxLines = 1,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMulti = maxLines > 1;
    final borderRadius = isMulti
        ? const BorderRadius.all(Radius.circular(20))
        : AppRadii.roundedPill;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (labelText != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              labelText!,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textStrong,
              ),
            ),
          ),
        ],
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          validator: validator,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          readOnly: readOnly,
          onTap: onTap,
          maxLines: maxLines,
          autofocus: autofocus,
          style: AppTypography.bodyMedium,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle:
                AppTypography.bodyMuted.copyWith(color: AppColors.textTertiary),
            prefixIcon: prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 16, right: 12),
                    child: prefixIcon,
                  )
                : null,
            prefixIconConstraints:
                const BoxConstraints(minWidth: 48, minHeight: 48),
            suffixIcon: suffixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: suffixIcon,
                  )
                : null,
            suffixIconConstraints:
                const BoxConstraints(minWidth: 48, minHeight: 48),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: isMulti ? 16 : 14,
            ),
            filled: true,
            fillColor: AppColors.surfaceBase,
            border: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: const BorderSide(color: AppColors.borderStrong),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: const BorderSide(color: AppColors.borderStrong),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide:
                  const BorderSide(color: AppColors.textStrong, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: const BorderSide(color: AppColors.errorRed),
            ),
          ),
        ),
      ],
    );
  }
}
