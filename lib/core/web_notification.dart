/// Web Notification Helper — Conditional Import Entry Point
/// ใช้ stub บน mobile, ใช้ impl บน web
export 'web_notification_stub.dart'
    if (dart.library.js_interop) 'web_notification_impl.dart';
