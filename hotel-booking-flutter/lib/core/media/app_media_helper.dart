import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import '../config/app_config.dart';

/// Reasons why a raw media URL or path is rejected before network/asset loading.
enum AppMediaUrlRejectReason {
  /// Empty string, whitespace-only, or literal serialization tokens (`null`, `undefined`, `NaN`).
  emptyOrPlaceholderToken,

  /// Dangerous or non-image URI schemes (`javascript:`, `data:`, `file:`, `ftp:`, `mailto:`, `tel:`).
  unsupportedOrDangerousScheme,

  /// Protocol-relative URL (`//example.com/photo.jpg`) that could be misresolved against API base URL.
  protocolRelativeUrl,

  /// URI has an invalid syntax, control characters, empty host (`https://`), or invalid port.
  malformedUriOrEmptyHost,

  /// Unstable or private hotlink forbidden by `FLUTTER_RULES.md` Section 7.1 (e.g. Google Drive links).
  unstablePrivateHotlink,

  /// Cleartext `http://` URL targeting a non-local host when HTTPS is required.
  cleartextHttpDisallowed,
}

/// Immutable result of inspecting and normalizing a raw media source string.
@immutable
class AppMediaSourceResolution {
  final String rawInput;
  final String? bundledAssetPath;
  final String? networkUrl;
  final AppMediaUrlRejectReason? rejectReason;

  const AppMediaSourceResolution._({
    required this.rawInput,
    this.bundledAssetPath,
    this.networkUrl,
    this.rejectReason,
  });

  const AppMediaSourceResolution.bundledAsset({
    required String rawInput,
    required String assetPath,
  }) : this._(
          rawInput: rawInput,
          bundledAssetPath: assetPath,
        );

  const AppMediaSourceResolution.network({
    required String rawInput,
    required String resolvedUrl,
  }) : this._(
          rawInput: rawInput,
          networkUrl: resolvedUrl,
        );

  const AppMediaSourceResolution.rejected({
    required String rawInput,
    required AppMediaUrlRejectReason reason,
  }) : this._(
          rawInput: rawInput,
          rejectReason: reason,
        );

  bool get isBundledAsset => bundledAssetPath != null;
  bool get isNetworkUrl => networkUrl != null;
  bool get isValid => isBundledAsset || isNetworkUrl;
  bool get isRejected => rejectReason != null;
}

/// Core media, asset, decode-sizing, cache-bounding, and font-fallback utilities
/// compliant with `FLUTTER_RULES.md` Sections 4, 6, 7.1, 13, 14, and 15.
abstract final class AppMediaHelper {
  /// Default high-resolution hero fallback asset (`1920x1280`).
  static const String defaultHeroFallbackAsset =
      'assets/images/NDT05929-HDR1.jpg';

  /// Secondary villa card fallback asset (`1920x1440`).
  static const String secondaryVillaFallbackAsset =
      'assets/images/19tranphu.jpg';

  /// Canonical bundled raster image files in `assets/images/` (exact case preserved, e.g. `nabi.JPG`).
  static const List<String> bundledRasterImageFiles = [
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

  /// Canonical bundled vector & icon assets.
  static const String brandLogoSvgAsset = 'assets/images/logo_mau.svg';
  static const String brandAppIconPngAsset = 'assets/icons/app_icon.png';

  static const Set<String> _invalidLiteralTokens = {
    'null',
    'undefined',
    'nan',
    'none',
    'false',
    '[object object]',
  };

  static const Set<String> _disallowedSchemes = {
    'javascript',
    'vbscript',
    'data',
    'file',
    'ftp',
    'blob',
    'about',
    'intent',
    'tel',
    'mailto',
    'ws',
    'wss',
  };

  static const Set<String> _blockedHotlinkHosts = {
    'drive.google.com',
    'docs.google.com',
  };

  /// Standard mobile card aspect ratio (4:3) per `FLUTTER_RULES.md` Section 7.1.
  static const double mobileCardAspectRatio = 4.0 / 3.0;

  /// Standard gallery / tablet card aspect ratio (16:10) per `FLUTTER_RULES.md` Section 7.1 & 8.
  static const double galleryAspectRatio = 16.0 / 10.0;

  /// Maximum physical decode width/height for list cards to prevent multi-megabyte RGBA buffers.
  static const int maxCardDecodeDimensionPx = 1080;

  /// Maximum physical decode width/height for hero/detail galleries.
  static const int maxHeroDecodeDimensionPx = 1600;

  /// Resolves a raw path or filename to a verified bundled asset path in `assets/`,
  /// or returns `null` if the input does not refer to a local asset.
  ///
  /// Handles case-insensitive matching for `assets/images/nabi.JPG`, legacy web paths
  /// (`/src/assets/img/...`), `villa_bien.jpg`, and numbered `anh_1.jpg`..`anh_24.jpg`.
  static String? resolveBundledAssetPath(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim().replaceAll('\\', '/');
    if (trimmed.isEmpty) return null;

    // Strip query string or fragment if present on a local asset path
    final cleanPath = trimmed.split('?').first.split('#').first.trim();
    if (cleanPath.isEmpty) return null;

    final lowerClean = cleanPath.toLowerCase();
    if (_invalidLiteralTokens.contains(lowerClean)) return null;

    // If it has a URI scheme (e.g. https://, http://, javascript:), it is not a bundled asset
    if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+\-.]*:').hasMatch(cleanPath)) {
      return null;
    }

