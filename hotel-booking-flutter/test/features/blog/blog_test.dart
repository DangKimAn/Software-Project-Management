import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hotel_booking_flutter/app/di/providers.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';
import 'package:hotel_booking_flutter/core/errors/app_failure.dart';
import 'package:hotel_booking_flutter/core/network/dio_client.dart';
import 'package:hotel_booking_flutter/core/security/secure_storage_service.dart';
import 'package:hotel_booking_flutter/features/blog/data/blog_repository.dart';
import 'package:hotel_booking_flutter/features/blog/presentation/screens/blog_detail_screen.dart';
import 'package:hotel_booking_flutter/features/blog/presentation/screens/blog_screen.dart';
import 'package:hotel_booking_flutter/features/booking_inquiry/domain/services/contact_service.dart';

class _FakeSecureStorage extends SecureStorageService {
  String? token;

  @override
  Future<String?> getAuthToken() async => token;

  @override
  Future<void> saveAuthToken(String value) async {
    token = value;
  }

  @override
  Future<void> deleteAuthToken() async {
    token = null;
  }
}

Dio _buildMockDio(
  Future<Response<dynamic>> Function(RequestOptions options) handler,
) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, interceptorHandler) async {
        try {
          final response = await handler(options);
          interceptorHandler.resolve(response);
        } on DioException catch (e) {
          interceptorHandler.reject(e);
        } catch (e) {
          interceptorHandler.reject(
            DioException(requestOptions: options, error: e),
          );
        }
      },
    ),
  );
  return dio;
}

