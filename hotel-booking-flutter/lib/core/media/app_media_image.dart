import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'app_media_helper.dart';

/// Light Luxury, DPR-aware media image widget with stable [AspectRatio] support,
/// bounded `cacheWidth`/`cacheHeight` decoding, reduced-motion compliance,
/// bare neutral monochrome Lucide icons (no circle/blur/gradient backgrounds),
/// and accessible retry action (`>= 48x48dp` hit target).
class AppMediaImage extends StatelessWidget {
  final String? imageUrl;
  final String? url;
  final Uint8List? memoryBytes;
  final BoxFit fit;
  final double? width;
  final double? height;
  final double? aspectRatio;
  final Alignment alignment;
  final BorderRadius? borderRadius;
  final int maxDecodeDimensionPx;
  final String? semanticLabel;
  final VoidCallback? onRetry;
  final bool? enforceHttps;

  const AppMediaImage({
    super.key,
    this.imageUrl,
    this.url,
    this.memoryBytes,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.aspectRatio,
    this.alignment = Alignment.center,
    this.borderRadius,
    this.maxDecodeDimensionPx = AppMediaHelper.maxCardDecodeDimensionPx,
    this.semanticLabel,
    this.onRetry,
    this.enforceHttps,
  });

  static const Color _surfaceMuted = Color(0xFFF1F5F9);
  static const Color _iconNeutral = Color(0xFF717171);
  static const Color _textStrong = Color(0xFF222222);

  static bool _isReduceMotionEnabled(BuildContext context) {
    final mediaQueryDisable =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final platformReduceMotion = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.reduceMotion;
    return mediaQueryDisable || platformReduceMotion;
  }

  @override
  Widget build(BuildContext context) {
    Widget child = LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
        final effectiveLogicalWidth = width ??
            (constraints.hasBoundedWidth && constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 360.0);
        final effectiveLogicalHeight = height ??
            (constraints.hasBoundedHeight && constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : (aspectRatio != null && aspectRatio! > 0
                    ? effectiveLogicalWidth / aspectRatio!
                    : null));

        final cacheWidth = AppMediaHelper.computeDecodeDimension(
          effectiveLogicalWidth,
          devicePixelRatio: dpr,
          maxPhysicalPx: maxDecodeDimensionPx,
        );
        final cacheHeight = AppMediaHelper.computeDecodeDimension(
          effectiveLogicalHeight,
          devicePixelRatio: dpr,
          maxPhysicalPx: maxDecodeDimensionPx,
        );

        return _buildMediaContent(
          context,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
        );
      },
    );

    if (aspectRatio != null && aspectRatio! > 0) {
      child = AspectRatio(
        aspectRatio: aspectRatio!,
        child: child,
      );
    } else if (width != null || height != null) {
      child = SizedBox(
        width: width,
        height: height,
        child: child,
      );
    }

    if (borderRadius != null && borderRadius != BorderRadius.zero) {
      child = ClipRRect(
        borderRadius: borderRadius!,
        child: child,
      );
    }

    if (semanticLabel != null && semanticLabel!.trim().isNotEmpty) {
      child = Semantics(
        image: true,
        label: semanticLabel!.trim(),
        child: child,
      );
    }

    return child;
  }

  Widget _buildMediaContent(
    BuildContext context, {
    required int? cacheWidth,
    required int? cacheHeight,
  }) {
    if (memoryBytes != null) {
      if (memoryBytes!.isEmpty) {
        return _buildErrorPlaceholder(context);
      }
      return Image.memory(
        memoryBytes!,
        width: width ?? double.infinity,
        height: height ?? double.infinity,
        fit: fit,
        alignment: alignment,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        filterQuality: FilterQuality.low,
        excludeFromSemantics: semanticLabel != null,
        errorBuilder: (_, __, ___) => _buildErrorPlaceholder(context),
      );
    }

    final rawSource = (imageUrl ?? url)?.trim() ?? '';
    final resolution = AppMediaHelper.inspectMediaSource(
      rawSource,
      enforceHttps: enforceHttps,
    );

    if (resolution.isBundledAsset) {
      return Image.asset(
        resolution.bundledAssetPath!,
        width: width ?? double.infinity,
        height: height ?? double.infinity,
        fit: fit,
        alignment: alignment,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        filterQuality: FilterQuality.low,
        excludeFromSemantics: semanticLabel != null,
        errorBuilder: (_, __, ___) => _buildErrorPlaceholder(context),
      );
    }

    if (resolution.isNetworkUrl) {
      final reduceMotion = _isReduceMotionEnabled(context);
      return Image.network(
        resolution.networkUrl!,
        width: width ?? double.infinity,
        height: height ?? double.infinity,
        fit: fit,
        alignment: alignment,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        filterQuality: FilterQuality.low,
        excludeFromSemantics: semanticLabel != null,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || reduceMotion) {
            return child;
          }
          return AnimatedOpacity(
            opacity: frame == null ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: frame == null ? _buildLoadingPlaceholder() : child,
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingPlaceholder();
        },
        errorBuilder: (_, __, ___) => _buildErrorPlaceholder(context),
      );
    }

    return _buildErrorPlaceholder(context);
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      key: const ValueKey<String>('app_media_loading_placeholder'),
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      color: _surfaceMuted,
      alignment: Alignment.center,
      child: const ExcludeSemantics(
        child: Icon(
          LucideIcons.image,
          size: 24,
          color: _iconNeutral,
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder(BuildContext context) {
    return Container(
      key: const ValueKey<String>('app_media_error_placeholder'),
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      color: _surfaceMuted,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: onRetry != null
          ? Semantics(
              button: true,
              label: 'Tải lại hình ảnh',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRetry,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.refreshCw,
                        size: 20,
                        color: _textStrong,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Thử lại',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _textStrong,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const ExcludeSemantics(
              child: Icon(
                LucideIcons.imageOff,
                size: 24,
                color: _iconNeutral,
              ),
            ),
    );
  }
}
