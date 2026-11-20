import 'bootstrap.dart';

/// Điểm khởi chạy mặc định của ứng dụng The Palm Villa.
///
/// Giải thuật phân giải môi trường khởi chạy:
/// Ủy quyền toàn bộ quy trình khởi tạo cho `bootstrap` mà không ép cứng tên môi trường,
/// cho phép `AppConfig.resolveExpectedEnvironment` tự động đối chiếu `appFlavor`
/// và chế độ biên dịch (`kReleaseMode` mặc định `prod`, Debug/Profile mặc định `dev`).
void main() {
  bootstrap();
}
