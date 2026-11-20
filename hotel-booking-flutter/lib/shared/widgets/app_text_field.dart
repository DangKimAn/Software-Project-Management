import 'package:flutter/material.dart';

/// Trường nhập văn bản chuẩn hóa theo hệ thống thiết kế Light Luxury.
///
/// Giải thuật bảo vệ dữ liệu nhạy cảm và vùng chạm chuẩn:
/// - Khi bật chế độ mật khẩu (`obscureText == true`), tự động tắt gợi ý bàn phím (`enableSuggestions`), tự sửa lỗi (`autocorrect`), học cá nhân hóa IME (`enableIMEPersonalizedLearning`) và cưỡng bức `maxLines = 1`.
/// - Đảm bảo vùng chạm tối thiểu `48x48` logical pixel cho `prefixIcon` và `suffixIcon` theo `FLUTTER_RULES.md`.
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
  final Iterable<String>? autofillHints;
  final bool? enableSuggestions;
  final bool? autocorrect;
  final bool? enableIMEPersonalizedLearning;
  const AppTextField(
      {super.key,
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
      this.autofillHints,
      this.enableSuggestions,
      this.autocorrect,
      this.enableIMEPersonalizedLearning});

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        initialValue: initialValue,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        validator: validator,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        obscureText: obscureText,
        enableSuggestions: enableSuggestions ?? !obscureText,
        autocorrect: autocorrect ?? !obscureText,
        enableIMEPersonalizedLearning:
            enableIMEPersonalizedLearning ?? !obscureText,
        readOnly: readOnly,
        onTap: onTap,
        maxLines: obscureText ? 1 : maxLines,
        autofocus: autofocus,
        autofillHints: autofillHints,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: hintText,
          labelText: labelText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          prefixIconConstraints:
              const BoxConstraints(minWidth: 48, minHeight: 48),
          suffixIconConstraints:
              const BoxConstraints(minWidth: 48, minHeight: 48),
        ),
      );
}
