// admob_impl.dart — Android/iOS (dart.library.io disponible)
// Utilise le vrai SDK google_mobile_ads
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobImpl {
  static RewardedAd? _ad;

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  static void loadRewarded({
    required String adUnitId,
    required void Function() onLoaded,
    required void Function() onFailed,
  }) {
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          onLoaded();
        },
        onAdFailedToLoad: (error) {
          _ad = null;
          onFailed();
        },
      ),
    );
  }

  static void showRewarded({
    required void Function(int, String) onEarned,
    required void Function() onDismissed,
    required void Function() onFailed,
  }) {
    if (_ad == null) { onFailed(); return; }
    bool rewarded = false;

    _ad!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        if (!rewarded) onDismissed();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _ad = null;
        onFailed();
      },
    );

    _ad!.show(
      onUserEarnedReward: (ad, reward) {
        // ✅ Seul callback officiel AdMob qui accorde la récompense
        rewarded = true;
        onEarned(reward.amount.toInt(), reward.type);
      },
    );
  }

  static void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}
