import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/core/date/booking_date.dart';
import 'package:hotel_booking_flutter/features/booking_inquiry/domain/services/contact_service.dart';

void main() {
  tearDown(() {
    ContactService.resetTestOverrides();
  });

  group('ContactService Tests', () {
    test(
      'buildZaloInquiryMessage constructs correct text including villa code, dates, and strips XSS tags',
      () {
        final checkIn = BookingDate.parse('2026-10-15');
        final checkOut = BookingDate.parse('2026-10-17');

        final message = ContactService.buildZaloInquiryMessage(
          villaName: 'Minh Thanh Luxury Sea Villa 01 <script>alert(1)</script>',
          villaCode: 'MTV-01',
          checkIn: checkIn,
          checkOut: checkOut,
          guestCount: 16,
          additionalNotes: 'Cần phòng xông hơi <b>sạch</b>',
        );

        expect(message.contains('Minh Thanh Luxury Sea Villa 01'), isTrue);
        expect(message.contains('<script>'), isFalse);
        expect(message.contains('<b>'), isFalse);
        expect(message.contains('MTV-01'), isTrue);
        expect(message.contains('15/10/2026'), isTrue);
        expect(message.contains('17/10/2026'), isTrue);
        expect(message.contains('2 đêm'), isTrue);
        expect(message.contains('16 người'), isTrue);
        expect(message.contains('Cần phòng xông hơi sạch'), isTrue);
      },
    );

    test(
      'Hotline validation distinguishes valid real numbers, invalid strings, and config sample placeholders',
      () {
        // Sample numbers from config/*.json must be flagged as placeholders
        expect(ContactService.isValidPhoneFormat('0901234567'), isTrue);
        expect(ContactService.isPlaceholderPhone('0901234567'), isTrue);
        expect(ContactService.isVerifiedHotline('0901234567'), isFalse);
        expect(ContactService.isPlaceholderPhone('+84901234567'), isTrue);
        expect(ContactService.isPlaceholderPhone('0123456789'), isTrue);
        expect(ContactService.isPlaceholderPhone('0999999999'), isTrue);

        // Verified real numbers
        expect(ContactService.isValidPhoneFormat('0254.385.6789'), isTrue);
        expect(ContactService.isPlaceholderPhone('0254.385.6789'), isFalse);
        expect(ContactService.isVerifiedHotline('0254.385.6789'), isTrue);
        expect(ContactService.isVerifiedHotline('0938889921'), isTrue);
        expect(ContactService.isVerifiedHotline('1900636999'), isTrue);

        // Malformed / malicious inputs
        expect(ContactService.isValidPhoneFormat(''), isFalse);
        expect(ContactService.isValidPhoneFormat('abc12345'), isFalse);
        expect(
          ContactService.isValidPhoneFormat('javascript:alert(1)'),
          isFalse,
        );
        expect(ContactService.isValidPhoneFormat('tel:0938889921'), isFalse);
      },
    );

    test(
      'Zalo URL validation enforces official HTTPS hosts, strips query params, and flags placeholder OA',
      () {
        // Sample config URL uses placeholder phone 0901234567
        expect(
          ContactService.isValidZaloUrl('https://zalo.me/0901234567'),
          isTrue,
        );
        expect(
          ContactService.isPlaceholderZaloUrl('https://zalo.me/0901234567'),
          isTrue,
        );
        expect(
          ContactService.isVerifiedZaloUrl('https://zalo.me/0901234567'),
          isFalse,
        );

        // Verified OA URL with query parameters stripped (no fake auto-fill)
        final parsed = ContactService.parseAndValidateZaloUri(
          'https://zalo.me/minhthanhvillavungtau?text=Hello&message=FakeAutoFill#frag',
        );
        expect(parsed, isNotNull);
        expect(parsed.toString(), 'https://zalo.me/minhthanhvillavungtau');
        expect(parsed!.hasQuery, isFalse);
        expect(
          ContactService.isVerifiedZaloUrl(
            'https://oa.zalo.me/minhthanhvillavungtau',
          ),
          isTrue,
        );

        // Rejects non-HTTPS, non-Zalo hosts, and malformed URLs
        expect(
          ContactService.parseAndValidateZaloUri(
            'http://zalo.me/minhthanhvilla',
          ),
          isNull,
        );
        expect(
          ContactService.parseAndValidateZaloUri(
            'https://evil.com/zalo.me/minhthanhvilla',
          ),
          isNull,
        );
        expect(
          ContactService.parseAndValidateZaloUri('javascript:alert(1)'),
          isNull,
        );
        expect(
          ContactService.parseAndValidateZaloUri('https://zalo.me/..'),
          isNull,
        );
        expect(
          ContactService.parseAndValidateZaloUri('ht!tp://bad url'),
          isNull,
        );
      },
    );

    test(
      'callHotlineDetailed launches tel: when available and falls back to copying phone when launcher fails',
      () async {
        Uri? launchedUri;
        String? copiedText;

        ContactService.canLaunchUrlOverride = (uri) async => true;
        ContactService.launchUrlOverride = (uri, mode) async {
          launchedUri = uri;
          return true;
        };
        ContactService.clipboardSetDataOverride = (text) async {
          copiedText = text;
        };

        final okResult = await ContactService.callHotlineDetailed(
          customNumber: '0254 385 6789',
        );
        expect(okResult.status, ContactActionStatus.launched);
        expect(okResult.launched, isTrue);
        expect(okResult.copiedToClipboard, isFalse);
        expect(launchedUri.toString(), 'tel:02543856789');
        expect(copiedText, isNull);

        // Simulate dialer failure (e.g. simulator / tablet without telephony)
        ContactService.canLaunchUrlOverride = (uri) async => false;
        final fallbackResult = await ContactService.callHotlineDetailed(
          customNumber: '0254 385 6789',
        );
        expect(fallbackResult.status, ContactActionStatus.copiedFallback);
        expect(fallbackResult.launched, isFalse);
        expect(fallbackResult.copiedToClipboard, isTrue);
        expect(copiedText, '02543856789');
      },
    );

    test(
      'callHotlineDetailed refuses unverified placeholder number and malformed phone',
      () async {
        var launchAttempted = false;
        String? copiedText;

        ContactService.canLaunchUrlOverride = (uri) async {
          launchAttempted = true;
          return true;
        };
        ContactService.clipboardSetDataOverride = (text) async {
          copiedText = text;
        };

        final placeholderRes = await ContactService.callHotlineDetailed(
          customNumber: '0901234567',
          rejectPlaceholder: true,
        );
        expect(placeholderRes.status, ContactActionStatus.unverifiedConfig);
        expect(placeholderRes.launched, isFalse);
        expect(launchAttempted, isFalse);
        expect(copiedText, isNull);

        final invalidRes = await ContactService.callHotlineDetailed(
          customNumber: 'not-a-phone',
        );
        expect(invalidRes.status, ContactActionStatus.invalidInput);
        expect(invalidRes.launched, isFalse);
        expect(launchAttempted, isFalse);
      },
    );

    test(
      'openZaloInquiryDetailed respects user consent for clipboard copy and rejects malformed/unverified URLs',
      () async {
        Uri? launchedUri;
        String? copiedText;

        ContactService.canLaunchUrlOverride = (uri) async => true;
        ContactService.launchUrlOverride = (uri, mode) async {
          launchedUri = uri;
          return true;
        };
        ContactService.clipboardSetDataOverride = (text) async {
          copiedText = text;
        };

        // 1. Without consent to copy draft -> launches verified Zalo OA without overwriting clipboard
        final noCopyRes = await ContactService.openZaloInquiryDetailed(
          customZaloUrl: 'https://zalo.me/minhthanhvillavungtau?text=ignored',
          messageText: 'Draft text',
          userConsentedToCopyDraft: false,
          rejectPlaceholder: true,
        );
        expect(noCopyRes.status, ContactActionStatus.launched);
        expect(noCopyRes.launched, isTrue);
        expect(noCopyRes.copiedToClipboard, isFalse);
        expect(copiedText, isNull);
        expect(launchedUri.toString(), 'https://zalo.me/minhthanhvillavungtau');

        // 2. With consent -> copies draft and launches verified Zalo OA
        final withConsentRes = await ContactService.openZaloInquiryDetailed(
          customZaloUrl: 'https://zalo.me/minhthanhvillavungtau',
          messageText: 'Nội dung tư vấn khách đồng ý',
          userConsentedToCopyDraft: true,
          rejectPlaceholder: true,
        );
        expect(withConsentRes.status, ContactActionStatus.launched);
        expect(withConsentRes.copiedToClipboard, isTrue);
        expect(copiedText, 'Nội dung tư vấn khách đồng ý');

        // 3. Malformed URL -> never launches
        launchedUri = null;
        final badUrlRes = await ContactService.openZaloInquiryDetailed(
          customZaloUrl: 'javascript:alert(1)',
          messageText: 'Nội dung dự phòng',
          userConsentedToCopyDraft: true,
        );
        expect(badUrlRes.status, ContactActionStatus.invalidInput);
        expect(badUrlRes.launched, isFalse);
        expect(launchedUri, isNull);
      },
    );

    test(
      'Email and external HTTPS URL validation reject malformed inputs',
      () {
        expect(ContactService.isValidEmail('khachhang@gmail.com'), isTrue);
        expect(
          ContactService.isValidEmail('minh.thanh+villa@domain.vn'),
          isTrue,
        );
        expect(ContactService.isValidEmail('invalid-email'), isFalse);
        expect(ContactService.isValidEmail('a..b@domain.com'), isFalse);
        expect(ContactService.isValidEmail('<script>@domain.com'), isFalse);

        expect(
          ContactService.parseSafeExternalHttpsUrl(
            'https://www.google.com/maps/search/?api=1&query=Vung+Tau',
          ),
          isNotNull,
        );
        expect(
          ContactService.parseSafeExternalHttpsUrl('http://insecure.com'),
          isNull,
        );
        expect(
          ContactService.parseSafeExternalHttpsUrl('javascript:alert(1)'),
          isNull,
        );
      },
    );
  });
}
