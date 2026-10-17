export 'dio_adapter_stub.dart'
    if (dart.library.js_interop) 'dio_adapter_web.dart'
    if (dart.library.html) 'dio_adapter_web.dart';
