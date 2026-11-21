import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

/// Cấu hình `BrowserHttpClientAdapter(withCredentials: true)` trên Flutter Web để trình duyệt tự động gửi và nhận cookie `HttpOnly` qua CORS an toàn.
void configurePlatformDio(Dio dio) {
  // On Flutter Web, enable credentials ('include') so the browser sends and receives
  // HttpOnly refresh cookies over CORS without JavaScript ever touching cookie values.
  dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: true);
}
