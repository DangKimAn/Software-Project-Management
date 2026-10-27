import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_header_footer.dart';
import '../../../booking_inquiry/domain/services/contact_service.dart';
import '../../data/blog_repository.dart';
import 'blog_screen.dart';

/// Port of `Source goc/frontend/src/views/pages/Blog/BlogDetailPage.tsx`
/// adhering to Minh Thanh Villa Light Luxury Design System (FLUTTER_RULES.md).
class BlogDetailScreen extends ConsumerWidget {
  final String slug;

  const BlogDetailScreen({
    super.key,
    required this.slug,
  });

  /// Matches `getRelatedPosts` in `BlogDetailPage.tsx`:
  /// - Excludes `currentPost` by slug and id
  /// - Prioritizes posts in the same category, then other categories (unless [sameCategoryOnly] is true)
  /// - Returns up to [maxCount] posts (default 3), never fabricating fake articles.
  static List<BlogPost> selectRelatedPosts(
    BlogPost currentPost,
    List<BlogPost> posts, {
    int maxCount = 3,
    bool sameCategoryOnly = false,
  }) {
    if (maxCount <= 0 || posts.isEmpty) return const [];

    final candidates = posts.where((candidate) {
      if (candidate.title.trim().isEmpty || candidate.slug.trim().isEmpty) {
        return false;
      }
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

    final currentCategory = currentPost.category.trim().toLowerCase();
    final sameCategory = candidates
        .where((p) => p.category.trim().toLowerCase() == currentCategory)
        .toList();

    if (sameCategoryOnly) {
      return sameCategory.take(maxCount).toList();
    }

    final otherCategory = candidates
        .where((p) => p.category.trim().toLowerCase() != currentCategory)
        .toList();

    return [...sameCategory, ...otherCategory].take(maxCount).toList();
  }

  /// Builds a canonical deep link / share URL for a validated blog [slug].
  static String? buildCanonicalShareUrl(String rawSlug) {
    final cleanSlug = BlogContentSanitizer.normalizeSlug(rawSlug);
    if (cleanSlug.isEmpty) return null;
    final scheme = AppConfig.deepLinkScheme.trim().isNotEmpty
        ? AppConfig.deepLinkScheme.trim().toLowerCase()
        : 'minhthanhvilla';
    return '$scheme://blog/$cleanSlug';
  }

  /// Handles tapping an inline link in rich blog content safely.
  static Future<bool> handleContentLinkTap(
    BuildContext context,
    String? rawUrl,
  ) async {
    final safeUrl = BlogContentSanitizer.sanitizeLinkUrl(rawUrl);
    if (safeUrl == null) return false;

    if (safeUrl.startsWith('/')) {
      if (context.mounted) {
        unawaited(context.push(safeUrl));
      }
      return true;
    }

    final result = await ContactService.openExternalHttpsUrl(safeUrl);
    if (!result.launched && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(result.message),
            duration: const Duration(seconds: 2),
          ),
        );
    }
    return result.launched;
  }

