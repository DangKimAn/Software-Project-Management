import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/di/providers.dart';
import '../../../core/network/dio_client.dart';

class BlogPost {
  final String id;
  final String slug;
  final String title;
  final String excerpt;
  final String content;
  final String coverImage;
  final String category;
  final String location;
  final String readTime;
  final String authorName;
  final String publishedAt;
  final int readTimeMinutes;
  final List<String> tags;

  const BlogPost({
    required this.id,
    required this.slug,
    required this.title,
    required this.excerpt,
    required this.content,
    required this.coverImage,
    required this.category,
    this.location = 'Vũng Tàu',
    this.readTime = '5 phút đọc',
    required this.authorName,
    required this.publishedAt,
    this.readTimeMinutes = 5,
    this.tags = const [],
  });

  factory BlogPost.fromJson(Map<String, dynamic> json) {
    final id = (json['blogId'] ?? json['id'] ?? '').toString();
    final slug = (json['slug'] ?? id).toString();
    final rawContent = json['content'] ?? json['body'] ?? json['excerpt'] ?? '';
    final contentText = rawContent is List
        ? rawContent.map((e) => e.toString()).join('\n\n')
        : rawContent.toString();
    final mins = (json['readTimeMinutes'] as num?)?.toInt() ?? 5;
    final readTimeStr = (json['readTime'] ?? '$mins phút đọc').toString();
    return BlogPost(
      id: id,
      slug: slug,
      title: (json['title'] ?? '').toString(),
      excerpt: (json['excerpt'] ?? json['summary'] ?? '').toString(),
      content: contentText,
      coverImage: (json['coverImage'] ??
              json['thumbnail'] ??
              json['imageUrl'] ??
              'assets/images/lacase.jpg')
          .toString(),
      category: (json['category'] ?? 'Cẩm nang chuyến đi').toString(),
      location: (json['location'] ?? 'Vũng Tàu').toString(),
      readTime: readTimeStr,
      authorName: (json['authorName'] ??
              (json['author'] is Map ? json['author']['fullName'] : null) ??
              'Ban biên tập VungTau Stay')
          .toString(),
      publishedAt:
          (json['publishedAt'] ?? json['createdAt'] ?? '2026-05-05').toString(),
      readTimeMinutes: mins,
      tags: json['tags'] is List
          ? (json['tags'] as List).map((e) => e.toString()).toList()
          : const ['Vũng Tàu', 'Nghỉ dưỡng', 'Villa'],
    );
  }
}

class BlogRepository {
  final DioClient _client;

  const BlogRepository(this._client);

  Future<List<BlogPost>> getBlogs({
    String? category,
    String? query,
    int page = 1,
    int limit = 12,
  }) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/api/blogs',
        queryParameters: {
          if (category != null && category != 'Tất cả' && category.isNotEmpty)
            'category': category,
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
          'page': page,
          'limit': limit,
        },
      );
      final data = DioClient.unwrapEnvelope(response.data);
      List<dynamic> list = [];
      if (data is List) {
        list = data;
      } else if (data is Map<String, dynamic> && data['items'] is List) {
        list = data['items'] as List<dynamic>;
      }
      final parsed = list
          .whereType<Map<String, dynamic>>()
          .map(BlogPost.fromJson)
          .toList();
      return parsed;
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<BlogPost?> getBlogBySlug(String slug) async {
    try {
      final response =
          await _client.dio.get<Map<String, dynamic>>('/api/blogs/$slug');
      final data = DioClient.unwrapEnvelope(response.data);
      if (data is Map<String, dynamic> && data.isNotEmpty) {
        return BlogPost.fromJson(data);
      }
      return null;
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }
}

final blogRepositoryProvider = Provider<BlogRepository>((ref) {
  final client = ref.watch(dioClientProvider);
  return BlogRepository(client);
});

final blogListProvider =
    FutureProvider.autoDispose.family<List<BlogPost>, String?>((ref, category) {
  return ref
      .watch(blogRepositoryProvider)
      .getBlogs(category: category, limit: 12);
});

final blogHighlightsProvider =
    FutureProvider.autoDispose<List<BlogPost>>((ref) {
  return ref.watch(blogRepositoryProvider).getBlogs(limit: 3);
});

final blogDetailProvider =
    FutureProvider.autoDispose.family<BlogPost?, String>((ref, slug) {
  return ref.watch(blogRepositoryProvider).getBlogBySlug(slug);
});
