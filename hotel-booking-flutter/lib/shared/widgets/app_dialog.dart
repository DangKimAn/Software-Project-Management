import 'package:flutter/material.dart';
import 'app_button.dart';
export '../animations/source_animations.dart'
    show AppModal, AppToast, AppToastType;

class AppDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final VoidCallback onConfirm;
  final String? cancelText;
  final VoidCallback? onCancel;
  const AppDialog(
      {super.key,
      required this.title,
      required this.message,
      required this.confirmText,
      required this.onConfirm,
      this.cancelText,
      this.onCancel});

  static Future<bool?> show(BuildContext context,
          {required String title,
          required String message,
          required String confirmText,
          String? cancelText}) =>
      showDialog<bool>(
        context: context,
        useSafeArea: true,
        animationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : const AnimationStyle(
                duration: Duration(milliseconds: 220),
                reverseDuration: Duration(milliseconds: 180)),
        builder: (ctx) => AppDialog(
            title: title,
            message: message,
            confirmText: confirmText,
            onConfirm: () => Navigator.of(ctx).pop(true),
            cancelText: cancelText,
            onCancel: () => Navigator.of(ctx).pop(false)),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Text(title),
        content: Text(message),
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          if (cancelText != null)
            AppButton.secondary(
                width: 200,
                text: cancelText!,
                onPressed: onCancel ?? () => Navigator.of(context).pop(false)),
          AppButton(width: 200, text: confirmText, onPressed: onConfirm),
        ],
      );
}
