// Export conditionnel : web_bridge_web sur web, stub sur mobile
export 'web_bridge_stub.dart'
    if (dart.library.html) 'web_bridge_web.dart';
