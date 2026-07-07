// Stub Android/iOS — dart:html et dart:js indisponibles sur mobile
class WebBridge {
  static String getLocalStorage(String key) => '';
  static void setLocalStorage(String key, String value) {}
  static void removeLocalStorage(String key) {}
  static void navigateTo(String url) {}

  // Partage via URL externe (WhatsApp, etc.)
  static void share(String url) {}

  // Sur mobile, AdMob natif est utilisé — cette méthode n'est jamais appelée
  static void showH5RewardedAd({
    required void Function(int amount, String type) onGranted,
    required void Function(String reason) onNotGranted,
  }) {
    onNotGranted('mobile_platform');
  }
}
