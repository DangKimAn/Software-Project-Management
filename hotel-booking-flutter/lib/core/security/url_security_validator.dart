import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

/// Centralized URL security validator for payment redirects, admin document
/// links, presigned R2 uploads, and remote media rendering.
final class UrlSecurityValidator {
  UrlSecurityValidator._();

  static const List<String> _trustedPaymentDomains = <String>[
    'vnpayment.vn',
    'momo.vn',
  ];

  static const List<String> _trustedStorageDomains = <String>[
    'r2.cloudflarestorage.com',
    'r2.dev',
  ];

  static const List<String> _blockedExternalMediaDomains = <String>[
    'drive.google.com',
    'docs.google.com',
  ];

  static final RegExp _spreadsheetIdPattern = RegExp(
    r'^[a-zA-Z0-9-_]{20,120}$',
  );

  static final RegExp _spreadsheetPathPattern = RegExp(
    r'^/spreadsheets/d/([a-zA-Z0-9-_]{20,120})(?:/[a-zA-Z0-9-_/]*)?$',
  );

  static bool _hasUnsafeChars(String raw) {
    return raw.isEmpty || RegExp(r'[\s<>"\x00-\x1F\\]').hasMatch(raw);
  }

  static bool _isLocalLoopbackHost(String hostLower) {
    return hostLower == 'localhost' ||
        hostLower == '127.0.0.1' ||
        hostLower == '10.0.2.2' ||
        hostLower == '::1' ||
        hostLower == '[::1]';
  }

  static bool _matchesDomainOrSubdomain(String hostLower, String domain) {
    return hostLower == domain || hostLower.endsWith('.$domain');
  }

  static bool isCleartextAllowedForHost(
    String host, {
    bool? isDev,
    bool? isRelease,
  }) {
    final devMode = isDev ?? AppConfig.isDevelopment;
    final releaseMode = isRelease ?? kReleaseMode;
    if (!devMode || releaseMode) {
      return false;
    }
    return _isLocalLoopbackHost(host.trim().toLowerCase());
  }

