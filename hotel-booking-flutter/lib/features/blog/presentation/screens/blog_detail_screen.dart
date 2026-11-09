import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_header_footer.dart';
import '../../../booking_inquiry/domain/services/contact_service.dart';
import '../../data/blog_repository.dart';
import 'blog_screen.dart';

/// Port of `Source goc/frontend/src/views/pages/Blog/BlogDetailPage.tsx`
/// adhering to The Palm Light Luxury Design System (FLUTTER_RULES.md).
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
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(context.l10n.blogShareInvalidLink),
              duration: const Duration(seconds: 2),
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
                ? context.l10n.blogShareSuccess
                : context.l10n.blogShareFailure,
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  (String, String) _resolveErrorTitleAndMessage(
    Object err,
    BuildContext context,
    String localeCode,
  ) {
    final errorCopy = LocaleFormatters.localizeFailure(
      err,
      localeCode: localeCode,
      l10n: context.l10n,
    );
    if (err is AppFailure && err.message.trim().isNotEmpty) {
      return (errorCopy.title, err.message);
    }
    return (errorCopy.title, errorCopy.message);
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
              context.l10n.blogNotFoundTitle,
              textAlign: TextAlign.center,
              style: AppTypography.sectionHeading.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.l10n.blogNotFoundDescription,
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
                    label: Text(context.l10n.ctaRetry),
                  ),
                FilledButton(
                  onPressed: () => context.go('/blog'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(context.l10n.blogBackToBlog),
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
    final localeCode = ref.watch(localeProvider);
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
                data: (rawPost) {
                  if (rawPost == null) {
                    return _buildNotFoundView(
                      context,
                      onRetry: () =>
                          ref.invalidate(blogDetailProvider(cleanSlug)),
                    );
                  }

                  final post = LocaleFormatters.localizeBlogPost(
                    rawPost,
                    localeCode: localeCode,
                    l10n: context.l10n,
                  );
                  final relatedPosts = selectRelatedPosts(rawPost, allBlogs);

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
                                              label: Text(
                                                context.l10n.blogAllArticles,
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
                                        tooltip: context.l10n.blogShareTooltip,
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
                                      color: AppColors.surfaceBase,
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
                                                color: AppColors.surfaceBase,
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
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              context.l10n.blogRelatedArticlesBadge,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 1.2,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              context.l10n.blogRelatedArticlesTitle,
                                              style: const TextStyle(
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
                                            label: Text(
                                              context.l10n.blogViewAllArticles,
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
                    label: context.l10n.blogLoadingArticle,
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
                  final (title, message) =
                      _resolveErrorTitleAndMessage(err, context, localeCode);
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
            color: AppColors.surfaceBase,
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

class _RelatedBlogPostCard extends ConsumerWidget {
  final BlogPost post;
  final VoidCallback onTap;

  const _RelatedBlogPostCard({
    required this.post,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final localizedPost = LocaleFormatters.localizeBlogPost(
      post,
      localeCode: locale,
      l10n: context.l10n,
    );
    final metaParts = <String>[
      if (localizedPost.publishedAt.isNotEmpty) localizedPost.publishedAt,
      if (localizedPost.readTime.isNotEmpty) localizedPost.readTime,
    ];
    final metaText = metaParts.join(' · ');

    return Semantics(
      button: true,
      label: 'Bài viết liên quan: ${localizedPost.title}',
      child: InkWell(
        key: ValueKey('related-blog-card-${localizedPost.slug}'),
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
                rawUrl: localizedPost.coverImage,
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
                        color: AppColors.surfaceBase,
                        borderRadius: AppRadii.roundedPill,
                      ),
                      child: Text(
                        localizedPost.category,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      localizedPost.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    if (localizedPost.excerpt.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        localizedPost.excerpt,
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
