import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/di/providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/dio_client.dart';

/// Supported block types for safe rich blog content rendering.
enum BlogBlockType {
  heading,
  paragraph,
  bulletList,
  orderedList,
  quote,
}

/// Inline text span with safe formatting and validated link URL.
class BlogInlineSpan {
  final String text;
  final bool isBold;
  final bool isItalic;
  final String? linkUrl;

  const BlogInlineSpan({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.linkUrl,
  });
}

/// A parsed, sanitized block of blog content ready for native Flutter widget rendering.
class BlogContentBlock {
  final BlogBlockType type;
  final int headingLevel;
  final List<BlogInlineSpan> spans;
  final List<List<BlogInlineSpan>> listItems;

  const BlogContentBlock({
    required this.type,
    this.headingLevel = 2,
    this.spans = const [],
    this.listItems = const [],
  });

  String get plainText {
    if (listItems.isNotEmpty) {
      return listItems
          .map((item) => item.map((s) => s.text).join())
          .where((line) => line.trim().isNotEmpty)
          .join('\n');
    }
    return spans.map((s) => s.text).join();
  }
}

/// Pure-Dart sanitizer & rich content parser that strips XSS vectors
/// (`<script>`, `<iframe>`, `<style>`, `<svg>`, `<object>`, inline `on*=` handlers,
/// `javascript:` / `data:` URLs) and produces structured [BlogContentBlock]s.
abstract final class BlogContentSanitizer {
  static const Set<String> _allowedInternalPrefixes = {
    '/blog',
    '/cam-nang',
    '/villa',
    '/villas',
    '/tim-kiem',
    '/search',
    '/noi-luu-tru',
    '/lien-he',
    '/tro-thanh-host',
  };

