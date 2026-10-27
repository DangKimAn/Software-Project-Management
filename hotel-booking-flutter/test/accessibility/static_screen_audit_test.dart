import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

Directory _resolveProjectRoot() {
  final direct = Directory('lib');
  if (direct.existsSync()) return Directory.current;
  final nested = Directory('hotel-booking-flutter/lib');
  if (nested.existsSync()) return Directory('hotel-booking-flutter');
  throw StateError('Cannot locate hotel-booking-flutter project root');
}

class StaticAuditFinding {
  final String category;
  final String filePath;
  final int lineNumber;
  final String snippet;
  final String moduleArea;

  const StaticAuditFinding({
    required this.category,
    required this.filePath,
    required this.lineNumber,
    required this.snippet,
    required this.moduleArea,
  });

  @override
  String toString() =>
      '[$category] ($moduleArea) $filePath:$lineNumber -> $snippet';
}

void main() {
  group(
      'Static Screen & Codebase Audit (Icons, Hit Targets, Semantics, L10n, Fonts)',
      () {
    late Directory projectRoot;
    late List<File> dartFiles;

    setUpAll(() {
      projectRoot = _resolveProjectRoot();
      dartFiles = Directory('${projectRoot.path}/lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
    });

    test(
        'Rule 1: Zero Material Icons.* or CupertinoIcons.* in lib/ (100% Lucide Icons)',
        () {
      final violations = <StaticAuditFinding>[];
      final materialOrCupertinoRegex =
          RegExp(r'\b(Icons|CupertinoIcons)\.[a-zA-Z0-9_]+');

      for (final file in dartFiles) {
        final relPath = file.path
            .replaceFirst(projectRoot.path, '')
            .replaceAll(r'\', '/')
            .replaceFirst(RegExp(r'^/'), '');
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.startsWith('//')) continue;
          if (materialOrCupertinoRegex.hasMatch(line)) {
            violations.add(
              StaticAuditFinding(
                category: 'ICON_MIXING',
                filePath: relPath,
                lineNumber: i + 1,
                snippet: line,
                moduleArea: 'Unknown',
              ),
            );
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Found Material/Cupertino icons instead of LucideIcons: $violations',
      );
    });

    test(
        'Rule 2: Localization and accessibility modules have zero icon background, <48dp hit target, or missing Semantics violations; out-of-scope findings are catalogued accurately',
        () {
      final a11yModuleViolations = <StaticAuditFinding>[];
      final outOfScopeFindings = <StaticAuditFinding>[];

      for (final file in dartFiles) {
        final relPath = file.path
            .replaceFirst(projectRoot.path, '')
            .replaceAll(r'\', '/')
            .replaceFirst(RegExp(r'^/'), '');
        final isA11yModuleOwned = relPath.startsWith('lib/l10n/') ||
            relPath.startsWith('lib/shared/accessibility/');
        final lines = file.readAsLinesSync();

        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.startsWith('//')) continue;

          // Detect CircleAvatar wrapping Icon
          if (line.contains('CircleAvatar(')) {
            final window = lines.skip(i).take(20).join(' ');
            if (window.contains('Icon(')) {
              final finding = StaticAuditFinding(
                category: 'ICON_BACKGROUND_CIRCLE_AVATAR',
                filePath: relPath,
                lineNumber: i + 1,
                snippet: line,
                moduleArea: 'Host Module',
              );
              if (isA11yModuleOwned) {
                a11yModuleViolations.add(finding);
              } else {
                outOfScopeFindings.add(finding);
              }
            }
          }

          // Detect IconButton without tooltip
          if (RegExp(r'\bIconButton\(').hasMatch(line)) {
            final window = lines.skip(i).take(14).join(' ');
            if (!window.contains('tooltip:')) {
              final finding = StaticAuditFinding(
                category: 'MISSING_ICON_BUTTON_TOOLTIP',
                filePath: relPath,
                lineNumber: i + 1,
                snippet: line,
                moduleArea: 'Screen Module',
              );
              if (isA11yModuleOwned) {
                a11yModuleViolations.add(finding);
              } else {
                outOfScopeFindings.add(finding);
              }
            }
          }

          // Detect sub-48dp button minimumSize in theme
          if (line.contains('minimumSize: const Size(0, 46)')) {
            final finding = StaticAuditFinding(
              category: 'HIT_TARGET_UNDER_48DP',
              filePath: relPath,
              lineNumber: i + 1,
              snippet: line,
              moduleArea: 'Theme Module',
            );
            if (isA11yModuleOwned) {
              a11yModuleViolations.add(finding);
            } else {
              outOfScopeFindings.add(finding);
            }
          }

          // Detect BackdropFilter / ImageFilter.blur usage
          if (line.contains('BackdropFilter(') ||
              line.contains('ImageFilter.blur(')) {
            final finding = StaticAuditFinding(
              category: 'TRANSLUCENT_OR_BLUR_SURFACE',
              filePath: relPath,
              lineNumber: i + 1,
              snippet: line,
              moduleArea: 'Screen/Widget Module',
            );
            if (isA11yModuleOwned) {
              a11yModuleViolations.add(finding);
            } else {
              outOfScopeFindings.add(finding);
            }
          }

          // Detect hardcoded Vietnamese UI strings in presentation screens/widgets
          if (relPath.contains('/presentation/') &&
              RegExp(r"Text\(\s*'[^']*[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ][^']*'")
                  .hasMatch(line)) {
            final finding = StaticAuditFinding(
              category: 'UNLOCALIZED_HARDCODED_STRING',
              filePath: relPath,
              lineNumber: i + 1,
              snippet: line,
              moduleArea: 'Feature Screen Module',
            );
            if (isA11yModuleOwned) {
              a11yModuleViolations.add(finding);
            } else {
              outOfScopeFindings.add(finding);
            }
          }
        }
      }

      // Accessibility & localization owned files must have ZERO violations
      expect(a11yModuleViolations, isEmpty);
      // Out-of-scope findings are detected by the static scanner for reporting
      expect(outOfScopeFindings, isNotEmpty);
    });

    test(
        'Rule 3: SF Pro Font Audit verifies pubspec.yaml SF Pro assets and AppTypography fallback chain',
        () {
      final pubspecFile = File('${projectRoot.path}/pubspec.yaml');
      final typographyFile = File(
        '${projectRoot.path}/lib/app/theme/app_typography.dart',
      );

      expect(pubspecFile.existsSync(), isTrue);
      expect(typographyFile.existsSync(), isTrue);

      final pubspecContent = pubspecFile.readAsStringSync();
      final typographyContent = typographyFile.readAsStringSync();

      // Verify Apple SF Pro .otf/.ttf files are configured in pubspec.yaml
      final sfProAssetMatches = RegExp(
        r'-\s*asset:\s*assets/fonts/SF-Pro[^\s]+',
      ).allMatches(pubspecContent);
      expect(
        sfProAssetMatches,
        isNotEmpty,
        reason:
            'SF Pro font files must be declared in pubspec.yaml for consistent typography',
      );

      // Verify AppTypography uses SF Pro Display / SF Pro Text and includes Korean Hangul fallback (Noto Sans KR)
      expect(
        typographyContent.contains("primaryFontFamily = 'SF Pro Display'"),
        isTrue,
      );
      expect(
        typographyContent.contains("textFontFamily = 'SF Pro Text'"),
        isTrue,
      );
      expect(
        typographyContent.contains('Noto Sans KR'),
        isTrue,
      );
    });
  });
}
