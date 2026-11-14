import 'bootstrap.dart';

/// Điểm khởi chạy dành riêng cho môi trường phát triển (`dev`).
///
/// Truyền tường minh `expectedEnvironment: 'dev'` vào `bootstrap` để khóa kiểm tra
/// đồng bộ giữa cờ biên dịch `--dart-define=APP_ENV=dev` và flavor gốc trên thiết bị.
void main() {
  bootstrap(expectedEnvironment: 'dev');
}
