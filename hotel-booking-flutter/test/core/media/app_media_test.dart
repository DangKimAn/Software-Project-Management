import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/core/media/media.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  group('Native Config, Assets & Font Audit', () {
    test(
      'All 24 bundled raster images, SVG logo, app icon, and flavor configs exist and are non-empty',
      () {
        for (final file in AppMediaHelper.bundledRasterImageFiles) {
          final f = File('assets/images/$file');
          expect(
            f.existsSync(),
            isTrue,
            reason: 'Missing bundled raster asset: assets/images/$file',
          );
          expect(
            f.lengthSync(),
            greaterThan(1024),
            reason: 'Bundled raster asset is unexpectedly empty/tiny: $file',
          );
        }

        final svgLogo = File(AppMediaHelper.brandLogoSvgAsset);
        expect(svgLogo.existsSync(), isTrue);
        expect(svgLogo.lengthSync(), greaterThan(500));

        final appIcon = File(AppMediaHelper.brandAppIconPngAsset);
        expect(appIcon.existsSync(), isTrue);
        expect(appIcon.lengthSync(), greaterThan(500));

        for (final env in ['dev', 'staging', 'prod']) {
          final cfg = File('config/$env.json');
          expect(cfg.existsSync(), isTrue, reason: 'Missing config/$env.json');
          expect(cfg.lengthSync(), greaterThan(20));
        }
      },
    );

    test(
      'Apple SF Pro (.otf/.ttf) font binaries are bundled in assets/fonts and configured in pubspec.yaml',
      () {
        final fontsDir = Directory('assets/fonts');
        expect(fontsDir.existsSync(), isTrue);
        final sfFontFiles = fontsDir
            .listSync()
            .whereType<File>()
            .where((file) => AppMediaHelper.isSfProFontAsset(file.path))
            .toList();
        expect(
          sfFontFiles,
          isNotEmpty,
          reason: 'Bundled SF Pro font files must exist in assets/fonts',
        );

        final pubspecContent = File('pubspec.yaml').readAsStringSync();
        expect(pubspecContent.contains('SF-Pro-Display-'), isTrue);
        expect(pubspecContent.contains('SF-Pro-Text-'), isTrue);
        expect(pubspecContent.contains('SF-Pro-Rounded-'), isTrue);
        expect(pubspecContent.contains('assets/fonts/SF-Pro'), isTrue);
      },
    );

    test(
      'Android build.gradle.kts & AndroidManifest.xml enforce flavors, permissions, deep links, and HTTPS safety',
      () {
        final gradleContent =
            File('android/app/build.gradle.kts').readAsStringSync();
        expect(
          gradleContent,
          contains('applicationId = "com.bronc3.hotel_booking_flutter"'),
        );
        expect(gradleContent, contains('create("dev")'));
        expect(gradleContent, contains('applicationIdSuffix = ".dev"'));
        expect(gradleContent, contains('create("staging")'));
        expect(gradleContent, contains('applicationIdSuffix = ".staging"'));
        expect(gradleContent, contains('create("prod")'));
        expect(
          gradleContent,
          contains('Refusing to sign release build with debug key'),
        );

        final manifestContent = File(
          'android/app/src/main/AndroidManifest.xml',
        ).readAsStringSync();
        expect(
          manifestContent,
          contains('android.permission.INTERNET'),
        );
        expect(
          manifestContent,
          contains('android.permission.ACCESS_NETWORK_STATE'),
        );
        expect(
          manifestContent,
          contains('android:scheme="minhthanhvilla"'),
        );
        expect(
          manifestContent,
          contains('android:scheme="mailto"'),
        );
        expect(
          manifestContent,
          contains('android:scheme="tel"'),
        );
        // Must NEVER enable global cleartext traffic
        expect(
          manifestContent.contains('usesCleartextTraffic="true"'),
          isFalse,
        );
      },
    );

    test(
      'iOS Info.plist, Podfile & xcconfig files define dev/staging/prod flavors, deep links, and camera/photo purpose strings without opening global ATS',
      () {
        final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
        expect(infoPlist, contains('<string>minhthanhvilla</string>'));
        expect(infoPlist, contains('<string>zalo</string>'));
        expect(infoPlist, contains('<string>tel</string>'));
        expect(infoPlist, contains('<string>mailto</string>'));
        expect(infoPlist, contains('<key>NSCameraUsageDescription</key>'));
        expect(
          infoPlist,
          contains('<key>NSPhotoLibraryUsageDescription</key>'),
        );
        // Must NEVER open global ATS cleartext
        expect(
            infoPlist.contains('<key>NSAllowsArbitraryLoads</key>'), isFalse);

        final podfile = File('ios/Podfile').readAsStringSync();
        expect(podfile, contains("'Debug-dev'"));
        expect(podfile, contains("'Release-staging'"));
        expect(podfile, contains("'Release-prod'"));

        final devXcconfig = File('ios/Flutter/dev.xcconfig').readAsStringSync();
        final stagingXcconfig =
            File('ios/Flutter/staging.xcconfig').readAsStringSync();
        final prodXcconfig =
            File('ios/Flutter/prod.xcconfig').readAsStringSync();

        expect(
          devXcconfig,
          contains('com.bronc3.hotel_booking_flutter.dev'),
        );
        expect(
          stagingXcconfig,
          contains('com.bronc3.hotel_booking_flutter.staging'),
        );
        expect(
          prodXcconfig,
          contains('com.bronc3.hotel_booking_flutter'),
        );
      },
    );
  });

  group('Asset & Malformed URL Resolution', () {
    test(
        'Resolves bundled assets including case-sensitive nabi.JPG and legacy paths',
        () {
      expect(
        AppMediaHelper.resolveBundledAssetPath('assets/images/nabi.jpg'),
        equals('assets/images/nabi.JPG'),
      );
      expect(
        AppMediaHelper.resolveBundledAssetPath('/src/assets/img/casamar.jpg'),
        equals('assets/images/casamar.jpg'),
      );
      expect(
        AppMediaHelper.resolveBundledAssetPath('villa_bien.jpg'),
        equals(AppMediaHelper.defaultHeroFallbackAsset),
      );
      expect(
        AppMediaHelper.resolveBundledAssetPath('/src/assets/img/anh_1.jpg'),
        equals('assets/images/19tranphu.jpg'),
      );
      expect(
        AppMediaHelper.resolveBundledAssetPath(
            'assets/images/unknown_file.jpg'),
        equals(AppMediaHelper.secondaryVillaFallbackAsset),
      );
      expect(
        AppMediaHelper.resolveBundledAssetPath('assets/images/logo_mau.svg'),
        equals(AppMediaHelper.brandLogoSvgAsset),
      );
    });

    test('Rejects empty, literal placeholder tokens, and dangerous URI schemes',
        () {
      for (final token in [
        '',
        '   ',
        'null',
        'undefined',
        'NaN',
        '[object Object]'
      ]) {
        final res = AppMediaHelper.inspectMediaSource(token);
        expect(res.isRejected, isTrue, reason: 'Should reject "$token"');
        expect(
          res.rejectReason,
          equals(AppMediaUrlRejectReason.emptyOrPlaceholderToken),
        );
      }

      for (final badScheme in [
        'javascript:alert(1)',
        'data:image/png;base64,iVBORw0KGgo=',
        'file:///etc/passwd',
        'ftp://files.example.com/photo.jpg',
        'mailto:test@example.com',
        'tel:0901234567',
      ]) {
        final res = AppMediaHelper.inspectMediaSource(badScheme);
        expect(res.isRejected, isTrue, reason: 'Should reject "$badScheme"');
        expect(
          res.rejectReason,
          equals(AppMediaUrlRejectReason.unsupportedOrDangerousScheme),
        );
      }
    });

    test(
        'Rejects protocol-relative URLs, empty hosts, and private Google Drive hotlinks',
        () {
      final protoRel =
          AppMediaHelper.inspectMediaSource('//evil.com/hijack.jpg');
      expect(protoRel.isRejected, isTrue);
      expect(
        protoRel.rejectReason,
        equals(AppMediaUrlRejectReason.protocolRelativeUrl),
      );

      for (final malformed in [
        'https://',
        'http://',
        'https:///path/only.jpg',
        'https:photo.jpg',
        'https://..bad..host/img.jpg',
        'https://example.com:99999/img.jpg',
        'https://example.com/img\n.jpg',
      ]) {
        final res = AppMediaHelper.inspectMediaSource(malformed);
        expect(res.isRejected, isTrue, reason: 'Should reject "$malformed"');
        expect(
          res.rejectReason,
          equals(AppMediaUrlRejectReason.malformedUriOrEmptyHost),
        );
      }

      for (final gdrive in [
        'https://drive.google.com/file/d/1AbCdEfGhIjKlMnOp/view?usp=sharing',
        'https://docs.google.com/uc?export=download&id=1AbCdEfGhIjKlMnOp',
      ]) {
        final res = AppMediaHelper.inspectMediaSource(gdrive);
        expect(res.isRejected, isTrue, reason: 'Should reject "$gdrive"');
        expect(
          res.rejectReason,
          equals(AppMediaUrlRejectReason.unstablePrivateHotlink),
        );
      }
    });

    test(
        'Enforces HTTPS on non-local hosts in production while encoding UTF-8 and spaces',
        () {
      final cleartextProd = AppMediaHelper.inspectMediaSource(
        'http://cdn.minhthanhvilla.com/villas/01.jpg',
        enforceHttps: true,
      );
      expect(cleartextProd.isRejected, isTrue);
      expect(
        cleartextProd.rejectReason,
        equals(AppMediaUrlRejectReason.cleartextHttpDisallowed),
      );

      final localDev = AppMediaHelper.inspectMediaSource(
        '/uploads/villas/biệt thự biển 01.jpg',
        apiBaseUrl: 'http://localhost:7000',
        enforceHttps: false,
      );
      expect(localDev.isNetworkUrl, isTrue);
      expect(
        localDev.networkUrl,
        equals(
          'http://localhost:7000/uploads/villas/bi%E1%BB%87t%20th%E1%BB%B1%20bi%E1%BB%83n%2001.jpg',
        ),
      );
    });
  });

  group('DPR Decode Sizing, Cache Bounds & Typography', () {
    test(
        'Computes bounded physical decode dimensions and reduces RGBA memory by >75%',
        () {
      final fullResBytes = AppMediaHelper.estimateDecodedBytes(
        widthPx: 2048,
        heightPx: 1365,
      );
      expect(fullResBytes, equals(11182080)); // ~11.18 MB

      final cardDecode = AppMediaHelper.computeDecodeSizeForAspectRatio(
        logicalWidth: 360,
        aspectRatio: AppMediaHelper.mobileCardAspectRatio,
        devicePixelRatio: 2.0,
      );
      expect(cardDecode.cacheWidth, equals(720));
      expect(cardDecode.cacheHeight, equals(540));

      final resizedBytes = AppMediaHelper.estimateDecodedBytes(
        widthPx: cardDecode.cacheWidth,
        heightPx: cardDecode.cacheHeight,
      );
      expect(resizedBytes, equals(1555200)); // ~1.55 MB (>85% reduction)
      expect(resizedBytes, lessThan(fullResBytes ~/ 4));

      // Clamps extreme DPR or tablet widths to maxCardDecodeDimensionPx (1080)
      final clamped = AppMediaHelper.computeDecodeDimension(
        900,
        devicePixelRatio: 3.0,
        maxPhysicalPx: AppMediaHelper.maxCardDecodeDimensionPx,
      );
      expect(clamped, equals(AppMediaHelper.maxCardDecodeDimensionPx));
    });

    test('Configures bounded ImageCache capacity safely', () {
      final customCache = ImageCache();
      AppMediaHelper.configureImageCacheBounds(
        imageCache: customCache,
        maximumSize: 100,
        maximumSizeBytes: 48 * 1024 * 1024,
      );
      expect(customCache.maximumSize, equals(100));
      expect(customCache.maximumSizeBytes, equals(48 * 1024 * 1024));
    });

    test(
        'Provides SF Pro primary and localized font fallback chains for VI, EN, KO across iOS and Android',
        () {
      final androidVi = AppMediaHelper.licensedFontFallbacksForLanguage(
        'vi',
        platform: TargetPlatform.android,
      );
      expect(
        androidVi,
        containsAll([
          'SF Pro Display',
          'SF Pro Text',
          'Be Vietnam Pro',
          'Roboto',
          'Noto Sans KR',
        ]),
      );

      final androidKo = AppMediaHelper.licensedFontFallbacksForLanguage(
        'ko',
        platform: TargetPlatform.android,
      );
      expect(androidKo.first, equals('SF Pro Display'));
      expect(androidKo, contains('Noto Sans KR'));

      final iosKo = AppMediaHelper.licensedFontFallbacksForLanguage(
        'ko',
        platform: TargetPlatform.iOS,
      );
      expect(iosKo.first, equals('SF Pro Display'));
      expect(iosKo, contains('Apple SD Gothic Neo'));
    });
  });

  group('AppMediaImage Responsive & Text-Scale Widget Verification', () {
    // Valid 1x1 transparent PNG for deterministic memory image testing
    final Uint8List valid1x1Png = Uint8List.fromList(<int>[
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1F,
      0x15,
      0xC4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0A,
      0x49,
      0x44,
      0x41,
      0x54,
      0x78,
      0x9C,
      0x63,
      0x00,
      0x01,
      0x00,
      0x00,
      0x05,
      0x00,
      0x01,
      0x0D,
      0x0A,
      0x2D,
      0xB4,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4E,
      0x44,
      0xAE,
      0x42,
      0x60,
      0x82,
    ]);

    testWidgets(
      'AppMediaImage locks 4:3 aspect ratio, handles malformed URLs gracefully, and exposes >=48x48dp retry target',
      (tester) async {
        int retryCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  child: AppMediaImage(
                    imageUrl: 'javascript:alert(1)',
                    aspectRatio: AppMediaHelper.mobileCardAspectRatio,
                    borderRadius: BorderRadius.circular(24),
                    onRetry: () => retryCount++,
                  ),
                ),
              ),
            ),
          ),
        );

        final errorBox = find.byKey(
          const ValueKey<String>('app_media_error_placeholder'),
        );
        expect(errorBox, findsOneWidget);

        // Verify AspectRatio(4/3) keeps exact 320x240 logical geometry
        final size = tester.getSize(find.byType(AppMediaImage));
        expect(size.width, closeTo(320.0, 0.1));
        expect(size.height, closeTo(240.0, 0.1));

        // Verify bare Lucide icon (no CircleAvatar) and >=48x48dp retry target
        expect(find.byIcon(LucideIcons.refreshCw), findsOneWidget);
        expect(find.byType(CircleAvatar), findsNothing);

        await tester.tap(find.text('Thử lại'));
        await tester.pump();
        expect(retryCount, equals(1));
      },
    );

    for (final widthDp in <double>[320, 360, 390, 430]) {
      for (final scale in <double>[1.0, 1.3, 1.6]) {
        testWidgets(
          'Renders VI/EN/KO villa card with AppMediaImage at ${widthDp.toInt()}dp and textScale=$scale without overflow',
          (tester) async {
            tester.view.physicalSize = Size(widthDp * 2, 900 * 2);
            tester.view.devicePixelRatio = 2.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await tester.pumpWidget(
              MaterialApp(
                builder: (context, child) {
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      disableAnimations: true,
                    ),
                    child: child!,
                  );
                },
                home: Scaffold(
                  backgroundColor: const Color(0xFFFFFFFF),
                  body: SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppMediaImage(
                            memoryBytes: valid1x1Png,
                            aspectRatio: AppMediaHelper.mobileCardAspectRatio,
                            borderRadius: BorderRadius.circular(24),
                            semanticLabel: 'Biệt thự nghỉ dưỡng Vũng Tàu',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Biệt thự nghỉ dưỡng Vũng Tàu (ệ ư ỗ ợ đ)',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF222222),
                              fontFamilyFallback: AppMediaHelper
                                  .licensedFontFallbacksForLanguage(
                                'vi',
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Luxury Oceanfront Villa • 붕따우 럭셔리 풀빌라',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF717171),
                              fontFamilyFallback: AppMediaHelper
                                  .licensedFontFallbacksForLanguage(
                                'ko',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Từ 3.500.000 ₫ / đêm',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF222222),
                              fontFamilyFallback: AppMediaHelper
                                  .licensedFontFallbacksForLanguage(
                                'vi',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );

            await tester.pump();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}
