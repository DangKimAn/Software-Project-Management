import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Application configuration loaded at build time via `--dart-define` or `--dart-define-from-file`.
///
/// NOTE: Dart define flags are compiled into the binary and can be inspected.
/// Do NOT store sensitive private keys, database passwords, or OAuth client secrets here.
final class AppConfig {
  AppConfig._();

  static const Set<String> supportedEnvironments = {'dev', 'staging', 'prod'};

  /// Known example/placeholder phone numbers that must NEVER be treated as verified production hotlines.
  static const Set<String> knownPlaceholderPhones = {
    '0901234567',
    '0123456789',
    '0987654321',
    '0912345678',
    '0900000000',
    '0000000000',
    '1234567890',
    '0999999999',
  };

  /// Official Zalo domains permitted for OA / consultation links.
  static const Set<String> allowedZaloHosts = {
    'zalo.me',
    'www.zalo.me',
    'oa.zalo.me',
    'chat.zalo.me',
  };

  static const environment =
      String.fromEnvironment('APP_ENV', defaultValue: 'dev');
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:7000',
  );
  static const hotlineNumber = String.fromEnvironment(
    'HOTLINE_NUMBER',
    defaultValue: '0901234567',
  );
  static const zaloOaUrl = String.fromEnvironment(
    'ZALO_OA_URL',
    defaultValue: 'https://zalo.me/0901234567',
  );
  static const enableLogging =
      bool.fromEnvironment('ENABLE_LOGGING', defaultValue: true);

  /// Public Google OAuth 2.0 Client IDs (never client secrets).
  static const googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue:
        '1066515688940-7a3979894bs52fuvt95ggkvc8u63lfuq.apps.googleusercontent.com',
  );
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '1066515688940-7a3979894bs52fuvt95ggkvc8u63lfuq.apps.googleusercontent.com',
  );
  static const googleIosClientId =
      String.fromEnvironment('GOOGLE_IOS_CLIENT_ID', defaultValue: '');

  /// Custom URL scheme registered in AndroidManifest.xml and Info.plist for deep links & payment return.
  static const deepLinkScheme = String.fromEnvironment(
    'DEEP_LINK_SCHEME',
    defaultValue: 'minhthanhvilla',
  );

  /// Normalizes a raw API base URL by stripping trailing slashes and any redundant `/api` suffix
  /// so endpoint paths like `/api/listings` never produce `/api/api/listings`.
  static String normalizeApiBaseUrl(String rawUrl) {
    var normalized = rawUrl.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    while (normalized.toLowerCase().endsWith('/api')) {
      normalized = normalized.substring(0, normalized.length - 4);
      while (normalized.endsWith('/')) {
        normalized = normalized.substring(0, normalized.length - 1);
      }
    }
    return normalized;
  }

  /// Resolves the normalized API base URL, optionally remapping `localhost`/`127.0.0.1`
  /// to `10.0.2.2` when running on an Android emulator in development.
  static String resolveDeviceApiBaseUrl({
    String? rawUrl,
    TargetPlatform? platform,
    bool isWeb = kIsWeb,
    bool remapAndroidLoopback = false,
  }) {
    final normalized = normalizeApiBaseUrl(rawUrl ?? apiBaseUrl);
    if (!remapAndroidLoopback || isWeb) {
      return normalized;
    }
    final effectivePlatform = platform ?? defaultTargetPlatform;
    if (effectivePlatform != TargetPlatform.android) {
      return normalized;
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null) return normalized;
    final hostLower = uri.host.toLowerCase();
    if (hostLower == 'localhost' || hostLower == '127.0.0.1') {
      return uri.replace(host: '10.0.2.2').toString();
    }
    return normalized;
  }

  /// Resolves the effective Google OAuth Web/Server client ID for backend ID token verification.
  static String get effectiveGoogleServerClientId {
    final server = googleServerClientId.trim();
    if (server.isNotEmpty && !_isPlaceholderToken(server)) return server;
    final webOrDefault = googleClientId.trim();
    if (webOrDefault.isNotEmpty && !_isPlaceholderToken(webOrDefault)) {
      return webOrDefault;
    }
    return '';
  }

  /// Resolves the platform-appropriate Google OAuth client ID.
  static String get effectiveGoogleClientId {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final iosId = googleIosClientId.trim();
      if (iosId.isNotEmpty && !_isPlaceholderToken(iosId)) return iosId;
    }
    final client = googleClientId.trim();
    if (client.isNotEmpty && !_isPlaceholderToken(client)) return client;
    return '';
  }

  /// Returns true when a valid Google OAuth Client ID is configured.
  static bool get isGoogleOAuthConfigured =>
      effectiveGoogleClientId.isNotEmpty ||
      effectiveGoogleServerClientId.isNotEmpty;

  static bool _isPlaceholderToken(String value) {
    final lower = value.trim().toLowerCase();
    return lower.isEmpty ||
        lower.contains('your_') ||
        lower.contains('your-') ||
        lower.contains('placeholder') ||
        lower.contains('replace_with') ||
        lower.contains('changeme') ||
        lower.contains('example') ||
        lower.contains('<') ||
        lower.contains('>') ||
        lower.contains('\${');
  }

  static String _normalizePhoneDigits(String raw) {
    final clean = raw.trim().replaceAll(RegExp(r'[\s\.\-\(\)]+'), '');
    if (clean.startsWith('+84')) {
      return '0${clean.substring(3)}';
    }
    if (clean.startsWith('84') && clean.length >= 10) {
      return '0${clean.substring(2)}';
    }
    return clean;
  }

  /// Validates Vietnam phone/hotline syntax.
  static bool isValidHotlineFormat([String? rawPhone]) {
    final candidate = (rawPhone ?? hotlineNumber).trim();
    if (candidate.isEmpty) return false;
    if (candidate.contains(':') ||
        candidate.contains('/') ||
        candidate.contains('<') ||
        candidate.contains('>')) {
      return false;
    }
    final clean = candidate.replaceAll(RegExp(r'[\s\.\-\(\)]+'), '');
    final mobileOrLandline = RegExp(r'^(\+84|84|0)[1-9][0-9]{7,9}$');
    final tollFree = RegExp(r'^1[89]00[0-9]{4,6}$');
    return mobileOrLandline.hasMatch(clean) || tollFree.hasMatch(clean);
  }

  /// Detects if [rawPhone] is an unverified sample/placeholder phone (such as `0901234567`).
  static bool isPlaceholderHotline([String? rawPhone]) {
    final candidate = (rawPhone ?? hotlineNumber).trim();
    if (_isPlaceholderToken(candidate)) return true;
    if (!isValidHotlineFormat(candidate)) return true;
    final local = _normalizePhoneDigits(candidate);
    if (knownPlaceholderPhones.contains(local)) {
      return true;
    }
    if (local.length >= 8) {
      final tail = local.substring(local.length - 7);
      if (RegExp(r'^(\d)\1{6}$').hasMatch(tail)) {
        return true;
      }
    }
    return false;
  }

  /// Returns `true` only when the hotline number is valid AND not a sample placeholder.
  static bool isVerifiedHotline([String? rawPhone]) {
    return isValidHotlineFormat(rawPhone) && !isPlaceholderHotline(rawPhone);
  }

  /// Returns the verified hotline number, or `null` if the configured number is a placeholder.
  static String? get verifiedHotlineOrNull =>
      isVerifiedHotline(hotlineNumber) ? hotlineNumber.trim() : null;

  /// Validates official HTTPS Zalo OA / chat URL format.
  static bool isValidZaloUrlFormat([String? rawUrl]) {
    final candidate = (rawUrl ?? zaloOaUrl).trim();
    if (candidate.isEmpty ||
        RegExp(r'[\s<>"\x00-\x1F\\]').hasMatch(candidate)) {
      return false;
    }
    final uri = Uri.tryParse(candidate);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.userInfo.isNotEmpty) {
      return false;
    }
    if (!allowedZaloHosts.contains(uri.host.toLowerCase())) {
      return false;
    }
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return false;
    final oaId = segments.first.trim();
    return oaId.isNotEmpty &&
        oaId != '.' &&
        oaId != '..' &&
        RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(oaId);
  }

  /// Detects if [rawUrl] is an unverified sample/placeholder Zalo URL (such as `https://zalo.me/0901234567`).
  static bool isPlaceholderZaloUrl([String? rawUrl]) {
    final candidate = (rawUrl ?? zaloOaUrl).trim();
    if (_isPlaceholderToken(candidate)) return true;
    if (!isValidZaloUrlFormat(candidate)) return true;
    final uri = Uri.parse(candidate);
    final identifier =
        uri.pathSegments.firstWhere((s) => s.isNotEmpty).toLowerCase();
    if (identifier == 'test' ||
        identifier == 'demo' ||
        identifier.contains('sample')) {
      return true;
    }
    if (RegExp(r'^\+?\d+$').hasMatch(identifier)) {
      return isPlaceholderHotline(identifier);
    }
    return false;
  }

  /// Returns `true` only when the Zalo URL is valid AND not a sample placeholder.
  static bool isVerifiedZaloUrl([String? rawUrl]) {
    return isValidZaloUrlFormat(rawUrl) && !isPlaceholderZaloUrl(rawUrl);
  }

  /// Returns the verified Zalo OA URL, or `null` if the configured URL is a placeholder.
  static String? get verifiedZaloUrlOrNull =>
      isVerifiedZaloUrl(zaloOaUrl) ? zaloOaUrl.trim() : null;

  /// Indicates whether the current build still contains sample/placeholder contact config.
  static bool get hasUnverifiedContactPlaceholders =>
      isPlaceholderHotline(hotlineNumber) || isPlaceholderZaloUrl(zaloOaUrl);

  /// Audits the active configuration and returns non-PII diagnostic warnings.
  static List<String> auditConfiguration({
    String? currentEnvironment,
    String? currentApiBaseUrl,
    String? currentHotline,
    String? currentZaloUrl,
    String? buildFlavor,
    bool isReleaseBuild = kReleaseMode,
  }) {
    final warnings = <String>[];
    final env = (currentEnvironment ?? environment).trim().toLowerCase();
    final rawUrl = (currentApiBaseUrl ?? apiBaseUrl).trim();
    final hotline = (currentHotline ?? hotlineNumber).trim();
    final zalo = (currentZaloUrl ?? zaloOaUrl).trim();

    if (rawUrl.toLowerCase().endsWith('/api') ||
        rawUrl.toLowerCase().endsWith('/api/')) {
      warnings.add(
        'API_BASE_URL contains a trailing "/api" segment; DioClient normalizes it to prevent "/api/api" duplication.',
      );
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri != null &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
      warnings.add(
        'API_BASE_URL uses "${uri.host}" on Android target; Android Emulator requires "10.0.2.2" or "adb reverse tcp:${uri.hasPort ? uri.port : 7000} tcp:${uri.hasPort ? uri.port : 7000}".',
      );
    }

    if (isPlaceholderHotline(hotline)) {
      warnings.add(
        'HOTLINE_NUMBER is using an unverified placeholder value in [$env] config.',
      );
    }

    if (isPlaceholderZaloUrl(zalo)) {
      warnings.add(
        'ZALO_OA_URL is using an unverified placeholder value in [$env] config.',
      );
    }

    return warnings;
  }

  /// Resolves the expected environment from explicit entrypoint argument, native build flavor
  /// (`appFlavor`), or build mode (`kReleaseMode`), without ever comparing `AppConfig.environment`
  /// against itself.
  static String resolveExpectedEnvironment({
    String? explicitExpectedEnvironment,
    String? buildFlavor,
    bool isReleaseBuild = kReleaseMode,
  }) {
    final explicit = explicitExpectedEnvironment?.trim().toLowerCase();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }

    final flavor = (buildFlavor ?? appFlavor)?.trim().toLowerCase();
    if (flavor != null && flavor.isNotEmpty) {
      return flavor;
    }

    // Release builds without an explicit flavor must target production.
    // Debug/Profile builds without a flavor default to 'dev' for local development.
    return isReleaseBuild ? 'prod' : 'dev';
  }

  /// Validates environment consistency, flavor alignment, and HTTPS security at startup.
  static void validate({
    required String expectedEnvironment,
    String? currentEnvironment,
    String? currentApiBaseUrl,
    String? currentHotline,
    String? currentZaloUrl,
    String? buildFlavor,
    bool isReleaseBuild = kReleaseMode,
    bool enforceVerifiedContactsInProd = false,
  }) {
    final env = (currentEnvironment ?? environment).trim().toLowerCase();
    final expected = expectedEnvironment.trim().toLowerCase();
    final rawUrl = (currentApiBaseUrl ?? apiBaseUrl).trim();
    final effectiveFlavor = buildFlavor?.trim().toLowerCase();

    if (!supportedEnvironments.contains(expected)) {
      throw StateError(
        'Build environment mismatch: Unsupported expected environment "$expectedEnvironment".',
      );
    }

    if (!supportedEnvironments.contains(env)) {
      throw StateError(
        'Build environment mismatch: Unsupported APP_ENV "$env".',
      );
    }

    if (env != expected) {
      throw StateError(
        'Build environment mismatch: Expected "$expectedEnvironment" but received "$env".',
      );
    }

    if (effectiveFlavor != null &&
        effectiveFlavor.isNotEmpty &&
        effectiveFlavor != env) {
      throw StateError(
        'Build flavor mismatch: Native flavor "$effectiveFlavor" does not match APP_ENV "$env".',
      );
    }

    if (isReleaseBuild && env == 'dev') {
      throw StateError(
        'Security gate violation: Release builds MUST NOT run with APP_ENV="dev".',
      );
    }

    if (_isPlaceholderToken(rawUrl)) {
      throw StateError(
        'Invalid API_BASE_URL "$rawUrl": Placeholder URL is not allowed.',
      );
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw StateError('Invalid API_BASE_URL "$rawUrl".');
    }

    final hostLower = uri.host.toLowerCase();
    final isLocalHost = hostLower == 'localhost' ||
        hostLower == '127.0.0.1' ||
        hostLower == '10.0.2.2' ||
        hostLower == '0.0.0.0';
    final isDevHost = isLocalHost ||
        hostLower.startsWith('dev.') ||
        hostLower.startsWith('dev-');
    final isStagingHost =
        hostLower.startsWith('staging.') || hostLower.startsWith('staging-');

    // Staging, Production, and any Release build must strictly use HTTPS.
    if ((env != 'dev' || isReleaseBuild) && uri.scheme != 'https') {
      throw StateError(
        'Invalid API_BASE_URL "$rawUrl": Production, Staging, and Release builds MUST use secure HTTPS.',
      );
    }

    // Prevent production or release builds from accidentally pointing at a development or staging API.
    if ((env == 'prod' || (isReleaseBuild && env != 'staging')) &&
        (isDevHost || isStagingHost)) {
      throw StateError(
        'Invalid API_BASE_URL "$rawUrl": Production/Release build cannot target non-production host "${uri.host}".',
      );
    }

    if (enforceVerifiedContactsInProd && env == 'prod') {
      final hotlineToCheck = currentHotline ?? hotlineNumber;
      final zaloToCheck = currentZaloUrl ?? zaloOaUrl;
      if (isPlaceholderHotline(hotlineToCheck)) {
        throw StateError(
          'Unverified HOTLINE_NUMBER placeholder in production configuration.',
        );
      }
      if (isPlaceholderZaloUrl(zaloToCheck)) {
        throw StateError(
          'Unverified ZALO_OA_URL placeholder in production configuration.',
        );
      }
    }
  }

  static bool get isProduction => environment == 'prod';
  static bool get isStaging => environment == 'staging';
  static bool get isDevelopment => environment == 'dev';
}
