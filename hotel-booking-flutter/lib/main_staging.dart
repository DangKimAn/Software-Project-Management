import 'bootstrap.dart';

/// Điểm khởi chạy dành riêng cho môi trường kiểm thử tích hợp (`staging`).
///
/// Truyền tường minh `expectedEnvironment: 'staging'` vào `bootstrap` nhằm bắt buộc
/// kiểm tra tính toàn vẹn của cấu hình `APP_ENV=staging` và giao thức bảo mật HTTPS.
void main() {
  bootstrap(expectedEnvironment: 'staging');
}
