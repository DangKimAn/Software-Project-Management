import 'dart:io';

/// Minh Thanh Villa — Automated Secret, Mock-Ban & FLUTTER_RULES Audit Tool
///
/// Usage:
///   dart run tools/quality/secret_and_rule_audit.dart [--strict-design]
void main(List<String> args) {
  final strictDesign = args.contains('--strict-design');
  final rootDir = _resolveFlutterProjectRoot();

  stdout.writeln(
    '====================================================================',
  );
  stdout.writeln(
    ' MINH THANH VILLA — SECURITY, ZERO-MOCK & FLUTTER_RULES AUDIT GATE',
  );
  stdout.writeln(' Project Root: ${rootDir.path}');
  stdout.writeln(
    '====================================================================',
  );

  final criticalViolations = <String>[];
  final designWarnings = <String>[];

  // 1. Secret & Credential Leak Scan across lib/, test/, integration_test/, config/, .github/
  final secretPatterns = <String, RegExp>{
    'Private Key Block': RegExp(
      r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
    ),
    'Google API Key': RegExp(r'AIza[0-9A-Za-z\-_]{35}'),
    'GitHub Personal Access Token': RegExp(r'ghp_[0-9A-Za-z]{36}'),
    'Hardcoded JWT Token': RegExp(
      r'eyJhbGciOi[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}',
    ),
    'VNPay Hash Secret Assignment': RegExp(
      r'''vnp_HashSecret\s*[:=]\s*['"][A-Za-z0-9]{12,}['"]''',
      caseSensitive: false,
    ),
    'MoMo Secret Key Assignment': RegExp(
      r'''momoSecretKey\s*[:=]\s*['"][A-Za-z0-9]{12,}['"]''',
      caseSensitive: false,
    ),
  };

  final scanDirs = <Directory>[
    Directory('${rootDir.path}/lib'),
    Directory('${rootDir.path}/test'),
    Directory('${rootDir.path}/integration_test'),
    Directory('${rootDir.path}/config'),
    Directory('${rootDir.path}/.github'),
    Directory('${rootDir.parent.path}/.github'),
  ];

  for (final dir in scanDirs) {
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart') &&
          !path.endsWith('.json') &&
          !path.endsWith('.yml') &&
          !path.endsWith('.yaml')) {
        continue;
      }
      final content = entity.readAsStringSync();
      for (final entry in secretPatterns.entries) {
        if (entry.value.hasMatch(content)) {
          criticalViolations.add(
            '[SECRET-LEAK] ${entry.key} detected in ${_relPath(path, rootDir)}',
          );
        }
      }
    }
  }

  // 2. Production Zero-Mock & TLS Safety Scan in lib/
  final libDir = Directory('${rootDir.path}/lib');
  if (libDir.existsSync()) {
    final bannedProdPatterns = <String, RegExp>{
      'StandaloneBackendInterceptor in production lib/': RegExp(
        r'\bStandaloneBackendInterceptor\b',
      ),
      'badCertificateCallback TLS bypass in production lib/': RegExp(
        r'\bbadCertificateCallback\b',
      ),
      'seed_villas mock import in production lib/': RegExp(r'\bseed_villas\b'),
    };

    final offBrandColorRegex = RegExp(
      r'0xFF(?:06B6D4|0891B2|ECFEFF|22D3EE|67E8F9)\b',
      caseSensitive: false,
    );

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      final content = entity.readAsStringSync();

      for (final entry in bannedProdPatterns.entries) {
        if (entry.value.hasMatch(content)) {
          criticalViolations.add(
            '[PROD-SAFETY] ${entry.key} in ${_relPath(path, rootDir)}',
          );
        }
      }

      if (offBrandColorRegex.hasMatch(content)) {
        designWarnings.add(
          '[DESIGN-RULE-4] Off-brand Cyan/Teal hex color found in ${_relPath(path, rootDir)} (expected Coral #FF385C / #FFF1F3)',
        );
      }
    }
  }

  // 3. Check pubspec.yaml for SF Pro font configuration (FLUTTER_RULES Section 4)
  final pubspecFile = File('${rootDir.path}/pubspec.yaml');
  if (pubspecFile.existsSync()) {
    final pubspecContent = pubspecFile.readAsStringSync();
    if (!RegExp(
      r'family:\s*SF Pro Display',
      caseSensitive: false,
    ).hasMatch(pubspecContent)) {
      designWarnings.add(
        '[FONT-RULE-4] pubspec.yaml is missing SF Pro Display font family declaration',
      );
    }
  }

  // 4. Report results
  if (criticalViolations.isEmpty) {
    stdout.writeln(
      '[PASS] Zero hardcoded secrets, tokens, or production mocks found.',
    );
  } else {
    for (final v in criticalViolations) {
      stderr.writeln('  ERROR: $v');
    }
  }

  if (designWarnings.isNotEmpty) {
    stdout.writeln(
      '\n[AUDIT WARNINGS — Baseline Findings (${designWarnings.length})]:',
    );
    for (final w in designWarnings) {
      stdout.writeln('  WARN: $w');
    }
  } else {
    stdout.writeln('[PASS] Zero design/font rule warnings detected.');
  }

  if (criticalViolations.isNotEmpty ||
      (strictDesign && designWarnings.isNotEmpty)) {
    exitCode = 1;
  }
}

Directory _resolveFlutterProjectRoot() {
  final cwd = Directory.current;
  if (File('${cwd.path}/pubspec.yaml').existsSync()) {
    return cwd;
  }
  final nested = Directory('${cwd.path}/hotel-booking-flutter');
  if (File('${nested.path}/pubspec.yaml').existsSync()) {
    return nested;
  }
  return cwd;
}

String _relPath(String fullPath, Directory rootDir) {
  final normRoot = rootDir.path.replaceAll(r'\', '/');
  if (fullPath.startsWith(normRoot)) {
    return fullPath.substring(normRoot.length + 1);
  }
  return fullPath;
}
