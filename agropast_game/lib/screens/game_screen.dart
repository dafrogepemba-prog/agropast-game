import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_provider.dart';
import '../services/admob_service.dart';
import '../models/parcelle.dart';
import '../widgets/parcelle_widget.dart';
import '../services/web_bridge.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final AdMobService _adMob = AdMobService();

  @override
  void initState() {
    super.initState();
    _adMob.loadRewardedAd(onLoaded: () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _adMob.dispose();
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

  // ── Pub AdMob (mobile uniquement) ───────────────────────
  void _showAd(BuildContext context) {
    if (!_adMob.isLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pub en chargement, reessaie.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    _adMob.showRewardedAd(
      onUserEarnedReward: (amount, type) {
        context.read<GameProvider>().appliquerBonusAdMob(amount, type);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('+$amount pieces & +${amount * 10} pts !'),
            backgroundColor: const Color(0xFF2e7d32),
            duration: const Duration(seconds: 3),
          ),
        );
      },
      onAdDismissedWithoutReward: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Regarde la pub jusqu\'a la fin.'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      onAdFailedToShow: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pub non disponible.')),
        );
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
        child: Padding(
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
                        child: Text(gp.message,
                            style: const TextStyle(
                                color: Color(0xFFf9a825),
                                fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center),
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
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFf9a825),
                        side:
                            const BorderSide(color: Color(0xFFf9a825)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _adMob.isLoaded
                          ? () => _showAd(context)
                          : () => _showWebBonus(context),
                      icon: const Icon(Icons.play_circle_outline,
                          color: Color(0xFFf9a825), size: 20),
                      label: Text(
                        _adMob.isLoaded
                            ? 'Booster\n+50 pièces +500 pts'
                            : 'Bonus\n+5 pièces +50 pts',
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
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: gp.saisonTerminee
                          ? () => gp.nouvelleSaison()
                          : null,
                      icon: const Icon(Icons.agriculture,
                          color: Colors.white, size: 20),
                      label: const Text('Nouvelle\nsaison',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
          _Stat(Icons.person, player.pseudo),
          _Stat(Icons.star, 'Niv. ${player.niveau}'),
          _Stat(Icons.agriculture, '${player.nombreRecoltes} rec.'),
          _Stat(Icons.monetization_on, '${player.piecesOr}'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  const _Stat(this.icon, this.value);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, color: const Color(0xFF4caf50), size: 18),
          const SizedBox(height: 2),
          Text(value,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      );
}