  Future<void> _sharePost(BuildContext context, BlogPost post) async {
    final canonicalLink = buildCanonicalShareUrl(post.slug);
    if (canonicalLink == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Liên kết bài viết không hợp lệ để chia sẻ.'),
              duration: Duration(seconds: 2),
            ),
          );
      }
      return;
    }

    final sharePayload = '${post.title}\n$canonicalLink';
    final copied = await ContactService.copyTextToClipboard(sharePayload);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            copied
                ? 'Đã sao chép liên kết bài viết vào bộ nhớ tạm'
                : 'Không thể sao chép liên kết bài viết trên thiết bị này.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  (String, String) _resolveErrorTitleAndMessage(Object err) {
    if (err is NetworkFailure) {
      return ('Không có kết nối mạng', err.message);
    }
    if (err is ServerFailure) {
      return ('Lỗi máy chủ', err.message);
    }
    if (err is RateLimitFailure) {
      return ('Tạm thời quá tải', err.message);
    }
    if (err is AppFailure) {
      return ('Không thể tải bài viết', err.message);
    }
    return ('Không thể tải bài viết', err.toString());
  }

  Widget _buildNotFoundView(BuildContext context, {VoidCallback? onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.fileX,
              size: 32,
              color: AppColors.iconMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Không tìm thấy bài viết',
              textAlign: TextAlign.center,
              style: AppTypography.sectionHeading.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Bài viết có thể đã được gỡ hoặc đường dẫn không chính xác.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMuted,
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                if (onRetry != null)
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      shape: const StadiumBorder(),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    icon: const Icon(
                      LucideIcons.refreshCw,
                      size: 16,
                      color: AppColors.iconStrong,
                    ),
                    label: const Text('Thử lại'),
                  ),
                FilledButton(
                  onPressed: () => context.go('/blog'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Quay lại Blog'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cleanSlug = BlogContentSanitizer.normalizeSlug(slug);
    if (cleanSlug.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const AppTopHeader(currentPath: '/blog'),
              Expanded(child: _buildNotFoundView(context)),
            ],
          ),
        ),
      );
    }

    final postAsync = ref.watch(blogDetailProvider(cleanSlug));
    // Watch blog list for related posts; if it errors or is loading, gracefully
    // fallback to empty list so the main article never fails.
    final allBlogsAsync = ref.watch(blogListProvider(null));
    final allBlogs = allBlogsAsync.valueOrNull ?? const <BlogPost>[];
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPad = screenWidth < 360 ? AppSpacing.md : 20.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTopHeader(currentPath: '/blog'),
            Expanded(
              child: postAsync.when(
                data: (post) {
                  if (post == null) {
                    return _buildNotFoundView(
                      context,
                      onRetry: () =>
                          ref.invalidate(blogDetailProvider(cleanSlug)),
                    );
                  }

                  final relatedPosts = selectRelatedPosts(post, allBlogs);

                  return SingleChildScrollView(
                    key: ValueKey('blog-detail-scroll-${post.slug}'),
                    child: Column(
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 840),
                            child: Padding(
                              padding: EdgeInsets.all(horizontalPad),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top Action Row: Back button + Bare Lucide Share button (48x48dp)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              minHeight: 48,
                                            ),
                                            child: TextButton.icon(
                                              onPressed: () =>
                                                  context.go('/blog'),
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    AppColors.textStrong,
                                                minimumSize: const Size(48, 48),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: AppSpacing.sm,
                                                  vertical: AppSpacing.xs,
                                                ),
                                                shape: const StadiumBorder(),
                                              ),
                                              icon: const Icon(
                                                LucideIcons.arrowLeft,
                                                size: 16,
                                                color: AppColors.iconStrong,
                                              ),
                                              label: const Text(
                                                'Tất cả bài viết',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      AppIconButton(
                                        key: const ValueKey(
                                          'blog-share-button',
                                        ),
                                        tooltip: 'Chia sẻ bài viết',
                                        icon: const Icon(
                                          LucideIcons.share2,
                                          size: 20,
                                          color: AppColors.iconStrong,
                                        ),
                                        onPressed: () =>
                                            _sharePost(context, post),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 5,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: AppColors.surfaceWarmSand,
                                      borderRadius: AppRadii.roundedPill,
                                    ),
                                    child: Text(
                                      post.category.toUpperCase(),
                                      style: AppTypography.caption.copyWith(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    post.title,
                                    style: AppTypography.displayMedium.copyWith(
                                      fontSize: screenWidth < 360 ? 22 : 28,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Wrap(
                                    spacing: AppSpacing.md,
                                    runSpacing: AppSpacing.xs,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      if (post.publishedAt.isNotEmpty)
                                        _BlogMetaItem(
                                          icon: LucideIcons.calendar,
                                          text: post.publishedAt,
                                          isBold: true,
                                        ),
                                      if (post.readTime.isNotEmpty)
                                        _BlogMetaItem(
                                          icon: LucideIcons.clock,
                                          text: post.readTime,
                                        ),
                                      if (post.location.isNotEmpty)
                                        _BlogMetaItem(
                                          icon: LucideIcons.mapPin,
                                          text: post.location,
                                        ),
                                      if (post.authorName.isNotEmpty)
                                        _BlogMetaItem(
                                          icon: LucideIcons.user,
                                          text: post.authorName,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  BlogCoverImage(
                                    rawUrl: post.coverImage,
                                    aspectRatio: 16 / 9,
                                    borderRadius: AppRadii.roundedCard,
                                  ),
                                  const SizedBox(height: AppSpacing.xl),
                                  if (post.excerpt.isNotEmpty) ...[
                                    Text(
                                      post.excerpt,
                                      style: AppTypography.bodyLarge.copyWith(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                        height: 1.55,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                  ],
                                  BlogRichContentRenderer(
                                    blocks: post.resolvedBlocks,
                                    onLinkTap: (url) =>
                                        handleContentLinkTap(context, url),
                                  ),
                                  if (post.tags.isNotEmpty) ...[
                                    const SizedBox(height: AppSpacing.xl),
                                    Wrap(
                                      spacing: AppSpacing.xs,
                                      runSpacing: AppSpacing.xs,
                                      children: post.tags
                                          .map(
                                            (t) => Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color:
                                                    AppColors.surfaceWarmSand,
                                                borderRadius:
                                                    AppRadii.roundedPill,
                                                border: Border.all(
                                                  color: AppColors.borderSoft,
                                                ),
                                              ),
                                              child: Text(
                                                '#$t',
                                                style: AppTypography.caption
                                                    .copyWith(
                                                  color: AppColors.textStrong,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                  const SizedBox(height: AppSpacing.xxl),
                                  // Consultation CTA Card (24dp radius, pill CTAs, bare Lucide icons)
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(
                                      screenWidth < 360
                                          ? AppSpacing.md
                                          : AppSpacing.xl,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceBase,
                                      borderRadius: AppRadii.roundedCard,
                                      border: Border.all(
                                        color: AppColors.borderSoft,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Cần tư vấn đặt biệt thự Vũng Tàu?',
                                          style: AppTypography.sectionHeading
                                              .copyWith(
                                            fontSize: 18,
                                            color: AppColors.textStrong,
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        const Text(
                                          'Kết nối với đội ngũ Minh Thanh Villa để kiểm tra lịch trống và báo giá chính xác theo đoàn khách của bạn.',
                                          style: AppTypography.bodyMuted,
                                        ),
                                        const SizedBox(height: AppSpacing.md),
                                        Wrap(
                                          spacing: AppSpacing.sm,
                                          runSpacing: AppSpacing.sm,
                                          children: [
                                            FilledButton.icon(
                                              onPressed: () =>
                                                  context.push('/lien-he'),
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.primary,
                                                foregroundColor: Colors.white,
                                                minimumSize: const Size(48, 48),
                                                shape: const StadiumBorder(),
                                              ),
                                              icon: const Icon(
                                                LucideIcons.messageCircle,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                              label: const Text(
                                                'Liên hệ tư vấn',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  context.push('/tim-kiem'),
                                              style: OutlinedButton.styleFrom(
                                                minimumSize: const Size(48, 48),
                                                shape: const StadiumBorder(),
                                                side: const BorderSide(
                                                  color: AppColors.border,
                                                ),
                                              ),
                                              icon: const Icon(
                                                LucideIcons.search,
                                                size: 16,
                                                color: AppColors.iconStrong,
                                              ),
                                              label: const Text(
                                                'Tìm kiếm villa',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
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
                                padding: EdgeInsets.fromLTRB(
                                  horizontalPad,
                                  AppSpacing.sm,
                                  horizontalPad,
                                  AppSpacing.xxl,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Divider(height: AppSpacing.xxl),
                                    Wrap(
                                      spacing: AppSpacing.sm,
                                      runSpacing: AppSpacing.xs,
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
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            minHeight: 48,
                                          ),
                                          child: TextButton.icon(
                                            onPressed: () =>
                                                context.go('/blog'),
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  AppColors.textStrong,
                                              minimumSize: const Size(48, 48),
                                              shape: const StadiumBorder(),
                                            ),
                                            icon: const Icon(
                                              LucideIcons.arrowRight,
                                              size: 16,
                                              color: AppColors.iconStrong,
                                            ),
                                            label: const Text(
                                              'Xem tất cả bài viết',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final cols = constraints.maxWidth >= 900
                                            ? 3
                                            : constraints.maxWidth >= 600
                                                ? 2
                                                : 1;
                                        final cardWidth =
                                            (constraints.maxWidth -
                                                    (cols - 1) * 16) /
                                                cols;
                                        return Wrap(
                                          spacing: AppSpacing.md,
                                          runSpacing: AppSpacing.md,
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
                loading: () => Center(
                  child: Semantics(
                    label: 'Đang tải bài viết',
                    child: const CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  ),
                ),
                error: (err, _) {
                  if (err is NotFoundFailure) {
                    return _buildNotFoundView(
                      context,
                      onRetry: () =>
                          ref.invalidate(blogDetailProvider(cleanSlug)),
                    );
                  }
                  final (title, message) = _resolveErrorTitleAndMessage(err);
                  return AppErrorView(
                    title: title,
                    message: message,
                    onRetry: () =>
                        ref.invalidate(blogDetailProvider(cleanSlug)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlogMetaItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isBold;

  const _BlogMetaItem({
    required this.icon,
    required this.text,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: AppColors.iconStrong,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
              color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Safe native widget renderer for structured [BlogContentBlock]s.
///
/// Never executes raw HTML/scripts and only attaches tap handlers to links
/// that have passed [BlogContentSanitizer.sanitizeLinkUrl].
class BlogRichContentRenderer extends StatefulWidget {
  final List<BlogContentBlock> blocks;
  final Future<void> Function(String url)? onLinkTap;

  const BlogRichContentRenderer({
    super.key,
    required this.blocks,
    this.onLinkTap,
  });

  @override
  State<BlogRichContentRenderer> createState() =>
      _BlogRichContentRendererState();
}

class _BlogRichContentRendererState extends State<BlogRichContentRenderer> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  TextSpan _buildInlineTextSpan(
    List<BlogInlineSpan> spans,
    TextStyle baseStyle,
  ) {
    return TextSpan(
      style: baseStyle,
      children: spans.map((span) {
        final safeLink = BlogContentSanitizer.sanitizeLinkUrl(span.linkUrl);
        TapGestureRecognizer? recognizer;
        if (safeLink != null && widget.onLinkTap != null) {
          recognizer = TapGestureRecognizer()
            ..onTap = () {
              widget.onLinkTap!(safeLink);
            };
          _recognizers.add(recognizer);
        }

        return TextSpan(
          text: span.text,
          recognizer: recognizer,
          style: baseStyle.copyWith(
            fontWeight: span.isBold || safeLink != null
                ? FontWeight.w700
                : baseStyle.fontWeight,
            fontStyle: span.isItalic ? FontStyle.italic : baseStyle.fontStyle,
            color: safeLink != null ? AppColors.primary : baseStyle.color,
            decoration: safeLink != null
                ? TextDecoration.underline
                : TextDecoration.none,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    if (widget.blocks.isEmpty) {
      return const SizedBox.shrink();
    }

    const paragraphStyle = TextStyle(
      fontSize: 15,
      color: AppColors.textPrimary,
      height: 1.75,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < widget.blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          _buildBlockWidget(widget.blocks[i], paragraphStyle),
        ],
      ],
    );
  }

  Widget _buildBlockWidget(
    BlogContentBlock block,
    TextStyle paragraphStyle,
  ) {
    switch (block.type) {
      case BlogBlockType.heading:
        final headingStyle = TextStyle(
          fontSize: block.headingLevel <= 2 ? 20 : 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textStrong,
          height: 1.35,
        );
        return Text.rich(
          _buildInlineTextSpan(block.spans, headingStyle),
        );

      case BlogBlockType.quote:
        final quoteStyle = paragraphStyle.copyWith(
          fontStyle: FontStyle.italic,
          color: AppColors.textSecondary,
        );
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: const BoxDecoration(
            color: AppColors.surfaceWarmSand,
            borderRadius: BorderRadius.all(Radius.circular(20)),
            border: Border(
              left: BorderSide(color: AppColors.primary, width: 3),
            ),
          ),
          child: Text.rich(
            _buildInlineTextSpan(block.spans, quoteStyle),
          ),
        );

      case BlogBlockType.bulletList:
      case BlogBlockType.orderedList:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var idx = 0; idx < block.listItems.length; idx++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      block.type == BlogBlockType.orderedList
                          ? '${idx + 1}. '
                          : '• ',
                      style: paragraphStyle.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textStrong,
                      ),
                    ),
                    Expanded(
                      child: Text.rich(
                        _buildInlineTextSpan(
                          block.listItems[idx],
                          paragraphStyle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );

      case BlogBlockType.paragraph:
        return Text.rich(
          _buildInlineTextSpan(block.spans, paragraphStyle),
        );
    }
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
    final metaParts = <String>[
      if (post.publishedAt.isNotEmpty) post.publishedAt,
      if (post.readTime.isNotEmpty) post.readTime,
    ];
    final metaText = metaParts.join(' · ');

    return Semantics(
      button: true,
      label: 'Bài viết liên quan: ${post.title}',
      child: InkWell(
        key: ValueKey('related-blog-card-${post.slug}'),
        onTap: onTap,
        borderRadius: AppRadii.roundedCard,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceBase,
            borderRadius: AppRadii.roundedCard,
            border: Border.all(color: AppColors.borderSoft),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BlogCoverImage(
                rawUrl: post.coverImage,
                aspectRatio: 16 / 10,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadii.card),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceWarmSand,
                        borderRadius: AppRadii.roundedPill,
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
                    const SizedBox(height: AppSpacing.xs),
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
                    if (post.excerpt.isNotEmpty) ...[
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
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            metaText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
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
      ),
    );
  }
}