  /// Decodes standard HTML entities into plain Unicode characters.
  static String decodeHtmlEntities(String input) {
    if (!input.contains('&')) return input;
    var out = input
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&ndash;', '–')
        .replaceAll('&mdash;', '—')
        .replaceAll('&bull;', '•');

    out = out.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final code = int.tryParse(match.group(1) ?? '');
      if (code != null && code >= 32 && code <= 0x10FFFF) {
        return String.fromCharCode(code);
      }
      return '';
    });

    out = out.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
      final code = int.tryParse(match.group(1) ?? '', radix: 16);
      if (code != null && code >= 32 && code <= 0x10FFFF) {
        return String.fromCharCode(code);
      }
      return '';
    });

    return out;
  }

  /// Strips dangerous container tags AND their entire inner content.
  static String stripDangerousBlocks(String input) {
    var out = input;
    const dangerousTags = [
      'script',
      'style',
      'iframe',
      'object',
      'embed',
      'svg',
      'math',
      'applet',
      'form',
      'noscript',
      'template',
    ];
    for (final tag in dangerousTags) {
      out = out.replaceAll(
        RegExp('<$tag\\b[^>]*>[\\s\\S]*?<\\/$tag>', caseSensitive: false),
        '',
      );
      out = out.replaceAll(
        RegExp('<$tag\\b[^>]*\\/?>', caseSensitive: false),
        '',
      );
    }
    // Strip standalone dangerous void/media tags such as <img onerror=...>, <input>, <meta>, <link>, <base>.
    out = out.replaceAll(
      RegExp(
        r'<\s*\/?\s*(?:img|input|button|select|textarea|meta|link|base|frame|frameset|audio|video|source)\b[^>]*>',
        caseSensitive: false,
      ),
      '',
    );
    // Strip inline event handler patterns if any malformed tag text remains.
    out = out.replaceAll(
      RegExp(
        r'''\bon[a-z]+\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)''',
        caseSensitive: false,
      ),
      '',
    );
    return out;
  }

  /// Sanitizes a single-line or multi-line string into safe plain text without HTML tags.
  static String sanitizePlainText(
    String? raw, {
    bool preserveNewlines = false,
  }) {
    if (raw == null || raw.isEmpty) return '';
    var cleaned = stripDangerousBlocks(raw);
    if (preserveNewlines) {
      cleaned = cleaned.replaceAll(
        RegExp(r'<\s*br\s*\/?>', caseSensitive: false),
        '\n',
      );
      cleaned = cleaned.replaceAll(
        RegExp(r'<\s*\/p\s*>', caseSensitive: false),
        '\n\n',
      );
    }
    cleaned = cleaned.replaceAll(RegExp(r'<[^>]*>'), ' ');
    cleaned = decodeHtmlEntities(cleaned);
    // Strip any stray dangerous scheme tokens in plain text
    cleaned = cleaned.replaceAll(
      RegExp(r'(?:javascript|vbscript|data)\s*:', caseSensitive: false),
      '',
    );
    if (preserveNewlines) {
      return cleaned
          .split('\n')
          .map(
            (line) => line
                .replaceAll(RegExp(r'[\x00-\x1F\x7F]+'), ' ')
                .replaceAll(RegExp(r'[ \t]+'), ' ')
                .trim(),
          )
          .join('\n')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();
    }
    return cleaned
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Validates and normalizes a URL from a rich content link (`<a href="...">` or `[label](url)`).
  ///
  /// Returns `null` if the URL is malformed, uses a dangerous scheme (`javascript:`, `data:`, etc.),
  /// or points to an untrusted target.
  static String? sanitizeLinkUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    final trimmed = decodeHtmlEntities(rawUrl).trim();
    if (trimmed.isEmpty) return null;
    if (RegExp(r'[\s<>"\x00-\x1F\\]').hasMatch(trimmed)) {
      return null;
    }

    final lower = trimmed.toLowerCase();
    if (lower.startsWith('javascript:') ||
        lower.startsWith('data:') ||
        lower.startsWith('vbscript:') ||
        lower.startsWith('file:') ||
        lower.startsWith('blob:') ||
        lower.startsWith('intent:') ||
        lower.startsWith('about:')) {
      return null;
    }

    // Internal application route (e.g. /villa/101, /blog/slug, /tim-kiem)
    if (trimmed.startsWith('/')) {
      if (trimmed.startsWith('//') || trimmed.contains('..')) {
        return null;
      }
      final uri = Uri.tryParse(trimmed);
      if (uri == null || uri.hasScheme || uri.hasAuthority) {
        return null;
      }
      final path = uri.path;
      if (path == '/') return '/';
      final allowed = _allowedInternalPrefixes.any(
        (prefix) => path == prefix || path.startsWith('$prefix/'),
      );
      return allowed ? trimmed : null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') return null;
    if (uri.userInfo.isNotEmpty) return null;

    final host = uri.host.toLowerCase();
    if (host.isEmpty ||
        !host.contains('.') ||
        host.startsWith('.') ||
        host.endsWith('.')) {
      return null;
    }
    return uri.toString();
  }

  /// Validates a cover image URL/asset path.
  ///
  /// Returns `''` when missing or invalid so the UI renders a stable placeholder
  /// instead of attempting a broken network call or substituting a fake villa photo.
  static String sanitizeImageUrl(String? rawUrl) {
    if (rawUrl == null) return '';
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '';
    if (RegExp(r'[<>"\x00-\x1F]').hasMatch(trimmed)) {
      return '';
    }

    final lower = trimmed.toLowerCase();
    if (lower.startsWith('javascript:') ||
        lower.startsWith('data:') ||
        lower.startsWith('vbscript:') ||
        lower.startsWith('file:') ||
        lower.startsWith('blob:')) {
      return '';
    }

    if (trimmed.startsWith('assets/images/') ||
        trimmed.startsWith('/src/assets/') ||
        trimmed.startsWith('/uploads/')) {
      if (trimmed.contains('..')) return '';
      return trimmed;
    }

    if (trimmed.contains(' ')) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return '';
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') return '';
    if (uri.host.isEmpty || !uri.host.contains('.')) return '';
    return uri.toString();
  }

  /// Normalizes and validates a blog slug from deep links or route parameters.
  static String normalizeSlug(String? rawSlug) {
    if (rawSlug == null) return '';
    var trimmed = rawSlug.trim();
    if (trimmed.isEmpty) return '';

    // Strip accidental query or fragment suffixes
    final qIdx = trimmed.indexOf('?');
    if (qIdx >= 0) trimmed = trimmed.substring(0, qIdx);
    final hIdx = trimmed.indexOf('#');
    if (hIdx >= 0) trimmed = trimmed.substring(0, hIdx);

    try {
      trimmed = Uri.decodeComponent(trimmed).trim();
    } catch (_) {
      return '';
    }

    if (trimmed.isEmpty ||
        trimmed.contains('..') ||
        trimmed.contains('/') ||
        trimmed.contains('\\') ||
        RegExp(r'[<>"\x00-\x1F\s]').hasMatch(trimmed)) {
      return '';
    }
    return trimmed;
  }

  /// Parses raw content (`List` or `String`, HTML or Markdown/plain text) into safe [BlogContentBlock]s.
  static List<BlogContentBlock> parseRichBlocks(dynamic rawContent) {
    final List<String> rawChunks = [];
    if (rawContent is List) {
      for (final item in rawContent) {
        if (item != null) {
          final s = item.toString().trim();
          if (s.isNotEmpty) rawChunks.add(s);
        }
      }
    } else if (rawContent != null) {
      final s = rawContent.toString().trim();
      if (s.isNotEmpty) rawChunks.add(s);
    }

    final List<BlogContentBlock> blocks = [];
    for (final chunk in rawChunks) {
      final cleanedChunk = stripDangerousBlocks(chunk).trim();
      if (cleanedChunk.isEmpty) continue;
      blocks.addAll(_parseSingleChunk(cleanedChunk));
    }
    return blocks;
  }

  static List<BlogContentBlock> _parseSingleChunk(String chunk) {
    final List<BlogContentBlock> result = [];

    // Normalize block HTML tags into newline-delimited markers for deterministic parsing.
    var normalized = chunk
        .replaceAll(RegExp(r'<\s*br\s*\/?>', caseSensitive: false), '\n')
        .replaceAllMapped(
          RegExp(
            r'<\s*h([1-4])\b[^>]*>([\s\S]*?)<\s*\/\s*h\1\s*>',
            caseSensitive: false,
          ),
          (m) {
            final level = int.tryParse(m.group(1) ?? '2') ?? 2;
            final prefix = level <= 2 ? '## ' : '### ';
            return '\n\n$prefix${m.group(2)?.trim() ?? ''}\n\n';
          },
        )
        .replaceAllMapped(
          RegExp(
            r'<\s*blockquote\b[^>]*>([\s\S]*?)<\s*\/\s*blockquote\s*>',
            caseSensitive: false,
          ),
          (m) => '\n\n> ${m.group(1)?.trim() ?? ''}\n\n',
        )
        .replaceAllMapped(
          RegExp(
            r'<\s*ul\b[^>]*>([\s\S]*?)<\s*\/\s*ul\s*>',
            caseSensitive: false,
          ),
          (m) {
            final items = RegExp(
              r'<\s*li\b[^>]*>([\s\S]*?)<\s*\/\s*li\s*>',
              caseSensitive: false,
            )
                .allMatches(m.group(1) ?? '')
                .map((li) => '- ${li.group(1)?.trim() ?? ''}')
                .join('\n');
            return '\n\n$items\n\n';
          },
        )
        .replaceAllMapped(
          RegExp(
            r'<\s*ol\b[^>]*>([\s\S]*?)<\s*\/\s*ol\s*>',
            caseSensitive: false,
          ),
          (m) {
            var idx = 1;
            final items = RegExp(
              r'<\s*li\b[^>]*>([\s\S]*?)<\s*\/\s*li\s*>',
              caseSensitive: false,
            )
                .allMatches(m.group(1) ?? '')
                .map((li) => '${idx++}. ${li.group(1)?.trim() ?? ''}')
                .join('\n');
            return '\n\n$items\n\n';
          },
        )
        .replaceAllMapped(
          RegExp(
            r'<\s*p\b[^>]*>([\s\S]*?)<\s*\/\s*p\s*>',
            caseSensitive: false,
          ),
          (m) => '\n\n${m.group(1)?.trim() ?? ''}\n\n',
        )
        .replaceAllMapped(
          RegExp(r'^(#{1,3})\s+(.+)$', multiLine: true),
          (m) => '\n\n${m.group(1)} ${m.group(2)?.trim() ?? ''}\n\n',
        );

    final sections = normalized
        .split(RegExp(r'\n\s*\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    for (final section in sections) {
      if (section.startsWith('### ')) {
        final spans = parseInlineSpans(section.substring(4).trim());
        if (_hasVisibleText(spans)) {
          result.add(
            BlogContentBlock(
              type: BlogBlockType.heading,
              headingLevel: 3,
              spans: spans,
            ),
          );
        }
        continue;
      }

      if (section.startsWith('## ') || section.startsWith('# ')) {
        final text = section.startsWith('## ')
            ? section.substring(3).trim()
            : section.substring(2).trim();
        final spans = parseInlineSpans(text);
        if (_hasVisibleText(spans)) {
          result.add(
            BlogContentBlock(
              type: BlogBlockType.heading,
              headingLevel: 2,
              spans: spans,
            ),
          );
        }
        continue;
      }

      if (section.startsWith('> ')) {
        final quoteText = section
            .split('\n')
            .map((l) => l.replaceFirst(RegExp(r'^>\s*'), '').trim())
            .join(' ');
        final spans = parseInlineSpans(quoteText);
        if (_hasVisibleText(spans)) {
          result.add(
            BlogContentBlock(
              type: BlogBlockType.quote,
              spans: spans,
            ),
          );
        }
        continue;
      }

      final lines = section
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      if (lines.isNotEmpty &&
          lines.every((l) => RegExp(r'^[-*•]\s+').hasMatch(l))) {
        final items = lines
            .map(
              (l) => parseInlineSpans(
                l.replaceFirst(RegExp(r'^[-*•]\s+'), '').trim(),
              ),
            )
            .where(_hasVisibleText)
            .toList();
        if (items.isNotEmpty) {
          result.add(
            BlogContentBlock(
              type: BlogBlockType.bulletList,
              listItems: items,
            ),
          );
        }
        continue;
      }

      if (lines.isNotEmpty &&
          lines.every((l) => RegExp(r'^\d+\.\s+').hasMatch(l))) {
        final items = lines
            .map(
              (l) => parseInlineSpans(
                l.replaceFirst(RegExp(r'^\d+\.\s+'), '').trim(),
              ),
            )
            .where(_hasVisibleText)
            .toList();
        if (items.isNotEmpty) {
          result.add(
            BlogContentBlock(
              type: BlogBlockType.orderedList,
              listItems: items,
            ),
          );
        }
        continue;
      }

      final spans = parseInlineSpans(lines.join(' '));
      if (_hasVisibleText(spans)) {
        result.add(
          BlogContentBlock(
            type: BlogBlockType.paragraph,
            spans: spans,
          ),
        );
      }
    }

    return result;
  }

  static bool _hasVisibleText(List<BlogInlineSpan> spans) {
    return spans.any((s) => s.text.trim().isNotEmpty);
  }

  /// Parses inline HTML (`<strong>`, `<b>`, `<em>`, `<i>`, `<a href="...">`) and Markdown
  /// (`**bold**`, `[label](url)`) into safe [BlogInlineSpan]s.
  static List<BlogInlineSpan> parseInlineSpans(String raw) {
    if (raw.trim().isEmpty) return const [];
    final stripped = stripDangerousBlocks(raw);

    final tokenPattern = RegExp(
      r'<\s*a\b[^>]*href\s*=\s*(?:"([^"]*)"|'
      r"'([^']*)'"
      r'|([^\s>]+))[^>]*>([\s\S]*?)<\s*\/\s*a\s*>|'
      r'\[([^\]]+)\]\(([^)]+)\)|'
      r'<\s*(?:strong|b)\b[^>]*>([\s\S]*?)<\s*\/\s*(?:strong|b)\s*>|'
      r'\*\*([^*]+)\*\*|'
      r'<\s*(?:em|i)\b[^>]*>([\s\S]*?)<\s*\/\s*(?:em|i)\s*>|'
      r'\*([^*]+)\*',
      caseSensitive: false,
    );

    final List<BlogInlineSpan> spans = [];
    var currentIndex = 0;

    for (final match in tokenPattern.allMatches(stripped)) {
      if (match.start > currentIndex) {
        final plain =
            sanitizePlainText(stripped.substring(currentIndex, match.start));
        if (plain.isNotEmpty) {
          spans.add(BlogInlineSpan(text: '$plain '));
        }
      }

      if (match.group(4) != null) {
        // HTML <a href="...">text</a>
        final rawHref = match.group(1) ?? match.group(2) ?? match.group(3);
        final label = sanitizePlainText(match.group(4));
        final safeUrl = sanitizeLinkUrl(rawHref);
        if (label.isNotEmpty) {
          spans.add(BlogInlineSpan(text: label, linkUrl: safeUrl));
        }
      } else if (match.group(5) != null && match.group(6) != null) {
        // Markdown [label](url)
        final label = sanitizePlainText(match.group(5));
        final safeUrl = sanitizeLinkUrl(match.group(6));
        if (label.isNotEmpty) {
          spans.add(BlogInlineSpan(text: label, linkUrl: safeUrl));
        }
      } else if (match.group(7) != null || match.group(8) != null) {
        // Bold
        final boldText = sanitizePlainText(match.group(7) ?? match.group(8));
        if (boldText.isNotEmpty) {
          spans.add(BlogInlineSpan(text: boldText, isBold: true));
        }
      } else if (match.group(9) != null || match.group(10) != null) {
        // Italic
        final italicText = sanitizePlainText(match.group(9) ?? match.group(10));
        if (italicText.isNotEmpty) {
          spans.add(BlogInlineSpan(text: italicText, isItalic: true));
        }
      }

      currentIndex = match.end;
    }

    if (currentIndex < stripped.length) {
      final tail = sanitizePlainText(stripped.substring(currentIndex));
      if (tail.isNotEmpty) {
        spans.add(BlogInlineSpan(text: tail));
      }
    }

    if (spans.isEmpty) {
      final fallback = sanitizePlainText(stripped);
      if (fallback.isNotEmpty) {
        return [BlogInlineSpan(text: fallback)];
      }
    }

    // Normalize spacing between adjacent spans
    final List<BlogInlineSpan> normalized = [];
    for (var i = 0; i < spans.length; i++) {
      final s = spans[i];
      var text = s.text.trim();
      if (text.isEmpty) continue;
      if (i < spans.length - 1) {
        final nextText = spans[i + 1].text.trim();
        if (nextText.isNotEmpty && !RegExp(r'^[,.;:!?)]').hasMatch(nextText)) {
          text = '$text ';
        }
      }
      normalized.add(
        BlogInlineSpan(
          text: text,
          isBold: s.isBold,
          isItalic: s.isItalic,
          linkUrl: s.linkUrl,
        ),
      );
    }

    return normalized;
  }

  /// Joins [blocks] back into sanitized plain text separated by double newlines.
  static String blocksToPlainText(List<BlogContentBlock> blocks) {
    return blocks
        .map((b) => b.plainText.trim())
        .where((t) => t.isNotEmpty)
        .join('\n\n');
  }
}

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
  final List<BlogContentBlock> contentBlocks;
  final String status;

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
    this.contentBlocks = const [],
    this.status = 'published',
  });

  /// Returns sanitized rich content blocks, parsing [content] on the fly if [contentBlocks] was not pre-populated.
  List<BlogContentBlock> get resolvedBlocks {
    if (contentBlocks.isNotEmpty) return contentBlocks;
    return BlogContentSanitizer.parseRichBlocks(content);
  }

  static String _sanitizeDate(dynamic rawDate) {
    if (rawDate == null) return '';
    final str = rawDate.toString().trim();
    if (str.isEmpty) return '';
    final dateOnlyMatch = RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(str);
    if (dateOnlyMatch != null) {
      return dateOnlyMatch.group(1)!;
    }
    final parsed = DateTime.tryParse(str);
    if (parsed != null) {
      final y = parsed.year.toString().padLeft(4, '0');
      final m = parsed.month.toString().padLeft(2, '0');
      final d = parsed.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }
    return BlogContentSanitizer.sanitizePlainText(str);
  }

  factory BlogPost.fromJson(Map<String, dynamic> json) {
    final id = BlogContentSanitizer.sanitizePlainText(
      (json['blogId'] ?? json['id'] ?? '').toString(),
    );
    final rawSlug = (json['slug'] ?? id).toString();
    final slug = BlogContentSanitizer.normalizeSlug(rawSlug);

    final rawContent = json['content'] ?? json['body'] ?? json['excerpt'] ?? '';
    final blocks = BlogContentSanitizer.parseRichBlocks(rawContent);
    final contentText = BlogContentSanitizer.blocksToPlainText(blocks);

    final mins = (json['readTimeMinutes'] as num?)?.toInt() ?? 5;
    final rawReadTime = BlogContentSanitizer.sanitizePlainText(
      json['readTime']?.toString(),
    );
    final readTimeStr = rawReadTime.isNotEmpty ? rawReadTime : '$mins phút đọc';

    final rawCategory = BlogContentSanitizer.sanitizePlainText(
      json['category']?.toString(),
    );
    final rawLocation = BlogContentSanitizer.sanitizePlainText(
      json['location']?.toString(),
    );
    final rawAuthor = BlogContentSanitizer.sanitizePlainText(
      (json['authorName'] ??
              (json['author'] is Map ? json['author']['fullName'] : null) ??
              '')
          .toString(),
    );

    final parsedTags = json['tags'] is List
        ? (json['tags'] as List)
            .map((e) => BlogContentSanitizer.sanitizePlainText(e?.toString()))
            .where((t) => t.isNotEmpty)
            .toList()
        : const <String>[];

    final rawStatus = BlogContentSanitizer.sanitizePlainText(
      json['status']?.toString(),
    ).toLowerCase();

    return BlogPost(
      id: id,
      slug: slug.isNotEmpty ? slug : id,
      title: BlogContentSanitizer.sanitizePlainText(json['title']?.toString()),
      excerpt: BlogContentSanitizer.sanitizePlainText(
        (json['excerpt'] ?? json['summary'] ?? '').toString(),
      ),
      content: contentText,
      coverImage: BlogContentSanitizer.sanitizeImageUrl(
        (json['coverImage'] ?? json['thumbnail'] ?? json['imageUrl'])
            ?.toString(),
      ),
      category: rawCategory.isNotEmpty ? rawCategory : 'Cẩm nang du lịch',
      location: rawLocation.isNotEmpty ? rawLocation : 'Vũng Tàu',
      readTime: readTimeStr,
      authorName:
          rawAuthor.isNotEmpty ? rawAuthor : 'Ban biên tập Minh Thanh Villa',
      publishedAt: _sanitizeDate(json['publishedAt'] ?? json['createdAt']),
      readTimeMinutes: mins,
      tags: parsedTags,
      contentBlocks: blocks,
      status: rawStatus.isNotEmpty ? rawStatus : 'published',
    );
  }
}

