import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Application configuration loaded at build time via `--dart-define` or `--dart-define-from-file`.
///
/// NOTE: Dart define flags are compiled into the binary and can be inspected.
/// Do NOT store sensitive private keys, database passwords, or OAuth client secrets here.
final class AppConfig {
  AppConfig._();

  static const Set<String> supportedEnvironments = {'dev', 'staging', 'prod'};

  static const environment =
      String.fromEnvironment('APP_ENV', defaultValue: 'dev');
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://dev-api.minhthanhvilla.com',
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
  static const googleClientId =
      String.fromEnvironment('GOOGLE_CLIENT_ID', defaultValue: '');
  static const googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID', defaultValue: '');
  static const googleIosClientId =
      String.fromEnvironment('GOOGLE_IOS_CLIENT_ID', defaultValue: '');

  /// Custom URL scheme registered in AndroidManifest.xml and Info.plist for deep links & payment return.
  static const deepLinkScheme = String.fromEnvironment(
    'DEEP_LINK_SCHEME',
    defaultValue: 'minhthanhvilla',
  );

  /// Resolves the effective Google OAuth Web/Server client ID for backend ID token verification.
  static String get effectiveGoogleServerClientId {
    final server = googleServerClientId.trim();
    if (server.isNotEmpty && !_isPlaceholder(server)) return server;
    final webOrDefault = googleClientId.trim();
    if (webOrDefault.isNotEmpty && !_isPlaceholder(webOrDefault)) {
      return webOrDefault;
    }
    return '';
  }

  /// Resolves the platform-appropriate Google OAuth client ID.
  static String get effectiveGoogleClientId {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final iosId = googleIosClientId.trim();
      if (iosId.isNotEmpty && !_isPlaceholder(iosId)) return iosId;
    }
    final client = googleClientId.trim();
    if (client.isNotEmpty && !_isPlaceholder(client)) return client;
    return '';
  }

  /// Returns true when a valid Google OAuth Client ID is configured.
  static bool get isGoogleOAuthConfigured =>
      effectiveGoogleClientId.isNotEmpty ||
      effectiveGoogleServerClientId.isNotEmpty;

  static bool _isPlaceholder(String value) {
    final lower = value.toLowerCase();
    return lower.contains('your_') ||
        lower.contains('placeholder') ||
        lower.contains('replace_with') ||
        lower.contains('changeme') ||
        lower.contains('\${');
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
    String? buildFlavor,
    bool isReleaseBuild = kReleaseMode,
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

    final uri = Uri.tryParse(rawUrl);
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw StateError('Invalid API_BASE_URL "$rawUrl".');
    }

    final hostLower = uri.host.toLowerCase();
    final isLocalHost = hostLower == 'localhost' ||
        hostLower == '127.0.0.1' ||
        hostLower == '10.0.2.2';
    final isDevHost = isLocalHost ||
        hostLower.startsWith('dev.') ||
        hostLower.startsWith('dev-');

    // Staging, Production, and any Release build must strictly use HTTPS.
    if ((env != 'dev' || isReleaseBuild) && uri.scheme != 'https') {
      throw StateError(
        'Invalid API_BASE_URL "$rawUrl": Production, Staging, and Release builds MUST use secure HTTPS.',
      );
    }

    // Prevent production or release builds from accidentally pointing at a development API.
    if ((env == 'prod' || (isReleaseBuild && env != 'staging')) && isDevHost) {
      throw StateError(
        'Invalid API_BASE_URL "$rawUrl": Production/Release build cannot target development host "${uri.host}".',
      );
    }
  }

  static bool get isProduction => environment == 'prod';
  static bool get isStaging => environment == 'staging';
  static bool get isDevelopment => environment == 'dev';
}
