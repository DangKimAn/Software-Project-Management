/// Tầng ViewModel xuất tập trung các mô hình hiển thị và Provider truy vấn bài viết Blog theo chuẩn kiến trúc MVVM.
// CONFLICT-RESOLVED: Bổ sung tầng `blog_view_model.dart` tách các Provider bài viết Blog
// khỏi `data/blog_repository.dart` cho các màn hình `HomeScreen`, `BlogScreen`, `BlogDetailScreen`
// theo chuẩn MVVM (FLUTTER_RULES.md Mục 2).
library;

export '../../data/blog_repository.dart'
    show
        BlogBlockType,
        BlogContentBlock,
        BlogContentSanitizer,
        BlogInlineSpan,
        BlogPaginatedResult,
        BlogPagination,
        BlogPost,
        BlogQueryFilter,
        blogDetailProvider,
        blogHighlightsProvider,
        blogListProvider,
        blogPaginatedProvider;
