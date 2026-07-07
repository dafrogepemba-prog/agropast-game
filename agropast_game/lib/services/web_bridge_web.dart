// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

// Implémentation web — accès au localStorage et navigation
class WebBridge {
  static String getLocalStorage(String key) {
    try { return html.window.localStorage[key] ?? ''; } catch (_) { return ''; }
  }

  static void setLocalStorage(String key, String value) {
    try { html.window.localStorage[key] = value; } catch (_) {}
  }

  static void removeLocalStorage(String key) {
    try { html.window.localStorage.remove(key); } catch (_) {}
  }

  static void navigateTo(String url) {
    try { html.window.location.href = url; } catch (_) {}
  }
}
