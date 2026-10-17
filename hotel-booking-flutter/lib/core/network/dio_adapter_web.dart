import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

void configurePlatformDio(Dio dio) {
  // On Flutter Web, enable credentials ('include') so the browser sends and receives
  // HttpOnly refresh cookies over CORS without JavaScript ever touching cookie values.
  dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: true);
}
