import 'dart:math' as math;
import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, ghost }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final Widget? icon;
  final double? width;

  /// Minimum height; grows with text scaling and wrapped labels.
  final double height;
  final String? semanticLabel;

  const AppButton(
      {super.key,
      required this.text,
      required this.onPressed,
      this.variant = AppButtonVariant.primary,
      this.isLoading = false,
      this.icon,
      this.width,
      this.height = 50,
      this.semanticLabel});
  const AppButton.secondary(
      {super.key,
      required this.text,
      required this.onPressed,
      this.isLoading = false,
      this.icon,
      this.width,
      this.height = 50,
      this.semanticLabel})
      : variant = AppButtonVariant.secondary;
  const AppButton.ghost(
      {super.key,
      required this.text,
      required this.onPressed,
      this.isLoading = false,
      this.icon,
      this.width,
      this.height = 48,
      this.semanticLabel})
      : variant = AppButtonVariant.ghost;

  @override
  Widget build(BuildContext context) {
    final callback = isLoading ? null : onPressed;
    final content = Semantics(
      label: semanticLabel ?? text,
      liveRegion: isLoading,
      child: ExcludeSemantics(
          child: Stack(
        alignment: Alignment.center,
        children: [
          // Preserve label dimensions while loading so surrounding content stays still.
          Opacity(
              opacity: isLoading ? 0 : 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 8)],
                  Flexible(child: Text(text, textAlign: TextAlign.center)),
                ],
              )),
          if (isLoading)
            SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  value: MediaQuery.disableAnimationsOf(context) ? .75 : null,
                  strokeWidth: 2,
                )),
        ],
      )),
    );
    final button = switch (variant) {
      AppButtonVariant.primary =>
        FilledButton(onPressed: callback, child: content),
      AppButtonVariant.secondary =>
        OutlinedButton(onPressed: callback, child: content),
      AppButtonVariant.ghost => TextButton(onPressed: callback, child: content),
    };
    return SizedBox(
        width: width ?? double.infinity,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: math.max(48, height)),
          child: button,
        ));
  }
}

/// Bare icon with a transparent, keyboard accessible hit target of at least 48dp.
class AppIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String tooltip;

  /// Retained for caller compatibility. Icon actions always have a transparent background.
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  const AppIconButton(
      {super.key,
      required this.icon,
      required this.onPressed,
      required this.tooltip,
      this.backgroundColor,
      this.iconColor,
      this.size = 48});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: math.max(48, size),
        height: math.max(48, size),
        child: Tooltip(
          message: tooltip,
          excludeFromSemantics: true,
          child: Semantics(
            label: tooltip,
            child: IconButton(
              onPressed: onPressed,
              style: const ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(Colors.transparent)),
              color: iconColor,
              icon: icon,
            ),
          ),
        ),
      );
}
