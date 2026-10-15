import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_header_footer.dart';
import '../../../../shared/widgets/app_image.dart';
import '../../data/blog_repository.dart';

/// Port of `Source goc/frontend/src/views/pages/Blog/BlogDetailPage.tsx`.
class BlogDetailScreen extends ConsumerWidget {
  final String slug;

  const BlogDetailScreen({
    super.key,
    required this.slug,
  });

  /// Matches `getRelatedPosts` in `BlogDetailPage.tsx`:
  /// - Excludes `currentPost` by slug and id
  /// - Prioritizes posts in the same category, then other categories
  /// - Returns up to [maxCount] posts (default 3)
  static List<BlogPost> selectRelatedPosts(
    BlogPost currentPost,
    List<BlogPost> posts, {
    int maxCount = 3,
  }) {
    final candidates = posts.where((candidate) {
      if (candidate.slug.isNotEmpty &&
          currentPost.slug.isNotEmpty &&
          candidate.slug == currentPost.slug) {
        return false;
      }
      if (candidate.id.isNotEmpty &&
          currentPost.id.isNotEmpty &&
          candidate.id == currentPost.id) {
        return false;
      }
      return true;
    }).toList();

    final sameCategory = candidates
        .where(
          (p) =>
              p.category.trim().toLowerCase() ==
              currentPost.category.trim().toLowerCase(),
        )
        .toList();
    final otherCategory = candidates
        .where(
          (p) =>
              p.category.trim().toLowerCase() !=
              currentPost.category.trim().toLowerCase(),
        )
        .toList();

    return [...sameCategory, ...otherCategory].take(maxCount).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(blogDetailProvider(slug));
    // Watch blog list for related posts; if it errors or is loading, gracefully
    // fallback to empty list so the main article never fails.
    final allBlogsAsync = ref.watch(blogListProvider(null));
    final allBlogs = allBlogsAsync.valueOrNull ?? const <BlogPost>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const AppTopHeader(currentPath: '/blog'),
          Expanded(
            child: postAsync.when(
              data: (post) {
                if (post == null) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Không tìm thấy bài viết',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => context.go('/blog'),
                          child: const Text('Quay lại Blog'),
                        ),
                      ],
                    ),
                  );
                }

                final relatedPosts = selectRelatedPosts(post, allBlogs);

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 840),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 48,
                                  child: TextButton.icon(
                                    onPressed: () => context.go('/blog'),
                                    icon: const Icon(
                                      LucideIcons.arrowLeft,
                                      size: 16,
                                      color: AppColors.iconStrong,
                                    ),
                                    label: const Text('Tất cả bài viết'),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceWarmSand,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    post.category.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  post.title,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          LucideIcons.calendar,
                                          size: 15,
                                          color: AppColors.iconStrong,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          post.publishedAt,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          LucideIcons.clock,
                                          size: 15,
                                          color: AppColors.iconStrong,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          post.readTime,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          LucideIcons.mapPin,
                                          size: 15,
                                          color: AppColors.iconStrong,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          post.location,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: AppImage(
                                      url: post.coverImage,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  post.excerpt,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                    height: 1.55,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  post.content,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                    height: 1.75,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: post.tags
                                      .map(
                                        (t) => Chip(
                                          label: Text('#$t'),
                                          backgroundColor:
                                              AppColors.surfaceWarmSand,
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (relatedPosts.isNotEmpty)
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1120),
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 12, 20, 36),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(height: 32),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      const Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'BÀI VIẾT LIÊN QUAN',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.2,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Gợi ý đọc tiếp',
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(
                                        height: 48,
                                        child: TextButton.icon(
                                          onPressed: () => context.go('/blog'),
                                          icon: const Icon(
                                            LucideIcons.arrowRight,
                                            size: 16,
                                            color: AppColors.iconStrong,
                                          ),
                                          label: const Text(
                                            'Xem tất cả bài viết',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final cols = constraints.maxWidth >= 900
                                          ? 3
                                          : constraints.maxWidth >= 600
                                              ? 2
                                              : 1;
                                      final cardWidth = (constraints.maxWidth -
                                              (cols - 1) * 16) /
                                          cols;
                                      return Wrap(
                                        spacing: 16,
                                        runSpacing: 16,
                                        children: relatedPosts
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                          final idx = entry.key;
                                          final related = entry.value;
                                          return SizedBox(
                                            width: cardWidth,
                                            child: FadeSlideIn(
                                              delay: Duration(
                                                milliseconds: idx * 45,
                                              ),
                                              child: _RelatedBlogPostCard(
                                                post: related,
                                                onTap: () => context.go(
                                                  '/blog/${related.slug}',
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const AppFooter(),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => AppErrorView(
                message: err.toString(),
                onRetry: () => ref.invalidate(blogDetailProvider(slug)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedBlogPostCard extends StatelessWidget {
  final BlogPost post;
  final VoidCallback onTap;

  const _RelatedBlogPostCard({
    required this.post,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('related-blog-card-${post.slug}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: AppImage(
                url: post.coverImage,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWarmSand,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      post.category,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    post.excerpt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${post.publishedAt} · ${post.readTime}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Icon(
                        LucideIcons.arrowUpRight,
                        size: 16,
                        color: AppColors.iconStrong,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
