import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/app/theme/app_colors.dart';

import 'package:hotel_booking_flutter/features/host/domain/host_models.dart';
import 'package:hotel_booking_flutter/features/host/presentation/widgets/host_chat_composer_bar.dart';
import 'package:hotel_booking_flutter/features/host/presentation/widgets/host_studio_widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
