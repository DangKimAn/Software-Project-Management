/// Điểm xuất (re-export) `wishlistDetailProvider` cho tầng trình diễn của tính năng Yêu thích.
///
/// Đảm bảo các màn hình trong phân hệ chỉ phụ thuộc vào tầng ViewModel/DI thay vì
/// khai báo trực tiếp provider dữ liệu ngay trong tệp giao diện.
library;

// CONFLICT-RESOLVED: Tách `wishlistDetailProvider` khỏi `favorites_screen.dart` sang tầng DI/ViewModel
// theo chuẩn MVVM (FLUTTER_RULES.md Mục 2).
export '../../../../app/di/providers.dart' show wishlistDetailProvider;
