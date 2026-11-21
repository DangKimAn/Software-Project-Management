/// Điểm xuất có điều kiện bộ điều hợp HTTP của `Dio` theo nền tảng biên dịch (Flutter Web hoặc Native IO).
library;

export 'dio_adapter_stub.dart'
    if (dart.library.js_interop) 'dio_adapter_web.dart'
    if (dart.library.html) 'dio_adapter_web.dart';