void main() {
  tearDown(ContactService.resetTestOverrides);

  group('BlogRepository & API Contract (GET /api/blogs, GET /api/blogs/:slug)',
      () {
    test('GET /api/blogs handles 0 items without fabricating fallback posts',
        () async {
      final dio = _buildMockDio((options) async {
        expect(options.path, '/api/blogs');
        return Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'data': {
              'items': const <dynamic>[],
              'pagination': {
                'page': 1,
                'limit': 12,
                'total': 0,
                'totalPages': 1,
              },
            },
          },
        );
      });
      final repo = BlogRepository(
        DioClient(dio: dio, secureStorage: _FakeSecureStorage()),
      );

      final result = await repo.getBlogsPaginated();
      expect(result.items, isEmpty);
      expect(result.pagination.total, 0);
      expect(result.pagination.totalPages, 1);
    });

    test(
      'GET /api/blogs parses N items, array content, pagination, and does not fabricate missing cover images/tags',
      () async {
        Map<String, dynamic>? capturedQuery;
        final dio = _buildMockDio((options) async {
          capturedQuery = options.queryParameters;
          return Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'data': {
                'items': [
                  {
                    'id': 10,
                    'slug': 'villa-bai-sau-view-bien',
                    'title': 'Kinh nghiệm chọn villa Bãi Sau',
                    'summary': 'Hướng dẫn chi tiết cho gia đình.',
                    'content': [
                      '## Mở đầu',
                      'Nội dung đoạn 1 <script>alert(1)</script>',
                    ],
                    'thumbnailUrl': '',
                    'categoryName': 'Kinh nghiệm đặt villa',
                    'authorName': 'Minh Thanh Team',
                    'publishedAt': '2026-10-15T08:00:00.000Z',
                    'tags': const <String>[],
                  },
                ],
                'pagination': {
                  'page': 2,
                  'limit': 6,
                  'total': 13,
                  'totalPages': 3,
                },
              },
            },
          );
        });
        final repo = BlogRepository(
          DioClient(dio: dio, secureStorage: _FakeSecureStorage()),
        );

        final result = await repo.getBlogsPaginated(
          category: 'Kinh nghiệm đặt villa',
          query: 'Bãi Sau',
          page: 2,
          limit: 6,
        );

        expect(capturedQuery?['category'], 'Kinh nghiệm đặt villa');
        expect(capturedQuery?['q'], 'Bãi Sau');
        expect(capturedQuery?['page'], 2);
        expect(capturedQuery?['limit'], 6);
        expect(result.items.length, 1);
        final post = result.items.first;
        expect(post.slug, 'villa-bai-sau-view-bien');
        expect(post.coverImage, isEmpty); // Not fabricated!
        expect(post.tags, isEmpty); // Not fabricated!
        expect(post.content, isNot(contains('<script>')));
        expect(result.pagination.page, 2);
        expect(result.pagination.totalPages, 3);
        expect(result.pagination.hasNextPage, isTrue);
        expect(result.pagination.hasPreviousPage, isTrue);
      },
    );

    test('GET /api/blogs/:slug returns null on 404 and rejects traversal slugs',
        () async {
      var networkCalls = 0;
      final dio = _buildMockDio((options) async {
        networkCalls++;
        throw DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 404,
            data: {'message': 'Blog not found'},
          ),
          type: DioExceptionType.badResponse,
        );
      });
      final repo = BlogRepository(
        DioClient(dio: dio, secureStorage: _FakeSecureStorage()),
      );

      final traversalResult = await repo.getBlogBySlug('../admin/secret');
      expect(traversalResult, isNull);
      expect(networkCalls, 0);

      final notFoundResult = await repo.getBlogBySlug('bai-viet-khong-ton-tai');
      expect(notFoundResult, isNull);
      expect(networkCalls, 1);
    });
  });

  group('BlogContentSanitizer & Malformed URL Protection', () {
    test('strips XSS scripts, event handlers, iframes, and unsafe schemes', () {
      const maliciousRaw = '''
<script>window.stealToken()</script>
<iframe src="javascript:alert('xss')"></iframe>
<h2>Tiêu đề an toàn</h2>
<p onclick="evil()">Đoạn văn có <a href="javascript:alert(1)">link độc hại</a> và <a href="https://minhthanhvilla.com/cam-nang">link hợp lệ</a>.</p>
<blockquote>Trích dẫn thực tế từ khách lưu trú.</blockquote>
<ul><li>Mục kiểm tra 1</li><li>Mục kiểm tra 2</li></ul>
''';

      final blocks = BlogContentSanitizer.parseRichBlocks(maliciousRaw);
      final serialized = BlogContentSanitizer.sanitizePlainText(
        maliciousRaw,
        preserveNewlines: true,
      );

      expect(serialized, isNot(contains('stealToken')));
      expect(serialized, isNot(contains('<script')));
      expect(serialized, isNot(contains('<iframe')));
      expect(serialized, isNot(contains('javascript:')));

      expect(
        blocks.any(
          (BlogContentBlock b) =>
              b.type == BlogBlockType.heading &&
              b.plainText == 'Tiêu đề an toàn',
        ),
        isTrue,
      );
      expect(
        blocks.any((BlogContentBlock b) => b.type == BlogBlockType.quote),
        isTrue,
      );
      final bulletBlocks = blocks
          .where((BlogContentBlock b) => b.type == BlogBlockType.bulletList)
          .toList();
      expect(bulletBlocks.length, 1);
      expect(bulletBlocks.first.listItems.length, 2);

      final paragraphBlock = blocks.firstWhere(
        (BlogContentBlock b) =>
            b.type == BlogBlockType.paragraph &&
            b.plainText.contains('Đoạn văn có'),
      );
      final links = paragraphBlock.spans
          .where((BlogInlineSpan s) => s.linkUrl != null)
          .toList();
      expect(links.length, 1);
      expect(links.first.linkUrl, 'https://minhthanhvilla.com/cam-nang');
    });

    test('sanitizeLinkUrl and sanitizeImageUrl reject malformed or unsafe URLs',
        () {
      expect(
          BlogContentSanitizer.sanitizeLinkUrl('javascript:alert(1)'), isNull);
      expect(BlogContentSanitizer.sanitizeLinkUrl('data:text/html;base64,abc'),
          isNull);
      expect(BlogContentSanitizer.sanitizeLinkUrl('ht!tp://bad url'), isNull);
      expect(BlogContentSanitizer.sanitizeLinkUrl('https://localhost/internal'),
          isNull);
      expect(
        BlogContentSanitizer.sanitizeLinkUrl(
            'https://minhthanhvilla.com/villa'),
        'https://minhthanhvilla.com/villa',
      );
      expect(
        BlogContentSanitizer.sanitizeLinkUrl('/villa/101'),
        '/villa/101',
      );

      expect(BlogContentSanitizer.sanitizeImageUrl('javascript:evil()'), '');
      expect(
          BlogContentSanitizer.sanitizeImageUrl(
              'data:image/svg+xml;utf8,<svg/>'),
          '');
      expect(
        BlogContentSanitizer.sanitizeImageUrl('assets/images/lacase.jpg'),
        'assets/images/lacase.jpg',
      );
    });
  });

  group('Related Posts Exclusion & Same-Category Cap', () {
    const current = BlogPost(
      id: '10',
      slug: 'post-current',
      title: 'Current Post',
      excerpt: 'Excerpt',
      content: 'Content',
      coverImage: '',
      category: 'Kinh nghiệm đặt villa',
      authorName: 'Author',
      publishedAt: '2026-10-10',
    );

    BlogPost makeCandidate(String id, String slug, String category) => BlogPost(
          id: id,
          slug: slug,
          title: 'Title $slug',
          excerpt: 'Excerpt $slug',
          content: 'Content $slug',
          coverImage: '',
          category: category,
          authorName: 'Author',
          publishedAt: '2026-10-11',
        );

    test(
        'excludes current post by id/slug, caps at 3, and never fabricates posts when empty',
        () {
      expect(BlogDetailScreen.selectRelatedPosts(current, const [current]),
          isEmpty);

      final candidates = [
        current,
        makeCandidate('10', 'duplicate-id', 'Kinh nghiệm đặt villa'),
        makeCandidate('11', 'same-1', 'Kinh nghiệm đặt villa'),
        makeCandidate('12', 'same-2', 'Kinh nghiệm đặt villa'),
        makeCandidate('13', 'same-3', 'Kinh nghiệm đặt villa'),
        makeCandidate('14', 'same-4', 'Kinh nghiệm đặt villa'),
        makeCandidate('15', 'other-1', 'Ẩm thực địa phương'),
      ];

      final selected = BlogDetailScreen.selectRelatedPosts(
        current,
        candidates,
        sameCategoryOnly: true,
      );
      expect(selected.length, 3);
      expect(selected.map((e) => e.slug), ['same-1', 'same-2', 'same-3']);
      expect(selected.any((e) => e.id == current.id || e.slug == current.slug),
          isFalse);
    });
  });

  group('BlogScreen & BlogDetailScreen Widget & Responsive QA', () {
    ProviderScope wrapWithScope({
      required Widget child,
      List<Override> overrides = const [],
      double textScale = 1.0,
      Size? surfaceSize,
    }) {
      final fakeStorage = _FakeSecureStorage();
      final dio = _buildMockDio((options) async {
        return Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'data': {'items': const <dynamic>[], 'unreadCount': 0},
          },
        );
      });
      final router = GoRouter(
        initialLocation: '/blog',
        routes: [
          GoRoute(
            path: '/blog',
            builder: (context, state) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: surfaceSize,
                textScaler: TextScaler.linear(textScale),
              ),
              child: child,
            ),
          ),
          GoRoute(
            path: '/blog/:slug',
            builder: (context, state) => Scaffold(
              body: Text('Navigated to ${state.pathParameters['slug']}'),
            ),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) =>
                const Scaffold(body: Text('Search Screen')),
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          secureStorageProvider.overrideWithValue(fakeStorage),
          dioClientProvider.overrideWithValue(
            DioClient(dio: dio, secureStorage: fakeStorage),
          ),
          ...overrides,
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      );
    }

    testWidgets(
        'renders 0 posts empty state cleanly without fabricating articles',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrapWithScope(
          child: const BlogScreen(),
          overrides: [
            blogPaginatedProvider.overrideWith(
              (ref, filter) async => const BlogPaginatedResult(
                items: [],
                pagination: BlogPagination(
                  page: 1,
                  limit: 9,
                  total: 0,
                  totalPages: 1,
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chưa có bài viết phù hợp'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'distinguishes ServerFailure vs NetworkFailure and performs real retry on tap',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        var attempt = 0;
        await tester.pumpWidget(
          wrapWithScope(
            child: const BlogScreen(),
            overrides: [
              blogPaginatedProvider.overrideWith((ref, filter) async {
                attempt++;
                if (attempt == 1) {
                  throw const ServerFailure(
                    'Lỗi máy chủ nội bộ (500)',
                    statusCode: 500,
                  );
                }
                if (attempt == 2) {
                  throw const NetworkFailure('Không có kết nối Internet');
                }
                return const BlogPaginatedResult(
                  items: [
                    BlogPost(
                      id: '1',
                      slug: 'bai-viet-sau-retry',
                      title: 'Bài viết tải thành công sau khi thử lại',
                      excerpt: 'Tóm tắt bài viết thật.',
                      content: 'Nội dung thật.',
                      coverImage: '',
                      category: 'Cẩm nang du lịch',
                      authorName: 'Minh Thanh Villa',
                      publishedAt: '2026-10-16',
                    ),
                  ],
                  pagination: BlogPagination(
                    page: 1,
                    limit: 9,
                    total: 1,
                    totalPages: 1,
                  ),
                );
              }),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Attempt 1: Server error is NOT misreported as device offline
        expect(find.text('Lỗi máy chủ'), findsOneWidget);
        expect(find.text('Không có kết nối mạng'), findsNothing);
        expect(find.textContaining('Lỗi máy chủ nội bộ (500)'), findsOneWidget);

        // Tap retry -> Attempt 2: Network offline error
        final retryBtn1 = find.text('Thử lại');
        await tester.ensureVisible(retryBtn1);
        await tester.tap(retryBtn1);
        await tester.pumpAndSettle();

        expect(find.text('Không có kết nối mạng'), findsOneWidget);

        // Tap retry -> Attempt 3: Success
        final retryBtn2 = find.text('Thử lại');
        await tester.ensureVisible(retryBtn2);
        await tester.tap(retryBtn2);
        await tester.pumpAndSettle();

        expect(find.text('Bài viết tải thành công sau khi thử lại'),
            findsOneWidget);
        expect(attempt, 3);
      },
    );

    testWidgets(
      'BlogDetailScreen renders safe rich content, bare 48x48dp share icon, and handles 320dp + textScale 1.6 without overflow',
      (tester) async {
        String? copiedShareText;
        ContactService.clipboardSetDataOverride = (text) async {
          copiedShareText = text;
        };

        const post = BlogPost(
          id: '101',
          slug: 'cam-nang-nghi-duong-vung-tau',
          title:
              'Cẩm nang nghỉ dưỡng biệt thự biển Vũng Tàu dài cho màn hình 320dp',
          excerpt: 'Tổng hợp lưu ý đặt biệt thự biển chính chủ an toàn.',
          content: '''
## Kinh nghiệm chọn căn phù hợp
Đoạn văn kiểm thử với **chữ in đậm** và [liên kết hợp lệ](https://minhthanhvilla.com/villa) cùng [liên kết hỏng](ht!tp://invalid).

> Lưu ý kiểm tra hợp đồng và quy định hồ bơi trước khi nhận bàn giao.

- Kiểm tra số lượng phòng ngủ thực tế
- Xác nhận giờ nhận và trả phòng
''',
          coverImage: '', // Missing image -> must render placeholder cleanly
          category: 'Kinh nghiệm đặt villa',
          authorName: 'Ban biên tập Minh Thanh',
          publishedAt: '2026-10-20',
          tags: ['Bãi Sau', 'Villa Gia Đình'],
        );

        for (final width in [320.0, 360.0, 390.0, 430.0]) {
          await tester.binding.setSurfaceSize(Size(width, 900));
          await tester.pumpWidget(
            wrapWithScope(
              surfaceSize: Size(width, 900),
              textScale: width == 320.0 ? 1.6 : 1.0,
              child:
                  const BlogDetailScreen(slug: 'cam-nang-nghi-duong-vung-tau'),
              overrides: [
                blogDetailProvider('cam-nang-nghi-duong-vung-tau')
                    .overrideWith((ref) async => post),
                blogListProvider(null)
                    .overrideWith((ref) async => const [post]),
              ],
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'BlogDetailScreen must not overflow at width $width',
          );
        }

        // Verify share button hit target >= 48x48dp and copies canonical link
        final shareFinder = find.byKey(const ValueKey('blog-share-button'));
        expect(shareFinder, findsOneWidget);
        final shareSize = tester.getSize(shareFinder);
        expect(shareSize.width, greaterThanOrEqualTo(48));
        expect(shareSize.height, greaterThanOrEqualTo(48));

        await tester.tap(shareFinder);
        await tester.pumpAndSettle();
        expect(
          copiedShareText,
          contains('minhthanhvilla://blog/cam-nang-nghi-duong-vung-tau'),
        );

        // Verify rich content blocks rendered
        expect(
          find.text('Kinh nghiệm chọn căn phù hợp', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Kiểm tra số lượng phòng ngủ thực tế',
            findRichText: true,
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('blog-cover-placeholder')),
          findsOneWidget,
        );

        await tester.binding.setSurfaceSize(null);
      },
    );
  });
}
