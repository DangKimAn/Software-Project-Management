// CONFLICT-RESOLVED: Tách `popularDestinationsProvider` từ `home_screen.dart` sang tầng ViewModel
// theo chuẩn MVVM (FLUTTER_RULES.md Mục 2), không để Screen gọi trực tiếp `villaRepositoryProvider`.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/di/providers.dart';
import '../../../villas/domain/entities/villa.dart';

/// Provider tải danh sách điểm đến nổi bật trên Trang chủ độc lập với bộ lọc tìm kiếm (`villaFilterProvider`).
///
/// Đảm bảo dữ liệu hiển thị ở mục Điểm đến được yêu thích trên Trang chủ luôn ổn định, không bị biến đổi
/// ngoài ý muốn khi người dùng thay đổi điều kiện lọc ở màn hình Tìm kiếm.
final popularDestinationsProvider = FutureProvider<List<Villa>>((ref) async {
  // Giải thuật truy vấn danh sách biệt thự nổi bật cố định trên Trang chủ:
  // Luôn lấy trang đầu (tối đa 36 căn mới nhất) trực tiếp từ `VillaRepository` để các điều kiện lọc
  // trên màn hình Tìm kiếm không làm thay đổi dữ liệu hiển thị tại Trang chủ.
  final repository = ref.watch(villaRepositoryProvider);
  return repository.getVillas(
    page: 1,
    limit: 36,
    sort: 'newest',
  );
});