/// Pagination metadata returned by `GET /api/blogs`.
class BlogPagination {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  const BlogPagination({
    this.page = 1,
    this.limit = 12,
    this.total = 0,
    this.totalPages = 1,
  });

  bool get hasPreviousPage => page > 1;
  bool get hasNextPage => page < totalPages;

  factory BlogPagination.fromJson(
    Map<String, dynamic>? json, {
    required int fallbackPage,
    required int fallbackLimit,
    required int itemCount,
  }) {
    if (json == null) {
      return BlogPagination(
        page: fallbackPage,
        limit: fallbackLimit,
        total: itemCount,
        totalPages: 1,
      );
    }
    final page = ((json['page'] as num?)?.toInt() ?? fallbackPage).clamp(
      1,
      10000,
    );
    final limit = ((json['limit'] as num?)?.toInt() ?? fallbackLimit).clamp(
      1,
      50,
    );
    final total = ((json['total'] as num?)?.toInt() ?? itemCount).clamp(
      0,
      1000000,
    );
    final computedPages = limit > 0 ? ((total + limit - 1) ~/ limit) : 1;
    final totalPages =
        ((json['totalPages'] as num?)?.toInt() ?? computedPages).clamp(
      1,
      10000,
    );
    return BlogPagination(
      page: page,
      limit: limit,
      total: total,
      totalPages: totalPages,
    );
  }
}

