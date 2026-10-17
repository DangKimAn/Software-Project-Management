import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_header_footer.dart';
import '../../../../shared/widgets/app_image.dart';
import '../../data/blog_repository.dart';

/// Port of `Source goc/frontend/src/views/pages/Blog/BlogPage.tsx`.
class BlogScreen extends ConsumerStatefulWidget {
  const BlogScreen({super.key});

  @override
  ConsumerState<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends ConsumerState<BlogScreen> {
  static const List<String> _categories = [
    'Tất cả',
    'Cẩm nang chuyến đi',
    'Kinh nghiệm đặt phòng',
    'Khám phá địa phương',
    'Mẹo lưu trú',
    'Villa gần biển',
    'Checklist đặt phòng',
  ];

  String _selectedCategory = 'Tất cả';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blogsAsync = ref.watch(blogListProvider(_selectedCategory));

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const AppTopHeader(currentPath: '/cam-nang'),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: AppColors.divider),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 36,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CẨM NANG LƯU TRÚ VŨNG TÀU',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.0,
                                color: Color(0xFF0891B2),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Kinh nghiệm lưu trú, lịch trình & bí quyết đặt Villa biển Vũng Tàu',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                                color: Color(0xFF020617),
                              ),
                            ),
                            const SizedBox(height: 18),
                            // Search + Category pills
                            TextField(
                              controller: _searchCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Tìm bài viết cẩm nang Vũng Tàu...',
                                prefixIcon: Icon(
                                  LucideIcons.search,
                                  size: 18,
                                  color: AppColors.iconMuted,
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 16),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _categories.map((cat) {
                                  final selected = _selectedCategory == cat;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: InkWell(
                                      onTap: () => setState(
                                        () => _selectedCategory = cat,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 9,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? const Color(0xFF0F172A)
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          cat,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: selected
                                                ? Colors.white
                                                : const Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                blogsAsync.when(
                  data: (posts) {
                    final query = _searchCtrl.text.trim().toLowerCase();
                    final filtered = query.isEmpty
                        ? posts
                        : posts
                            .where(
                              (p) =>
                                  p.title.toLowerCase().contains(query) ||
                                  p.excerpt.toLowerCase().contains(query),
                            )
                            .toList();

                    if (filtered.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: AppEmptyView(
                            title: 'Chưa có bài viết phù hợp',
                            description:
                                'Hãy thử chọn chuyên mục khác hoặc từ khóa khác.',
                          ),
                        ),
                      );
                    }

                    return SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final cols = constraints.maxWidth >= 900
                                    ? 3
                                    : constraints.maxWidth >= 600
                                        ? 2
                                        : 1;
                                const spacing = 20.0;
                                final cardWidth = (constraints.maxWidth -
                                        spacing * (cols - 1)) /
                                    cols;
                                return Wrap(
                                  spacing: spacing,
                                  runSpacing: spacing,
                                  children: filtered.map((post) {
                                    return SizedBox(
                                      width: cardWidth,
                                      child: _BlogPostCard(
                                        post: post,
                                        onTap: () => context
                                            .push('/cam-nang/${post.slug}'),
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  loading: () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (err, _) => SliverToBoxAdapter(
                    child: AppErrorView(
                      message: err.toString(),
                      onRetry: () =>
                          ref.invalidate(blogListProvider(_selectedCategory)),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: AppFooter()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlogPostCard extends StatelessWidget {
  final BlogPost post;
  final VoidCallback onTap;

  const _BlogPostCard({
    required this.post,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 192,
              width: double.infinity,
              child: AppImage(
                url: post.coverImage,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                        ),
                        child: Text(
                          post.category,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0891B2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        post.readTime,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 54,
                    child: Text(
                      post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                        color: Color(0xFF020617),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 76,
                    child: Text(
                      post.excerpt,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.65,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.mapPin,
                        size: 14,
                        color: AppColors.iconStrong,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        post.location,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0891B2),
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
    );
  }
}
