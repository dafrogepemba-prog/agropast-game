// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

// Implémentation web — localStorage, navigation et H5 Ads
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

  // ── Google H5 Games Ads — Rewarded Ad ───────────────────
  // Appelle window.flutterCallJs('showRewardedAd') défini dans index.html
  // onGranted : vidéo vue en entier → créditer la récompense
  // onNotGranted : pub non disponible ou fermée avant la fin
  static void showH5RewardedAd({
    required void Function(int amount, String type) onGranted,
    required void Function(String reason) onNotGranted,
  }) {
    try {
      // Enregistrer le callback Flutter accessible depuis JS
      js.context['_flutterRewardCallback'] = (int amount, String type, bool granted) {
        if (granted) {
          onGranted(amount, type);
        } else {
          onNotGranted(type); // type contient la raison ici
        }
      };

      // Déclencher la pub via le pont JS défini dans index.html
      js.context.callMethod('flutterCallJs', ['showRewardedAd', '']);
    } catch (e) {
      onNotGranted('js_error');
    }
  }
}
