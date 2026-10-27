import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Border? border;
  final bool showShadow;
  const AppCard(
      {super.key,
      required this.child,
      this.padding,
      this.margin,
      this.onTap,
      this.backgroundColor,
      this.border,
      this.showShadow = true});

  @override
  Widget build(BuildContext context) {
    final shape = Theme.of(context).cardTheme.shape;
    return Card(
      margin: margin,
      color: backgroundColor,
      elevation: showShadow ? null : 0,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: border == null
            ? null
            : BoxDecoration(
                border: border,
                borderRadius:
                    shape is RoundedRectangleBorder ? shape.borderRadius : null,
              ),
        child: InkWell(
            onTap: onTap,
            customBorder: shape,
            child: Padding(
                padding: padding ?? const EdgeInsets.all(16), child: child)),
      ),
    );
  }
}