    if (lowerClean == 'assets/icons/app_icon.png' ||
        lowerClean == 'app_icon.png') {
      return brandAppIconPngAsset;
    }

    if (lowerClean == 'assets/images/logo_mau.svg' ||
        lowerClean == 'logo_mau.svg') {
      return brandLogoSvgAsset;
    }

    final lastSlash = cleanPath.lastIndexOf('/');
    final basename =
        lastSlash >= 0 ? cleanPath.substring(lastSlash + 1) : cleanPath;
    final lowerBase = basename.toLowerCase();

    for (final file in bundledRasterImageFiles) {
      if (file.toLowerCase() == lowerBase) {
        return 'assets/images/$file';
      }
    }

    if (lowerBase == 'villa_bien.jpg') {
      return defaultHeroFallbackAsset;
    }

    final anhMatch = RegExp(r'^anh_(\d+)\.jpg$').firstMatch(lowerBase);
    if (anhMatch != null) {
      final parsedIndex = int.tryParse(anhMatch.group(1)!) ?? 1;
      final clampedIndex =
          (parsedIndex - 1).clamp(0, bundledRasterImageFiles.length - 1);
      return 'assets/images/${bundledRasterImageFiles[clampedIndex]}';
    }

    if (lowerClean.startsWith('assets/images/') ||
        lowerClean.startsWith('/src/assets/') ||
        lowerClean.startsWith('src/assets/')) {
      return secondaryVillaFallbackAsset;
    }