  static Uri? _parseSafeHttpUri(
    String rawUrl, {
    bool? isDev,
    bool? isRelease,
  }) {
    final trimmed = rawUrl.trim();
    if (_hasUnsafeChars(trimmed)) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
      return null;
    }
    if (uri.userInfo.isNotEmpty) {
      return null;
    }
    final scheme = uri.scheme.toLowerCase();
    final hostLower = uri.host.toLowerCase();
    if (scheme == 'https') {
      return uri;
    }
    if (scheme == 'http' &&
        isCleartextAllowedForHost(
          hostLower,
          isDev: isDev,
          isRelease: isRelease,
        )) {
      return uri;
    }
    return null;
  }

  /// Validates external payment redirect URLs (`VNPay`, `MoMo`, or configured API host).
  static bool isValidPaymentGatewayUrl(
    String rawUrl, {
    String? apiBaseUrl,
    bool? isDev,
    bool? isRelease,
  }) {
    final uri = _parseSafeHttpUri(
      rawUrl,
      isDev: isDev,
      isRelease: isRelease,
    );
    if (uri == null) return false;

    final hostLower = uri.host.toLowerCase();
    for (final domain in _trustedPaymentDomains) {
      if (_matchesDomainOrSubdomain(hostLower, domain)) {
        return true;
      }
    }

    final configuredApiUri =
        Uri.tryParse((apiBaseUrl ?? AppConfig.apiBaseUrl).trim());
    if (configuredApiUri != null &&
        configuredApiUri.host.isNotEmpty &&
        hostLower == configuredApiUri.host.toLowerCase()) {
      return true;
    }

    if (isCleartextAllowedForHost(
      hostLower,
      isDev: isDev,
      isRelease: isRelease,
    )) {
      return true;
    }

    return false;
  }

  /// Validates private KYC / Admin document preview URLs before launching externally.
  static bool isTrustedAdminDocumentUrl(
    String rawUrl, {
    String? apiBaseUrl,
    bool? isDev,
    bool? isRelease,
  }) {
    final uri = _parseSafeHttpUri(
      rawUrl,
      isDev: isDev,
      isRelease: isRelease,
    );
    if (uri == null) return false;

    final hostLower = uri.host.toLowerCase();
    for (final blocked in _blockedExternalMediaDomains) {
      if (_matchesDomainOrSubdomain(hostLower, blocked)) {
        return false;
      }
    }

    final configuredApiUri =
        Uri.tryParse((apiBaseUrl ?? AppConfig.apiBaseUrl).trim());
    if (configuredApiUri != null &&
        configuredApiUri.host.isNotEmpty &&
        hostLower == configuredApiUri.host.toLowerCase()) {
      return true;
    }

    for (final domain in _trustedStorageDomains) {
      if (_matchesDomainOrSubdomain(hostLower, domain)) {
        return true;
      }
    }

    if (uri.scheme.toLowerCase() == 'https' &&
        (uri.queryParameters.containsKey('X-Amz-Signature') ||
            uri.queryParameters.containsKey('x-amz-signature'))) {
      return true;
    }

    if (isCleartextAllowedForHost(
      hostLower,
      isDev: isDev,
      isRelease: isRelease,
    )) {
      return true;
    }

    return false;
  }

  /// Validates presigned upload endpoints, public R2 URLs, and remote image URLs.
  /// Rejects `drive.google.com`, embedded credentials, and cleartext `http://` outside local dev.
  static bool isSafeUploadOrMediaUrl(
    String rawUrl, {
    bool? isDev,
    bool? isRelease,
  }) {
    final uri = _parseSafeHttpUri(
      rawUrl,
      isDev: isDev,
      isRelease: isRelease,
    );
    if (uri == null) return false;

    final hostLower = uri.host.toLowerCase();
    for (final blocked in _blockedExternalMediaDomains) {
      if (_matchesDomainOrSubdomain(hostLower, blocked)) {
        return false;
      }
    }

    return true;
  }

  /// Extracts a canonical Google Spreadsheet ID from either a raw ID or a strict
  /// `https://docs.google.com/spreadsheets/d/<id>` URL. Rejects SSRF / open-redirect
  /// vectors (`http://`, embedded credentials, custom ports, `..` traversal, or
  /// non-`docs.google.com` hosts).
  static String? extractGoogleSpreadsheetId(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty || trimmed.length > 512 || _hasUnsafeChars(trimmed)) {
      return null;
    }

    if (_spreadsheetIdPattern.hasMatch(trimmed)) {
      return trimmed;
    }

    if (trimmed.contains('%2e') ||
        trimmed.contains('%2E') ||
        trimmed.contains('%2f') ||
        trimmed.contains('%2F')) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.host.toLowerCase() != 'docs.google.com') {
      return null;
    }

    // `Uri.port` returns 443 for https without explicit port; reject any other port
    if (uri.hasPort && uri.port != 443) {
      return null;
    }
    if (RegExp(r'^https://docs\.google\.com:\d+', caseSensitive: false)
        .hasMatch(trimmed)) {
      return null;
    }

    if (uri.path.contains('..') || uri.path.contains('//')) {
      return null;
    }

    final match = _spreadsheetPathPattern.firstMatch(uri.path);
    return match?.group(1);
  }

  /// Strictly validates a Google Sheets browser URL before launching externally.
  static bool isValidGoogleSpreadsheetUrl(
    String rawUrl, {
    String? expectedSpreadsheetId,
  }) {
    final trimmed = rawUrl.trim();
    if (!trimmed.toLowerCase().startsWith('https://docs.google.com/')) {
      return false;
    }
    final extractedId = extractGoogleSpreadsheetId(trimmed);
    if (extractedId == null) {
      return false;
    }
    if (expectedSpreadsheetId != null &&
        expectedSpreadsheetId.trim().isNotEmpty &&
        extractedId != expectedSpreadsheetId.trim()) {
      return false;
    }
    return true;
  }

  /// Builds a guaranteed-safe canonical Google Spreadsheet URL from a validated ID.
  static String? buildCanonicalGoogleSpreadsheetUrl(String spreadsheetId) {
    final trimmed = spreadsheetId.trim();
    if (!_spreadsheetIdPattern.hasMatch(trimmed)) {
      return null;
    }
    return 'https://docs.google.com/spreadsheets/d/$trimmed/edit';
  }
}
