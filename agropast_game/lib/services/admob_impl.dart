// admob_impl.dart — Android/iOS
// SDK google_mobile_ads sera activé après validation du build CI
// Pour l'instant simulation identique au web
// IDs de production prêts : ca-app-pub-4115564366785475/9740112422

class AdMobImpl {
  static Future<void> initialize() async {}

  static void loadRewarded({
    required String adUnitId,
    required void Function() onLoaded,
    required void Function() onFailed,
  }) {
    Future.delayed(const Duration(milliseconds: 800), onLoaded);
  }

  static void showRewarded({
    required void Function(int, String) onEarned,
    required void Function() onDismissed,
    required void Function() onFailed,
  }) {
    // Simulation : vidéo 2s → récompense
    Future.delayed(const Duration(seconds: 2), () => onEarned(50, 'pieces_or'));
  }

  static void dispose() {}
}
