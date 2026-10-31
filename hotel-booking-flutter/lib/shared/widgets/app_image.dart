import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../app/theme/app_colors.dart';
import '../../core/config/app_config.dart';
import '../../core/security/url_security_validator.dart';

/// Unified image loader supporting:
/// - Full HTTP/HTTPS URLs
/// - Backend-relative paths (`/uploads/...`) resolved against `AppConfig.apiBaseUrl`
/// - Source goc frontend asset paths (`/src/assets/img/...`, `assets/images/...`) mapped to bundled `assets/images/`
class AppImage extends StatelessWidget {
  final String? imageUrl;
  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;
  final BorderRadius? borderRadius;

  const AppImage({
    super.key,
    this.imageUrl,
    this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.borderRadius,
  });

  static const List<String> _bundledAssetFiles = [
    '19tranphu.jpg',
    '343vothisau.jpg',
    'casamar.jpg',
    'lacase.jpg',
    'diamond.jpg',
    'mocnhien.jpg',
    'nabi.JPG',
    's07.jpg',
    'sunset.jpg',
    '109tranphu.jpg',
    '11tranphu.jpg',
    '16022ahht.jpg',
    '16hahuytap.jpg',
    '1phanhuychu.jpg',
    '22012aphanchutrinh.jpg',
    '6nguyentuan.jpg',
    '87tranphu.jpg',
    'a3dtt.jpg',
    'b25thuyduong.jpg',
    'b5dtt.jpg',
    'c12tongocvan.jpg',
    'nasa.jpg',
    'osaka.jpg',
    'NDT05929-HDR1.jpg',
  ];

  static String? resolveLocalAsset(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim().replaceAll('\\', '/');
    final lowerTrimmed = trimmed.toLowerCase();
    if (lowerTrimmed.contains('images.unsplash.com') ||
        lowerTrimmed.contains('plus.unsplash.com') ||
        lowerTrimmed.contains('source.unsplash.com')) {
      final hash = trimmed.hashCode.abs();
      final mapped = _bundledAssetFiles[hash % _bundledAssetFiles.length];
      return 'assets/images/$mapped';
    }

    final lastSlash = trimmed.lastIndexOf('/');
    final basename =
        lastSlash >= 0 ? trimmed.substring(lastSlash + 1) : trimmed;
    final lowerBase = basename.toLowerCase();

    for (final file in _bundledAssetFiles) {
      if (file.toLowerCase() == lowerBase) {
        return 'assets/images/$file';
      }
    }

    if (lowerBase == 'villa_bien.jpg') {
      return 'assets/images/NDT05929-HDR1.jpg';
    }

    final anhMatch = RegExp(r'^anh_(\d+)\.jpg$').firstMatch(lowerBase);
    if (anhMatch != null) {
      final index = (int.tryParse(anhMatch.group(1)!) ?? 1) - 1;
      final mapped =
          _bundledAssetFiles[index.clamp(0, _bundledAssetFiles.length - 1)];
      return 'assets/images/$mapped';
    }

    if (trimmed.startsWith('assets/images/')) {
      return 'assets/images/19tranphu.jpg';
    }

    return null;
  }

  static String resolveNetworkUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final base = AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 1)
        : AppConfig.apiBaseUrl;
    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$base$path';
  }

  @override
  Widget build(BuildContext context) {
    final raw = (imageUrl ?? url)?.trim() ?? '';
    Widget content;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final int? targetCacheWidth = (width != null && width!.isFinite && width! > 0)
        ? (width! * dpr).round().clamp(1, 2048)
        : null;

    if (raw.isEmpty) {
      content = _buildPlaceholder();
    } else {
      final assetPath = resolveLocalAsset(raw);
      if (assetPath != null) {
        content = Image.asset(
          assetPath,
          width: width,
          height: height,
          cacheWidth: targetCacheWidth,
          fit: fit,
          alignment: alignment,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      } else {
        final resolvedUrl = resolveNetworkUrl(raw);
        if (!UrlSecurityValidator.isSafeUploadOrMediaUrl(resolvedUrl)) {
          content = _buildPlaceholder();
        } else {
          content = Image.network(
            resolvedUrl,
            width: width,
            height: height,
            cacheWidth: targetCacheWidth,
            fit: fit,
            alignment: alignment,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: width,
                height: height,
                color: AppColors.surfaceMuted,
              );
            },
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          );
        }
      }
    }

    if (borderRadius != null && borderRadius != BorderRadius.zero) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: content,
      );
    }
    return content;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.surfaceMuted,
      alignment: Alignment.center,
      child: const Icon(
        LucideIcons.image,
        size: 28,
        color: AppColors.iconMuted,
      ),
    );
  }
}