    return null;
  }

  /// Inspects a raw media source and classifies it as a bundled asset, a sanitized
  /// network URL, or a rejected source with a specific [AppMediaUrlRejectReason].
  static AppMediaSourceResolution inspectMediaSource(
    String? raw, {
    String? apiBaseUrl,
    bool? enforceHttps,
  }) {
    final input = raw ?? '';
    final trimmed = input.trim();
    if (trimmed.isEmpty ||
        _invalidLiteralTokens.contains(trimmed.toLowerCase())) {
      return AppMediaSourceResolution.rejected(
        rawInput: input,
        reason: AppMediaUrlRejectReason.emptyOrPlaceholderToken,
      );
    }

    // Reject control characters or embedded newlines
    if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(trimmed)) {
      return AppMediaSourceResolution.rejected(
        rawInput: input,
        reason: AppMediaUrlRejectReason.malformedUriOrEmptyHost,
      );
    }

    // Reject protocol-relative URLs (`//example.com/image.jpg`)
    final normalizedSlashes = trimmed.replaceAll('\\', '/');
    if (normalizedSlashes.startsWith('//')) {
      return AppMediaSourceResolution.rejected(
        rawInput: input,
        reason: AppMediaUrlRejectReason.protocolRelativeUrl,
      );
    }

    // Check if it resolves to a bundled local asset first
    final assetPath = resolveBundledAssetPath(trimmed);
    if (assetPath != null) {
      return AppMediaSourceResolution.bundledAsset(
        rawInput: input,
        assetPath: assetPath,
      );
    }

    // Check explicit URI scheme
    final schemeMatch =
        RegExp(r'^([a-zA-Z][a-zA-Z0-9+\-.]*):(.*)$').firstMatch(trimmed);
    String candidateUrl;
    if (schemeMatch != null) {
      final scheme = schemeMatch.group(1)!.toLowerCase();
      if (_disallowedSchemes.contains(scheme) ||
          (scheme != 'http' && scheme != 'https')) {
        return AppMediaSourceResolution.rejected(
          rawInput: input,
          reason: AppMediaUrlRejectReason.unsupportedOrDangerousScheme,
        );
      }
      final remainder = schemeMatch.group(2) ?? '';
      if (!remainder.startsWith('//')) {
        return AppMediaSourceResolution.rejected(
          rawInput: input,
          reason: AppMediaUrlRejectReason.malformedUriOrEmptyHost,
        );
      }
      candidateUrl = trimmed;
    } else {
      // Relative path from backend (e.g. `/uploads/villas/img1.jpg` or `uploads/villas/img1.jpg`)
      final effectiveBase = (apiBaseUrl ?? AppConfig.apiBaseUrl).trim();
      if (effectiveBase.isEmpty) {
        return AppMediaSourceResolution.rejected(
          rawInput: input,
          reason: AppMediaUrlRejectReason.malformedUriOrEmptyHost,
        );
      }
      final cleanBase = effectiveBase.endsWith('/')
          ? effectiveBase.substring(0, effectiveBase.length - 1)
          : effectiveBase;
      final cleanRel = normalizedSlashes.startsWith('/')
          ? normalizedSlashes
          : '/$normalizedSlashes';
      candidateUrl = '$cleanBase$cleanRel';
    }

    final encodedCandidate = _encodeUrlSpacesAndUnicode(candidateUrl);
    final uri = Uri.tryParse(encodedCandidate);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        uri.host.trim().isEmpty) {
      return AppMediaSourceResolution.rejected(
        rawInput: input,
        reason: AppMediaUrlRejectReason.malformedUriOrEmptyHost,
      );
    }

    final hostLower = uri.host.toLowerCase();
    if (hostLower.startsWith('.') ||
        hostLower.endsWith('.') ||
        hostLower.contains('..') ||
        hostLower.contains(' ')) {
      return AppMediaSourceResolution.rejected(
        rawInput: input,
        reason: AppMediaUrlRejectReason.malformedUriOrEmptyHost,
      );
    }

    if (uri.hasPort && (uri.port <= 0 || uri.port > 65535)) {
      return AppMediaSourceResolution.rejected(
        rawInput: input,
        reason: AppMediaUrlRejectReason.malformedUriOrEmptyHost,
      );
    }

    // Block private/unstable Google Drive hotlinks per FLUTTER_RULES.md Section 7.1
    if (_blockedHotlinkHosts.contains(hostLower) ||
        hostLower.endsWith('.googleusercontent.com') &&
            uri.path.contains('/drive')) {
      return AppMediaSourceResolution.rejected(
        rawInput: input,
        reason: AppMediaUrlRejectReason.unstablePrivateHotlink,
      );
    }

    final isLocalDevHost = hostLower == 'localhost' ||
        hostLower == '127.0.0.1' ||
        hostLower == '10.0.2.2';
    final mustUseHttps =
        enforceHttps ?? (!AppConfig.isDevelopment || kReleaseMode);

    if (uri.scheme == 'http' && mustUseHttps && !isLocalDevHost) {
      return AppMediaSourceResolution.rejected(
        rawInput: input,
        reason: AppMediaUrlRejectReason.cleartextHttpDisallowed,
      );
    }

    return AppMediaSourceResolution.network(
      rawInput: input,
      resolvedUrl: uri.toString(),
    );
  }

  /// Convenience helper that returns a validated HTTP/HTTPS URL string, or `null` if invalid/unsafe.
  static String? sanitizeAndResolveNetworkUrl(
    String? raw, {
    String? apiBaseUrl,
    bool? enforceHttps,
  }) {
    final resolution = inspectMediaSource(
      raw,
      apiBaseUrl: apiBaseUrl,
      enforceHttps: enforceHttps,
    );
    return resolution.networkUrl;
  }

  static String _encodeUrlSpacesAndUnicode(String rawUrl) {
    final buffer = StringBuffer();
    for (final rune in rawUrl.runes) {
      if (rune == 0x20) {
        buffer.write('%20');
      } else if (rune > 0x7F) {
        final encoded = Uri.encodeComponent(String.fromCharCode(rune));
        buffer.write(encoded);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  /// Calculates an optimal physical pixel decode dimension (`cacheWidth` / `cacheHeight`)
  /// for [logicalExtent] and [devicePixelRatio], clamped to `[minPhysicalPx, maxPhysicalPx]`.
  ///
  /// Returns `null` if [logicalExtent] is null, non-finite, or `<= 0`.
  static int? computeDecodeDimension(
    double? logicalExtent, {
    required double devicePixelRatio,
    int maxPhysicalPx = maxCardDecodeDimensionPx,
    int minPhysicalPx = 64,
  }) {
    if (logicalExtent == null ||
        !logicalExtent.isFinite ||
        logicalExtent <= 0) {
      return null;
    }
    final safeDpr = devicePixelRatio.isFinite && devicePixelRatio > 0
        ? devicePixelRatio.clamp(1.0, 3.0)
        : 2.0;
    final rawPhysical = (logicalExtent * safeDpr).round();
    return rawPhysical.clamp(minPhysicalPx, maxPhysicalPx);
  }

  /// Computes paired `(cacheWidth, cacheHeight)` physical decode dimensions for a fixed
  /// [aspectRatio] frame (e.g. `4 / 3` mobile card or `16 / 10` detail gallery).
  static ({int cacheWidth, int cacheHeight}) computeDecodeSizeForAspectRatio({
    required double logicalWidth,
    required double aspectRatio,
    required double devicePixelRatio,
    int maxPhysicalDimension = maxCardDecodeDimensionPx,
    int minPhysicalDimension = 64,
  }) {
    final safeAspect = aspectRatio.isFinite && aspectRatio > 0
        ? aspectRatio
        : mobileCardAspectRatio;
    final safeWidth =
        logicalWidth.isFinite && logicalWidth > 0 ? logicalWidth : 360.0;
    final widthPx = computeDecodeDimension(
          safeWidth,
          devicePixelRatio: devicePixelRatio,
          maxPhysicalPx: maxPhysicalDimension,
          minPhysicalPx: minPhysicalDimension,
        ) ??
        720;
    final heightPx = (widthPx / safeAspect)
        .round()
        .clamp(minPhysicalDimension, maxPhysicalDimension);
    return (cacheWidth: widthPx, cacheHeight: heightPx);
  }

  /// Estimates the uncompressed RGBA8888 bitmap memory footprint in bytes (`width * height * 4`).
  static int estimateDecodedBytes({
    required int widthPx,
    required int heightPx,
  }) {
    if (widthPx <= 0 || heightPx <= 0) return 0;
    return widthPx * heightPx * 4;
  }

  /// Wraps [provider] with [ResizeImage] when [cacheWidth] or [cacheHeight] is specified,
  /// preventing full-resolution decoding in memory.
  static ImageProvider<Object> wrapWithResizeIfNeeded(
    ImageProvider<Object> provider, {
    int? cacheWidth,
    int? cacheHeight,
  }) {
    return ResizeImage.resizeIfNeeded(cacheWidth, cacheHeight, provider);
  }

  /// Configures bounded capacity on Flutter's global [ImageCache] to prevent OOM
  /// when scrolling long villa discovery lists.
  static void configureImageCacheBounds({
    ImageCache? imageCache,
    int maximumSize = 120,
    int maximumSizeBytes = 60 * 1024 * 1024, // 60 MB
  }) {
    final cache = imageCache ?? PaintingBinding.instance.imageCache;
    cache.maximumSize = maximumSize.clamp(20, 500);
    cache.maximumSizeBytes =
        maximumSizeBytes.clamp(16 * 1024 * 1024, 256 * 1024 * 1024);
  }

  /// Returns true if an asset path points to a bundled SF Pro font file (`SF-Pro*.otf`, `SF-Pro*.ttf`).
  static bool isSfProFontAsset(String assetPath) {
    final lower = assetPath.trim().toLowerCase().replaceAll('\\', '/');
    final filename = lower.split('/').last;
    return (filename.startsWith('sf-pro') ||
            filename.startsWith('sfpro') ||
            filename.startsWith('sanfrancisco')) &&
        (filename.endsWith('.otf') || filename.endsWith('.ttf'));
  }

  /// Returns the SF Pro primary font family fallback chain for `vi`, `en`, and `ko`
  /// across iOS and Android (`FLUTTER_RULES.md` Section 4):
  /// - Uses bundled `SF Pro Display` / `SF Pro Text` / `SF Pro Rounded` / `SF Pro` first.
  /// - Falls back to `Apple SD Gothic Neo` / `Noto Sans KR` (for Korean), `Be Vietnam Pro`, `Roboto`, `sans-serif`.
  static List<String> licensedFontFallbacksForLanguage(
    String? languageCode, {
    TargetPlatform? platform,
  }) {
    final effectivePlatform = platform ?? defaultTargetPlatform;
    final lang = (languageCode ?? 'vi').trim().toLowerCase();
    final isApple = effectivePlatform == TargetPlatform.iOS ||
        effectivePlatform == TargetPlatform.macOS;

    if (isApple) {
      return <String>[
        'SF Pro Display',
        'SF Pro Text',
        'SF Pro Rounded',
        'SF Pro',
        '.AppleSystemUIFont',
        if (lang == 'ko') 'Apple SD Gothic Neo',
        'Noto Sans KR',
        'Be Vietnam Pro',
        'sans-serif',
      ];
    }

    return <String>[
      'SF Pro Display',
      'SF Pro Text',
      'SF Pro Rounded',
      'SF Pro',
      if (lang == 'ko') 'Noto Sans KR',
      'Be Vietnam Pro',
      'Roboto',
      if (lang != 'ko') 'Noto Sans KR',
      'Noto Sans',
      'Segoe UI',
      'Malgun Gothic',
      'sans-serif',
    ];
  }
}