/// Paginated response wrapper for `GET /api/blogs`.
class BlogPaginatedResult {
  final List<BlogPost> items;
  final BlogPagination pagination;

  const BlogPaginatedResult({
    required this.items,
    required this.pagination,
  });
}

/// Filter key for [blogPaginatedProvider].
class BlogQueryFilter {
  final String? category;
  final String? query;
  final int page;
  final int limit;

  const BlogQueryFilter({
    this.category,
    this.query,
    this.page = 1,
    this.limit = 12,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is BlogQueryFilter &&
            other.category == category &&
            other.query == query &&
            other.page == page &&
            other.limit == limit);
  }

  @override
  int get hashCode => Object.hash(category, query, page, limit);
}

class BlogRepository {
  final DioClient _client;

  const BlogRepository(this._client);

  /// Fetches paginated blogs from `GET /api/blogs`.
  ///
  /// Strictly uses real backend data without fabricating posts.
  Future<BlogPaginatedResult> getBlogsPaginated({
    String? category,
    String? query,
    int page = 1,
    int limit = 12,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final safeLimit = limit.clamp(1, 50);
    final cleanCategory = category?.trim();
    final cleanQuery = query?.trim();

    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/api/blogs',
        queryParameters: {
          if (cleanCategory != null &&
              cleanCategory.isNotEmpty &&
              cleanCategory != 'Tất cả')
            'category': cleanCategory,
          if (cleanQuery != null && cleanQuery.isNotEmpty)
            'q': cleanQuery.length > 255
                ? cleanQuery.substring(0, 255)
                : cleanQuery,
          'page': safePage,
          'limit': safeLimit,
        },
      );
      final data = DioClient.unwrapEnvelope(response.data);
      List<dynamic> list = [];
      Map<String, dynamic>? paginationJson;

      if (data is List) {
        list = data;
      } else if (data is Map<String, dynamic>) {
        if (data['items'] is List) {
          list = data['items'] as List<dynamic>;
        }
        if (data['pagination'] is Map) {
          paginationJson = Map<String, dynamic>.from(
            data['pagination'] as Map,
          );
        }
      }

      final parsed = list
          .whereType<Map<String, dynamic>>()
          .map(BlogPost.fromJson)
          .where(
            (post) =>
                post.title.isNotEmpty &&
                post.slug.isNotEmpty &&
                (post.status.isEmpty || post.status == 'published'),
          )
          .toList();

      final pagination = BlogPagination.fromJson(
        paginationJson,
        fallbackPage: safePage,
        fallbackLimit: safeLimit,
        itemCount: parsed.length,
      );

      return BlogPaginatedResult(
        items: parsed,
        pagination: pagination,
      );
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  /// Backward-compatible helper returning the list of [BlogPost]s for [category], [query], [page], [limit].
  Future<List<BlogPost>> getBlogs({
    String? category,
    String? query,
    int page = 1,
    int limit = 12,
  }) async {
    final paginated = await getBlogsPaginated(
      category: category,
      query: query,
      page: page,
      limit: limit,
    );
    return paginated.items;
  }

  /// Fetches a single published blog article by its [slug] via `GET /api/blogs/:slug`.
  ///
  /// Returns `null` if [slug] is invalid/malformed or if the server responds with `404 Not Found`.
  /// Rethrows network/server failures so the UI can display accurate offline/server error states.
  Future<BlogPost?> getBlogBySlug(String slug) async {
    final cleanSlug = BlogContentSanitizer.normalizeSlug(slug);
    if (cleanSlug.isEmpty) {
      return null;
    }

    try {
      final encodedSlug = Uri.encodeComponent(cleanSlug);
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/api/blogs/$encodedSlug',
      );
      final data = DioClient.unwrapEnvelope(response.data);
      if (data is Map<String, dynamic> && data.isNotEmpty) {
        final post = BlogPost.fromJson(data);
        if (post.status.isNotEmpty && post.status != 'published') {
          return null;
        }
        return post;
      }
      return null;
    } catch (e) {
      final failure = DioClient.handleError(e);
      if (failure is NotFoundFailure) {
        return null;
      }
      throw failure;
    }
  }
}

final blogRepositoryProvider = Provider<BlogRepository>((ref) {
  final client = ref.watch(dioClientProvider);
  return BlogRepository(client);
});

final blogPaginatedProvider =
    FutureProvider.autoDispose.family<BlogPaginatedResult, BlogQueryFilter>((
  ref,
  filter,
) {
  return ref.watch(blogRepositoryProvider).getBlogsPaginated(
        category: filter.category,
        query: filter.query,
        page: filter.page,
        limit: filter.limit,
      );
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
