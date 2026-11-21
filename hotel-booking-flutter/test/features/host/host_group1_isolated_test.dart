import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hotel_booking_flutter/app/router/app_router.dart';
import 'package:hotel_booking_flutter/app/theme/app_colors.dart';
import 'package:hotel_booking_flutter/core/network/dio_client.dart';
import 'package:hotel_booking_flutter/features/host/data/host_repository.dart';
import 'package:hotel_booking_flutter/features/host/domain/host_models.dart';
import 'package:hotel_booking_flutter/features/host/presentation/screens/host_portal_screens.dart';
import 'package:hotel_booking_flutter/features/host/presentation/widgets/host_chat_composer_bar.dart';
import 'package:hotel_booking_flutter/features/host/presentation/widgets/host_studio_widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Uint8List _kSamplePngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

Uint8List _makePdfBytes() {
  final bytes = Uint8List(256);
  final header = ascii.encode('%PDF-1.7\n');
  for (var i = 0; i < header.length; i++) {
    bytes[i] = header[i];
  }
  return bytes;
}

void main() {
  group('Group 1 Isolated Domain, KYC & 1.3x–2.0x Font-Scaling Suite', () {
    test(
      'Item 1 & 2: HostListingStatus.rejected, internalStatus fallback, HostListingSummary, validate(isCreate) & toUpdateJson(includeStatus)',
      () {
        expect(
          HostListingStatus.fromApi('rejected'),
          HostListingStatus.rejected,
        );
        expect(HostListingStatus.rejected.labelVi, 'Bị từ chối');
        expect(
          HostListingStatus.fromListingMap({
            'status': 'draft',
            'internalStatus': 'rejected',
          }),
          HostListingStatus.rejected,
        );
        expect(
          HostListingStatus.rejected
              .canTransitionTo(HostListingStatus.pendingApproval),
          isTrue,
        );
        expect(
          HostListingStatus.rejected.canTransitionTo(HostListingStatus.draft),
          isTrue,
        );
        expect(
          HostListingStatus.rejected
              .canTransitionTo(HostListingStatus.published),
          isFalse,
        );

        final summary = HostListingSummary.fromJson({
          'listingId': 501,
          'title': 'Villa Hồ Bơi Bãi Sau',
          'status': 'draft',
          'internalStatus': 'rejected',
          'rejectionReason': 'Ảnh phòng tắm chưa rõ nét.',
          'propertyType': 'villa',
          'basePrice': 3500000,
          'weekendPrice': 4200000,
          'maxGuests': 10,
        });
        expect(summary.id, '501');
        expect(summary.status, HostListingStatus.rejected);
        expect(summary.rejectionReason, 'Ảnh phòng tắm chưa rõ nét.');

        for (final editStatus in [
          HostListingStatus.published,
          HostListingStatus.hidden,
          HostListingStatus.rejected,
        ]) {
          final dto = HostListingUpsertDto(
            title: 'Villa Biển Thùy Vân',
            description: 'Mô tả đầy đủ tiện nghi nghỉ dưỡng sát biển.',
            addressLine: '18 Thùy Vân',
            ward: 'Phường Thắng Tam',
            city: 'Vũng Tàu',
            latitude: 10.34,
            longitude: 107.09,
            propertyType: HostPropertyType.villa,
            roomType: HostRoomType.entirePlace,
            maxGuests: 10,
            bedrooms: 4,
            beds: 5,
            bathrooms: 4,
            basePrice: 3800000,
            weekendPrice: 4500000,
            status: editStatus,
          );
          expect(dto.validate(isCreate: true), isNotNull);
          expect(dto.validate(isCreate: false), isNull);

          final withoutStatus = dto.toUpdateJson(includeStatus: false);
          expect(withoutStatus.containsKey('status'), isFalse);

          final withStatus = dto.toUpdateJson(
            includeStatus: true,
            nextStatus: HostListingStatus.pendingApproval,
          );
          expect(withStatus['status'], 'pending_approval');
        }
      },
    );

    test(
      'Item 4: computeHostPayoutSummary sums ONLY pending/approved/processing into totalPending and exposes Vietnamese labels',
      () {
        final summary = computeHostPayoutSummary([
          {'payoutId': 1, 'amount': 1000000, 'status': 'pending'},
          {'payoutId': 2, 'amount': 2000000, 'status': 'approved'},
          {'payoutId': 3, 'amount': 3000000, 'status': 'processing'},
          {'payoutId': 4, 'amount': 10000000, 'status': 'paid'},
          {'payoutId': 5, 'amount': 5000000, 'status': 'rejected'},
          {'payoutId': 6, 'amount': 4000000, 'status': 'failed'},
          {'payoutId': 7, 'amount': 6000000, 'status': 'cancelled'},
        ]);
        expect(summary.totalPaid, 10000000);
        expect(summary.totalPending, 6000000);
        expect(kHostPayoutStatusLabels['processing'], 'Đang chuyển');
        expect(kHostPayoutStatusLabels['failed'], 'Thất bại');
        expect(kHostPayoutStatusLabels['cancelled'], 'Đã hủy');
        expect(
          kHostPayoutFilterTabs.map((e) => e.$1).toList(),
          containsAll([
            'all',
            'pending',
            'approved',
            'processing',
            'paid',
            'rejected',
            'failed',
            'cancelled',
          ]),
        );
      },
    );

    test(
      'Item 5 & 6: Non-blocking bookingStatus leaves HostCalendarDay editable and HostRevenueReport parses pendingStay metrics',
      () {
        for (final nonBlocking in [
          'cancelled_by_guest',
          'cancelled_by_host',
          'cancelled_by_admin',
          'rejected',
          'payment_expired',
          'pending_payment',
        ]) {
          expect(isCalendarBlockingStatusCode(nonBlocking), isFalse);
          final day = HostCalendarDay.fromJson({
            'date': '2026-12-15',
            'basePrice': 3000000,
            'effectivePrice': 3000000,
            'isAvailable': true,
            'isBooked': false,
            'bookingStatus': nonBlocking,
            'canEdit': true,
          });
          expect(day.isBooked, isFalse);
          expect(day.isEditable(), isTrue);
          expect(
            isHostCalendarDayLockedByBooking(
              isBookedFlag: day.isBooked,
              bookingStatus: day.bookingStatus,
            ),
            isFalse,
          );
        }

        for (final blocking in ['confirmed', 'checked_in', 'completed']) {
          expect(isCalendarBlockingStatusCode(blocking), isTrue);
          final day = HostCalendarDay.fromJson({
            'date': '2026-12-16',
            'basePrice': 3000000,
            'effectivePrice': 3000000,
            'isAvailable': false,
            'isBooked': false,
            'bookingStatus': blocking,
            'canEdit': false,
          });
          expect(day.isBooked, isTrue);
        }

        final report = HostRevenueReport.fromJson({
          'totals': {
            'grossRevenue': 20000000,
            'platformRevenue': 2000000,
            'hostRevenue': 18000000,
            'pendingStayRevenue': 9000000,
            'pendingStayHostRevenue': 8100000,
            'pendingStayBookingCount': 2,
          },
          'series': <dynamic>[],
        });
        expect(report.pendingStayHostRevenue, 8100000);
        expect(report.pendingStayBookingCount, 2);
      },
    );

    test(
      'Item 7a & 7b: Identity KYC validators reject PDF while allowing JPG/PNG/WebP (and PDF for businessLicense), and numeric conversation ID check blocks admin_support',
      () {
        final pdfFile = HostPickedFile(
          name: 'identity.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 256,
          bytes: _makePdfBytes(),
        );
        final pngFile = HostPickedFile(
          name: 'identity.png',
          mimeType: 'image/png',
          sizeBytes: _kSamplePngBytes.length,
          bytes: _kSamplePngBytes,
        );

        expect(
          validateIdentityKycPickedFile(pdfFile),
          contains('không hỗ trợ tệp PDF'),
        );
        expect(validateIdentityKycPickedFile(pngFile), isNull);
        expect(validateKycPickedFile(pdfFile), isNull);

        final badDto = HostKycSubmissionDto(
          contactName: 'Nguyễn Minh Thành',
          contactEmail: 'minhthanh@vt.vn',
          phone: '0901234567',
          profileType: HostProfileType.business,
          documentType: HostDocumentType.cccd,
          businessAddress: '100 Thùy Vân, Vũng Tàu',
          identityFront: pdfFile,
          identityBack: pngFile,
          businessLicense: pdfFile,
        );
        expect(badDto.validate(), contains('PDF'));

        final goodDto = HostKycSubmissionDto(
          contactName: 'Nguyễn Minh Thành',
          contactEmail: 'minhthanh@vt.vn',
          phone: '0901234567',
          profileType: HostProfileType.business,
          documentType: HostDocumentType.cccd,
          businessAddress: '100 Thùy Vân, Vũng Tàu',
          identityFront: pngFile,
          identityBack: pngFile,
          businessLicense: pdfFile,
        );
        expect(goodDto.validate(), isNull);

        expect(isNumericHostConversationId('admin_support'), isFalse);
        expect(isNumericHostConversationId('conv-101'), isFalse);
        expect(isNumericHostConversationId('777'), isTrue);
      },
    );

    testWidgets(
      'Item 7c: HostVoiceRecordingBar, HostChatComposerBar, Review 58x58 FittedBox, and HostStudioInitialsBadge scale cleanly at 1.3x–2.0x on 320px viewport',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final ctrl = TextEditingController();
        final focus = FocusNode();
        for (final scale in [1.3, 1.6, 2.0]) {
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 640),
                textScaler: TextScaler.linear(scale),
              ),
              child: MaterialApp(
                home: Scaffold(
                  body: Column(
                    children: [
                      HostVoiceRecordingBar(
                        recordingSeconds: 45,
                        onCancel: () {},
                        onSend: () {},
                      ),
                      HostChatComposerBar(
                        controller: ctrl,
                        focusNode: focus,
                        isRecordingVoice: true,
                        sendingMessage: false,
                        quickIcon: LucideIcons.thumbsUp,
                        onShowMoreOptions: () {},
                        onOpenCamera: () {},
                        onPickGalleryImage: () {},
                        onToggleVoiceRecording: () {},
                        onShowEmojiSelector: () {},
                        onSendQuickEmoji: () {},
                        onChooseQuickEmoji: () {},
                        onSendMessage: () {},
                      ),
                      Row(
                        children: [
                          const HostStudioInitialsBadge(
                            name: 'Nguyễn Hoàng Minh',
                            size: 42,
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 58,
                            height: 58,
                            padding: const EdgeInsets.all(6),
                            color: AppColors.textPrimary,
                            child: const Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '4.9',
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Expected zero overflow at scale=$scale',
          );

          final inputWidth =
              tester.getSize(find.byKey(const Key('host_message_input'))).width;
          expect(
            inputWidth,
            greaterThanOrEqualTo(95),
            reason:
                'TextField width ($inputWidth) must remain usable at $scale',
          );
        }
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    test(
      'Item 7b (Dio Contract): POST /api/conversations {support: true} and PATCH /api/conversations/:id/read',
      () async {
        final captured = <RequestOptions>[];
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'));
        dio.httpClientAdapter = _SimpleAdapter((opts) async {
          captured.add(opts);
          return ResponseBody.fromString(
            jsonEncode({'id': '777', 'conversationId': '777'}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });
        await dio.post<dynamic>('/api/conversations', data: {'support': true});
        await dio.patch<dynamic>('/api/conversations/777/read');
        expect(captured[0].path, '/api/conversations');
        expect((captured[0].data as Map)['support'], isTrue);
        expect(captured[1].path, '/api/conversations/777/read');
      },
    );

    test(
      'Item 7d (Dio Contract): POST /api/host/payouts/:payoutId/cancel cancels pending host payout',
      () async {
        final captured = <RequestOptions>[];
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'));
        dio.httpClientAdapter = _SimpleAdapter((opts) async {
          captured.add(opts);
          return ResponseBody.fromString(
            jsonEncode({
              'data': {
                'payoutId': 30001,
                'status': 'cancelled',
                'amount': 10000000,
              }
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        final dioClient = DioClient(dio: dio);
        final repo = HostRepository(dioClient);
        final res = await repo.cancelPayout(30001);

        expect(captured.length, 1);
        expect(captured[0].path, '/api/host/payouts/30001/cancel');
        expect(captured[0].method, 'POST');
        expect(res['payoutId'], 30001);
        expect(res['status'], 'cancelled');
      },
    );

    test(
      'Item 7e: Host Messages conversation filter matches guest name, listing title, or last message case-insensitively',
      () {
        final conversations = [
          {
            'id': 1,
            'otherParticipant': {'fullName': 'Lê Hoàng Long'},
            'listingTitle': 'Seaside Sunset Homestay & Studio Hạ Long',
            'lastMessage': {'content': 'Voice message (00:07)'},
          },
          {
            'id': 2,
            'otherParticipant': {'fullName': 'Quản trị viên The Palm Villa'},
            'listingTitle': 'Seaside Sunset Homestay & Studio Hạ Long',
            'lastMessage': {'content': 'Photo'},
          },
          {
            'id': 3,
            'otherParticipant': {'fullName': 'dangkiman User'},
            'listingTitle': 'Seaside Sunset Homestay & Studio Hạ Long',
            'lastMessage': {'content': 'Hồ bơi của biệt thự là nước ngọt hay nước mặn...'},
          },
        ];

        bool matches(Map<String, dynamic> c, String rawQuery) {
          final query = rawQuery.trim().toLowerCase();
          if (query.isEmpty) return true;
          final other = c['otherParticipant'] is Map
              ? Map<String, dynamic>.from(c['otherParticipant'] as Map)
              : null;
          final name = (other?['fullName'] ?? other?['name'] ?? '').toString().toLowerCase();
          final listingTitle = (c['listingTitle'] ?? '').toString().toLowerCase();
          final lastMsg = (c['lastMessage'] is Map
                  ? c['lastMessage']['content'] ?? c['lastMessage']['body']
                  : c['lastMessage']) ??
              '';
          return name.contains(query) ||
              listingTitle.contains(query) ||
              '$lastMsg'.toLowerCase().contains(query);
        }

        expect(conversations.where((c) => matches(c, 'Hoàng Long')).length, 1);
        expect(conversations.where((c) => matches(c, 'nước mặn')).length, 1);
        expect(conversations.where((c) => matches(c, 'Hạ Long')).length, 3);
        expect(conversations.where((c) => matches(c, 'nonexistent')).length, 0);
      },
    );

    test(
      'Item 7f: ScaffoldWithBottomNavBar.resolveActiveTabIndex accurately maps paths to tab indices',
      () {
        // Tab 0: Discover
        expect(
          ScaffoldWithBottomNavBar.resolveActiveTabIndex(
            path: '/',
            fallbackIndex: 3,
          ),
          0,
        );
        expect(
          ScaffoldWithBottomNavBar.resolveActiveTabIndex(
            path: '',
            fallbackIndex: 3,
          ),
          0,
        );

        // Tab 1: Messages / Tin nhắn
        expect(
          ScaffoldWithBottomNavBar.resolveActiveTabIndex(
            path: '/messages',
            fallbackIndex: 3,
          ),
          1,
        );
        expect(
          ScaffoldWithBottomNavBar.resolveActiveTabIndex(
            path: '/messages?conversationId=123',
            fallbackIndex: 3,
          ),
          1,
        );
        expect(
          ScaffoldWithBottomNavBar.resolveActiveTabIndex(
            path: '/tin-nhan',
            fallbackIndex: 3,
          ),
          1,
        );
        expect(
          ScaffoldWithBottomNavBar.resolveActiveTabIndex(
            path: '/tin-nhan?conversationId=456',
            fallbackIndex: 3,
          ),
          1,
        );

        // Tab 2: Trips
        expect(
          ScaffoldWithBottomNavBar.resolveActiveTabIndex(
            path: '/trips',
            fallbackIndex: 3,
          ),
          2,
        );
        expect(
          ScaffoldWithBottomNavBar.resolveActiveTabIndex(
            path: '/account/trips',
            fallbackIndex: 3,
          ),
          2,
        );
        expect(
          ScaffoldWithBottomNavBar.resolveActiveTabIndex(
            path: '/account/trips?status=completed',
            fallbackIndex: 3,
          ),
          2,
        );

        // Tab 3: Account
        expect(
          ScaffoldWithBottomNavBar.resolveActiveTabIndex(
            path: '/settings',
            fallbackIndex: 1,
          ),
          3,
        );
        expect(
          ScaffoldWithBottomNavBar.resolveActiveTabIndex(
            path: '/account/profile',
            fallbackIndex: 1,
          ),
          3,
        );

        // Fallback for non-tab modal paths
        expect(
          ScaffoldWithBottomNavBar.resolveActiveTabIndex(
            path: '/villa/101',
            fallbackIndex: 2,
          ),
          2,
        );
      },
    );

    testWidgets(
      'Item 7g: Listing Selector trigger opens Modern BottomSheet Modal styled like Guest Status Filter',
      (tester) async {
        final adapter = _SimpleAdapter((options) async {
          if (options.path == '/api/host/listings/mine') {
            return ResponseBody.fromString(
              jsonEncode({
                'items': [
                  {
                    'listingId': 101,
                    'title': 'Seaside Sunset Homestay & Studio Hạ Long',
                    'propertyType': 'homestay',
                    'city': 'Hạ Long',
                    'status': 'published',
                  },
                  {
                    'listingId': 102,
                    'title': 'White Lotus Pool Villa Phan Chu Trinh',
                    'propertyType': 'villa',
                    'city': 'Vũng Tàu',
                    'status': 'published',
                  },
                  {
                    'listingId': 103,
                    'title': 'The Palm Villa Vũng Tàu',
                    'propertyType': 'villa',
                    'city': 'Vũng Tàu',
                    'status': 'published',
                  },
                  {
                    'listingId': 104,
                    'title': 'Ocean View Penthouse Đà Nẵng',
                    'propertyType': 'apartment',
                    'city': 'Đà Nẵng',
                    'status': 'published',
                  },
                  {
                    'listingId': 105,
                    'title': 'Mountain Retreat Sa Pa',
                    'propertyType': 'villa',
                    'city': 'Sa Pa',
                    'status': 'published',
                  },
                ],
              }),
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }
          if (options.path.contains('/reviews')) {
            return ResponseBody.fromString(
              jsonEncode({
                'items': [
                  {
                    'reviewId': 1,
                    'reviewerName': 'Đặng Kim An',
                    'rating': 5,
                    'comment': 'Chỗ nghỉ tuyệt vời!',
                    'createdAt': '2026-11-15',
                  },
                ],
              }),
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }
          return ResponseBody.fromString(
            jsonEncode({'items': <Object?>[]}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        final client = DioClient()..dio.httpClientAdapter = adapter;
        final testRepo = HostRepository(client);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hostRepositoryProvider.overrideWithValue(testRepo),
              hostCurrentUserRoleProvider.overrideWithValue('host'),
            ],
            child: const MaterialApp(
              home: HostPortalScreen(
                initialSection: HostPortalSection.reviews,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify trigger is rendered with the selected listing title
        final triggerFinder = find.byKey(const Key('reviews_listing_dropdown'));
        expect(triggerFinder, findsOneWidget);
        expect(
          find.text('Seaside Sunset Homestay & Studio Hạ Long'),
          findsWidgets,
        );

        // 2. Tap trigger to open the Studio BottomSheet modal
        await tester.tap(triggerFinder);
        await tester.pumpAndSettle();

        // 3. Verify modal bottom sheet is displayed
        expect(find.text('Chọn chỗ nghỉ'), findsOneWidget);
        expect(find.byIcon(LucideIcons.x), findsOneWidget);

        // Verify options are listed and Scrollbar is visible for >3 listings
        expect(find.byType(Scrollbar), findsOneWidget);
        final option1 = find.byKey(const Key('listing_option_101'));
        final option2 = find.byKey(const Key('listing_option_102'));
        final option5 = find.byKey(const Key('listing_option_105'));
        expect(option1, findsOneWidget);
        expect(option2, findsOneWidget);

        // Option 1 is selected and displays checkmark
        expect(find.byIcon(LucideIcons.check), findsOneWidget);

        // 4. Scroll down to Option 5 (exceeding initial 3-4 visible villas) and tap it
        await tester.ensureVisible(option5);
        await tester.pumpAndSettle();
        expect(option5, findsOneWidget);
        await tester.tap(option5);
        await tester.pumpAndSettle();

        // 5. Verify modal closed and trigger updated to Option 5 title
        expect(find.byIcon(LucideIcons.x), findsNothing);
        expect(
          find.text('Mountain Retreat Sa Pa'),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'Item 7h: Bookings Section filter and sort triggers open Modern BottomSheet Modals styled like Guest Status Filter',
      (tester) async {
        final adapter = _SimpleAdapter((options) async {
          if (options.path == '/api/host/bookings') {
            return ResponseBody.fromString(
              jsonEncode({
                'items': [
                  {
                    'bookingId': 501,
                    'status': 'confirmed',
                    'listingTitle': 'Villa Biển Vũng Tàu',
                    'totalPrice': 5000000,
                    'checkInDate': '2026-11-20',
                    'checkOutDate': '2026-11-22',
                  },
                  {
                    'bookingId': 502,
                    'status': 'paid',
                    'listingTitle': 'Penthouse Hạ Long',
                    'totalPrice': 8000000,
                    'checkInDate': '2026-11-25',
                    'checkOutDate': '2026-11-28',
                  },
                ],
              }),
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }
          return ResponseBody.fromString(
            jsonEncode({'items': <Object?>[]}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        final client = DioClient()..dio.httpClientAdapter = adapter;
        final testRepo = HostRepository(client);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hostRepositoryProvider.overrideWithValue(testRepo),
              hostCurrentUserRoleProvider.overrideWithValue('host'),
            ],
            child: const MaterialApp(
              home: HostPortalScreen(
                initialSection: HostPortalSection.bookings,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify triggers exist
        final filterTrigger = find.byKey(const Key('booking_filter_dropdown'));
        final sortTrigger = find.byKey(const Key('booking_sort_dropdown'));
        expect(filterTrigger, findsOneWidget);
        expect(sortTrigger, findsOneWidget);

        // 2. Tap filter trigger: opens modal bottom sheet with status options
        await tester.tap(filterTrigger);
        await tester.pumpAndSettle();

        expect(find.text('Lọc trạng thái đơn'), findsOneWidget);
        expect(find.byType(Scrollbar), findsOneWidget);

        // Tap confirmed status
        final confirmedOption = find.byKey(const Key('booking_filter_confirmed'));
        await tester.ensureVisible(confirmedOption);
        await tester.pumpAndSettle();
        await tester.tap(confirmedOption);
        await tester.pumpAndSettle();

        // Modal closed, filter trigger now displays "Đã xác nhận"
        expect(find.text('Lọc trạng thái đơn'), findsNothing);
        expect(find.text('Đã xác nhận'), findsWidgets);

        // 3. Tap sort trigger: opens modal bottom sheet with sort options
        await tester.tap(sortTrigger);
        await tester.pumpAndSettle();

        expect(find.text('Sắp xếp theo'), findsOneWidget);

        // Tap "Giá cao nhất"
        final sortPriceOption = find.byKey(const Key('booking_sort_total_desc'));
        expect(sortPriceOption, findsOneWidget);
        await tester.tap(sortPriceOption);
        await tester.pumpAndSettle();

        // Modal closed, sort trigger now displays "Giá cao nhất"
        expect(find.text('Sắp xếp theo'), findsNothing);
        expect(find.text('Giá cao nhất'), findsWidgets);
      },
    );

    testWidgets(
      'Item 7i: Tapping phone button on booking card displays both phone number and email/gmail with copy actions',
      (tester) async {
        final adapter = _SimpleAdapter((options) async {
          if (options.path == '/api/host/bookings') {
            return ResponseBody.fromString(
              jsonEncode({
                'items': [
                  {
                    'bookingId': 701,
                    'status': 'confirmed',
                    'guestName': 'Lê Hoàng Long',
                    'guestPhone': '0901234567',
                    'guestEmail': 'long.le@example.com',
                    'listingTitle': 'Seaside Sunset Homestay',
                    'totalPrice': 4440000,
                    'checkInDate': '2026-11-20',
                    'checkOutDate': '2026-11-22',
                  },
                ],
              }),
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }
          return ResponseBody.fromString(
            jsonEncode({'items': <Object?>[]}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        final client = DioClient()..dio.httpClientAdapter = adapter;
        final testRepo = HostRepository(client);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hostRepositoryProvider.overrideWithValue(testRepo),
              hostCurrentUserRoleProvider.overrideWithValue('host'),
            ],
            child: const MaterialApp(
              home: HostPortalScreen(
                initialSection: HostPortalSection.bookings,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the phone call button on the booking card
        final phoneBtn = find.descendant(
          of: find.byKey(const Key('host_booking_card_701')),
          matching: find.byIcon(LucideIcons.phone),
        );
        expect(phoneBtn, findsOneWidget);

        // Tap the phone button
        await tester.tap(phoneBtn);
        await tester.pumpAndSettle();

        // Verify contact dialog appears with both phone and email
        expect(find.text('Thông tin liên hệ khách'), findsOneWidget);
        expect(find.text('Lê Hoàng Long'), findsWidgets);
        expect(find.text('0901234567'), findsOneWidget);
        expect(find.text('long.le@example.com'), findsOneWidget);

        // Verify copy buttons exist
        expect(
          find.byKey(const Key('guest_contact_copy_phone_btn')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('guest_contact_copy_email_btn')),
          findsOneWidget,
        );

        // Verify actionable Call, Zalo and Email buttons exist in dialog
        expect(
          find.byKey(const Key('guest_contact_call_phone_btn')),
          findsOneWidget,
        );
        expect(find.text('Gọi điện'), findsOneWidget);
        expect(
          find.byKey(const Key('guest_contact_zalo_btn')),
          findsOneWidget,
        );
        expect(find.text('Nhắn Zalo'), findsOneWidget);
        expect(
          find.byKey(const Key('guest_contact_send_email_btn')),
          findsOneWidget,
        );
        expect(find.text('Gửi thư điện tử (Gmail/Email)'), findsOneWidget);

        // Tap Close button
        await tester.tap(find.byKey(const Key('guest_contact_close_btn')));
        await tester.pumpAndSettle();

        expect(find.text('Thông tin liên hệ khách'), findsNothing);

        // Verify Zalo quick button also exists directly on the booking card
        final zaloCardBtn = find.descendant(
          of: find.byKey(const Key('host_booking_card_701')),
          matching: find.byIcon(LucideIcons.messageCircle),
        );
        expect(zaloCardBtn, findsOneWidget);
      },
    );

    test(
      'CHROME-08: HostPortalSection.fromSlug resolves tai-chinh, rut-tien, finance, lich, and cho-nghi/them-moi aliases',
      () {
        for (final alias in [
          'tai-chinh',
          'thanh-toan',
          'rut-tien',
          'finance',
          'payouts',
          '  TAI-CHINH  ',
        ]) {
          final section = HostPortalSection.fromSlug(alias);
          expect(section, HostPortalSection.payouts);
          expect(section.routeSlug, 'thanh-toan');
        }

        expect(HostPortalSection.fromSlug('lich'), HostPortalSection.calendar);
        expect(
          HostPortalSection.fromSlug('cho-nghi/them-moi'),
          HostPortalSection.newProperty,
        );
      },
    );

    testWidgets(
      'CHROME-08: direct /chu-nha/tai-chinh route redirects to /chu-nha/thanh-toan and persists kHostLastActiveSectionKey',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final adapter = _SimpleAdapter((options) async {
          return ResponseBody.fromString(
            jsonEncode({'items': <Object?>[]}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

        final client = DioClient()..dio.httpClientAdapter = adapter;
        final testRepo = HostRepository(client);

        final router = GoRouter(
          initialLocation: '/chu-nha/tai-chinh',
          routes: [
            GoRoute(
              path: '/chu-nha',
              redirect: (context, state) async {
                final prefs = await SharedPreferences.getInstance();
                final cached = prefs.getString(kHostLastActiveSectionKey);
                if (cached != null &&
                    cached.isNotEmpty &&
                    cached != 'tong-quan') {
                  final section = HostPortalSection.fromSlug(cached);
                  if (section != HostPortalSection.overview) {
                    return '/chu-nha/${section.routeSlug}';
                  }
                }
                return '/chu-nha/tong-quan';
              },
            ),
            GoRoute(
              path: '/chu-nha/tong-quan',
              builder: (context, state) =>
                  const HostPortalScreen(section: 'tong-quan'),
            ),
            GoRoute(
              path: '/chu-nha/thanh-toan',
              builder: (context, state) =>
                  const HostPortalScreen(section: 'thanh-toan'),
            ),
            GoRoute(
              path: '/chu-nha/tai-chinh',
              redirect: (context, state) => '/chu-nha/thanh-toan',
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hostRepositoryProvider.overrideWithValue(testRepo),
              hostCurrentUserRoleProvider.overrideWithValue('host'),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          router.routeInformationProvider.value.uri.path,
          '/chu-nha/thanh-toan',
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(kHostLastActiveSectionKey), 'thanh-toan');

        // Navigating to /chu-nha restores /chu-nha/thanh-toan via kHostLastActiveSectionKey
        router.go('/chu-nha');
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          '/chu-nha/thanh-toan',
        );
      },
    );
  });
}

class _SimpleAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) handler;
  _SimpleAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}
