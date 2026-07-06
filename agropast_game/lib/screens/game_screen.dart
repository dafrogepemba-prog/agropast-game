import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../services/game_provider.dart';
import '../services/admob_service.dart';
import '../models/parcelle.dart';
import '../widgets/parcelle_widget.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final AdMobService _adMob = AdMobService();
  bool _adLoaded = false;

  @override
  void initState() {
    super.initState();
    _adMob.loadRewardedAd(onLoaded: () {
      if (mounted) setState(() => _adLoaded = true);
    });
  }

  @override
  void dispose() {
    _adMob.dispose();
    super.dispose();
  }

  // ── Menu principal (quitter / déconnexion) ──────────────
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2d4a1e),
        title: const Text('Menu', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Que veux-tu faire ?',
          style: TextStyle(color: Colors.white70),
        ),
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

  // ── Retour au site vitrine ───────────────────────────────
  void _navigateToSite() {
    try {
      html.window.location.href = '/';
    } catch (_) {}
  }

  // ── Déconnexion compte (efface localStorage) ────────────
  void _logout() {
    try {
      html.window.localStorage.remove('apg_token');
      html.window.localStorage.remove('apg_whatsapp');
      html.window.localStorage.remove('apg_nom');
      html.window.localStorage.remove('apg_ref_id');
      html.window.location.href = '/login.html';
    } catch (_) {}
  }

  // ── Publicité récompensée AdMob ─────────────────────────
  void _showAd(BuildContext context) {
    if (!_adMob.isLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pub en chargement, réessaie dans quelques secondes.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    _adMob.showRewardedAd(
      // SEUL callback qui déclenche la récompense — règle AdMob stricte
      onUserEarnedReward: (amount, type) {
        context.read<GameProvider>().appliquerBonusAdMob(amount, type);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎁 +$amount pièces & +${amount * 10} pts gagnés !'),
            backgroundColor: const Color(0xFF2e7d32),
            duration: const Duration(seconds: 3),
          ),
        );
      },
      // Pub fermée avant la fin → PAS de récompense (comportement AdMob)
      onAdDismissedWithoutReward: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Regarde la pub jusqu\'à la fin pour gagner les points.'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      onAdFailedToShow: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pub non disponible pour l\'instant.')),
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
            const Text('🍉 ', style: TextStyle(fontSize: 20)),
            const Text('Ma Ferme',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            // Score du joueur
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2e7d32),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${gp.player.scoreTotal} pts',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            // Bouton menu / déconnexion
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
                child: const Text('☰ Menu',
                    style: TextStyle(fontSize: 12, color: Colors.white70)),
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
              // Infos joueur
              _PlayerBar(player: gp.player),
              const SizedBox(height: 16),

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
                              fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : const SizedBox(height: 40),
              ),
              const SizedBox(height: 16),

              // Grille des parcelles (2 × 3)
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

              const SizedBox(height: 16),

              // Boutons bas de page
              Row(
                children: [
                  // Pub récompensée
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _adMob.isLoaded
                            ? const Color(0xFFf9a825)
                            : Colors.grey,
                        side: BorderSide(
                            color: _adMob.isLoaded
                                ? const Color(0xFFf9a825)
                                : Colors.grey),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed:
                          _adMob.isLoaded ? () => _showAd(context) : null,
                      icon: const Text('🎬',
                          style: TextStyle(fontSize: 18)),
                      label: Text(
                        _adMob.isLoaded
                            ? 'Booster\n+50 🪙 +500 pts'
                            : 'Chargement…',
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
                      icon: const Text('🌾',
                          style: TextStyle(fontSize: 18)),
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

class _PlayerBar extends StatelessWidget {
  final player;
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
          _Stat('👤', player.pseudo),
          _Stat('⭐', 'Niv. ${player.niveau}'),
          _Stat('🌾', '${player.nombreRecoltes} récoltes'),
          _Stat('🪙', '${player.piecesOr}'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String icon, value;
  const _Stat(this.icon, this.value);
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 11)),
        ],
      );
}
