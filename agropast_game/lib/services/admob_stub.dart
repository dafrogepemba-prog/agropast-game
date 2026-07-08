// Stub web — simulation 2 secondes
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
    // Simulation : vidéo de 2s puis récompense
    Future.delayed(const Duration(seconds: 2), () => onEarned(50, 'pieces_or'));
  }

  static void dispose() {}
}
