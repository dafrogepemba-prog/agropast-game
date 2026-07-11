import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../services/game_provider.dart';
import '../services/ad_mediation_service.dart';
import '../models/parcelle.dart';
import '../widgets/parcelle_widget.dart';
import '../services/web_bridge.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final AdMediationService _adService = AdMediationService();

  @override
  void initState() {
    super.initState();
    _adService.loadAds(onLoaded: () {
      if (mounted) setState(() {});
    }, onAllFailed: () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _adService.dispose();
    super.dispose();
  }

  // ── Menu ────────────────────────────────────────────────
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2d4a1e),
        title: const Text('Menu', style: TextStyle(color: Colors.white)),
        content: const Text('Que veux-tu faire ?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continuer à jouer',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2e7d32)),
            onPressed: () {
              Navigator.pop(context);
              _navigateToSite();
            },
            child: const Text('⏎ Retour au site'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFc62828)),
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: const Text('🔓 Se déconnecter'),
          ),
        ],
      ),
    );
  }

  void _navigateToSite() {
    WebBridge.navigateTo('/');
  }

  void _logout() {
    WebBridge.removeLocalStorage('apg_token');
    WebBridge.removeLocalStorage('apg_whatsapp');
    WebBridge.removeLocalStorage('apg_nom');
    WebBridge.removeLocalStorage('apg_ref_id');
    WebBridge.navigateTo('/login.html');
  }

  // ── Bonus web : Google H5 Games Ads ────────────────────
  void _showWebBonus(BuildContext context) {
    // Tenter la vraie pub H5 AdSense
    WebBridge.showH5RewardedAd(
      onGranted: (amount, type) {
        // ✅ Vidéo vue en entier — récompense accordée par Google
        context.read<GameProvider>().appliquerBonusAdMob(amount, type);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('+$amount pieces & +${amount * 10} pts !'),
            backgroundColor: const Color(0xFF2e7d32),
            duration: const Duration(seconds: 3),
          ));
        }
      },
      onNotGranted: (reason) {
        // Pub non disponible ou fermée — petit bonus de consolation
        if (reason == 'dismissed_early') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Regarde la pub jusqu\'a la fin pour gagner les points.'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          // Pas de pub dispo → bonus fixe de consolation
          context.read<GameProvider>().appliquerBonusAdMob(5, 'web_fallback');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bonus : +5 pièces & +50 pts'),
                backgroundColor: Color(0xFF546e7a),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF1b2a1b),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0d1f0d),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.grass, color: Color(0xFF4caf50), size: 22),
            const SizedBox(width: 6),
            const Text('Ma Ferme',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            // Ad counter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: gp.isAdCapReached
                    ? const Color(0xFFc62828).withOpacity(0.2)
                    : const Color(0xFF4caf50).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: gp.isAdCapReached
                      ? const Color(0xFFc62828).withOpacity(0.4)
                      : const Color(0xFF4caf50).withOpacity(0.4),
                ),
              ),
              child: Text('${gp.adsWatchedToday}/8',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: gp.isAdCapReached
                        ? const Color(0xFFc62828)
                        : const Color(0xFF4caf50),
                  )),
            ),
            const SizedBox(width: 8),
            // Score
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2e7d32),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${gp.player.scoreTotal} pts',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showLogoutDialog(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.menu, size: 14, color: Colors.white70),
                    SizedBox(width: 4),
                    Text('Menu',
                        style:
                            TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Version démo banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFf9a825),
                    const Color(0xFFffd54f),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.black87, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Version démo — récompenses limitées',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Open Play Store link
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.android, size: 16),
                    label: const Text(
                      'App Android',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _PlayerBar(player: gp.player),
                  const SizedBox(height: 12),
                  // Message action
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: gp.message.isNotEmpty
                        ? Container(
                            key: ValueKey(gp.message),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2d4a1e),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              gp.message,
                              style: const TextStyle(
                                color: Color(0xFFf9a825),
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : const SizedBox(height: 36),
                  ),
                  const SizedBox(height: 12),
                  // Grille 2×3
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: gp.parcelles.length,
                      itemBuilder: (ctx, i) => ParcelleWidget(
                        parcelle: gp.parcelles[i],
                        onTap: () => gp.interagir(i),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Bonus / pub
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: gp.isAdCapReached || !gp.isAdLoaded
                                ? Colors.white12
                                : const Color(0xFFf9a825),
                            disabledBackgroundColor: Colors.white12,
                            foregroundColor: gp.isAdCapReached || !gp.isAdLoaded
                                ? Colors.white54
                                : Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: gp.isAdCapReached || !gp.isAdLoaded
                              ? () => _showWebBonus(context)
                              : () => gp.showRewardedAd(context),
                          icon: Icon(
                            gp.isAdCapReached || !gp.isAdLoaded
                                ? Icons.card_giftcard
                                : Icons.play_circle,
                            size: 20,
                          ),
                          label: Text(
                            gp.isAdCapReached
                                ? 'Cap atteint'
                                : (gp.isAdLoaded
                                    ? 'Booster\n+50 pièces +500 pts'
                                    : 'Bonus\n+5 pièces +50 pts'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Nouvelle saison
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: gp.saisonTerminee
                                ? const Color(0xFF2e7d32)
                                : Colors.grey.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: gp.saisonTerminee ? () => gp.nouvelleSaison() : null,
                          icon: const Icon(Icons.agriculture, color: Colors.white, size: 20),
                          label: const Text(
                            'Nouvelle\nsaison',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Barre joueur ────────────────────────────────────────────
class _PlayerBar extends StatelessWidget {
  final dynamic player;
  const _PlayerBar({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0d1f0d),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatWidget.icon(Icons.person, player.pseudo),
          _StatWidget.icon(Icons.star, 'Niv. ${player.niveau}'),
          _StatWidget.icon(Icons.agriculture, '${player.nombreRecoltes} rec.'),
          _StatWidget.iconAsset('assets/images/coin_f.svg', '${player.piecesOr}'),
        ],
      ),
    );
  }
}

class _StatWidget extends StatelessWidget {
  final IconData? icon;
  final String? assetPath;
  final String value;
  const _StatWidget._(this.icon, this.assetPath, this.value);

  factory _StatWidget.icon(IconData icon, String value) => _StatWidget._(icon, null, value);
  factory _StatWidget.iconAsset(String assetPath, String value) => _StatWidget._(null, assetPath, value);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          if (assetPath != null)
            SvgPicture.asset(assetPath!, width: 18, height: 18)
          else
            Icon(icon, color: const Color(0xFF4caf50), size: 18),
          const SizedBox(height: 2),
          Text(value,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      );
}
