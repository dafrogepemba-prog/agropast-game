// Implémentation Android/iOS — dart:html et dart:js indisponibles sur
// mobile, donc on émule le "localStorage" avec SharedPreferences.
//
// IMPORTANT : les getters sont synchrones (comme sur web) pour garder
// la même API partout dans l'app. SharedPreferences est asynchrone,
// donc on charge une instance une seule fois au démarrage (WebBridge.init(),
// appelé depuis main()) et on la garde en cache pour le reste de la session.
import 'package:shared_preferences/shared_preferences.dart';

class WebBridge {
  static SharedPreferences? _prefs;

  /// À appeler une fois, avant runApp(), pour précharger le cache local.
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static String getLocalStorage(String key) {
    return _prefs?.getString(key) ?? '';
  }

  static void setLocalStorage(String key, String value) {
    _prefs?.setString(key, value);
  }

  static void removeLocalStorage(String key) {
    _prefs?.remove(key);
  }

  static void navigateTo(String url) {}

  // Partage via URL externe (WhatsApp, etc.) — pas utilisé pour la
  // connexion sur mobile (voir LoginScreen), seulement pour le partage
  // de lien de parrainage. Implémentation via url_launcher si besoin.
  static void share(String url) {}

  // Sur mobile, AdMob natif est utilisé — cette méthode n'est jamais appelée
  static void showH5RewardedAd({
    required void Function(int amount, String type) onGranted,
    required void Function(String reason) onNotGranted,
  }) {
    onNotGranted('mobile_platform');
  }
}
