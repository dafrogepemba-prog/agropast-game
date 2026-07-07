import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../services/game_provider.dart';
import '../services/web_bridge.dart';
import 'game_screen.dart';
import 'leaderboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  // ── Dialog retrait ────────────────────────────────────────
  void _showWithdrawDialog() {
    final gp    = context.read<GameProvider>();
    final score = gp.player.scoreTotal;
    const seuil   = 33334;
    const montant = 2000;
    final telCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          bool loading = false;
          return AlertDialog(
            backgroundColor: const Color(0xFF2d4a1e),
            title: const Text('💸 Retirer mes gains',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: score < seuil
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      'Il te faut $seuil pts minimum\n'
                      'pour retirer $montant FCFA.\n\n'
                      'Ton score : $score pts\n'
                      'Il te manque : ${seuil - score} pts',
                      style: const TextStyle(color: Colors.white70, height: 1.6),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (score / seuil).clamp(0.0, 1.0),
                        backgroundColor: Colors.white12,
                        color: const Color(0xFF4caf50),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('${(score / seuil * 100).toStringAsFixed(1)}% atteint',
                        style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ])
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text(
                      'Entre ton numéro Airtel Money\npour recevoir le paiement.',
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1b5e20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Montant :',
                              style: TextStyle(color: Colors.white70)),
                          const Text('2 000 FCFA',
                              style: TextStyle(
                                  color: Color(0xFFf9a825),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: telCtrl,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: '+242 06 XXX XX XX',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.phone,
                            color: Color(0xFF4caf50)),
                        filled: true,
                        fillColor: Colors.white12,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ]),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler',
                    style: TextStyle(color: Colors.white54)),
              ),
              if (score >= seuil)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFf9a825)),
                  onPressed: loading ? null : () async {
                    final tel = telCtrl.text.trim();
                    if (tel.length < 8) return;
                    setS(() => loading = true);
                    try {
                      String token = WebBridge.getLocalStorage('apg_token');
                      final res = await http.post(
                        Uri.parse('https://agropast-game.online/api/withdraw.php'),
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode({'token': token, 'telephone': tel}),
                      ).timeout(const Duration(seconds: 10));
                      final data = jsonDecode(res.body);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(data['message'] ?? data['error'] ?? 'Erreur'),
                          backgroundColor: data['success'] == true
                              ? const Color(0xFF2e7d32)
                              : const Color(0xFFc62828),
                          duration: const Duration(seconds: 5),
                        ));
                      }
                    } catch (_) {
                      setS(() => loading = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Erreur réseau. Réessaie.')),
                        );
                      }
                    }
                  },
                  child: loading
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Text('Envoyer la demande',
                          style: TextStyle(
                              color: Colors.black, fontWeight: FontWeight.bold)),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── Dialog pseudo ─────────────────────────────────────────
  void _showPseudoDialog() {
    final ctrl = TextEditingController(
        text: context.read<GameProvider>().player.pseudo);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2d4a1e),
        title: const Text('Mon pseudo',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Ex: AgriKing_Brazza',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF4caf50))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2e7d32)),
            onPressed: () {
              if (ctrl.text.trim().length >= 2) {
                context.read<GameProvider>().setPseudo(ctrl.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<GameProvider>().player;

    return Scaffold(
      backgroundColor: const Color(0xFF1b2a1b),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bonjour, ${player.pseudo} 👋',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        Text('Niveau ${player.niveau} • ${player.scoreTotal} pts',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 13)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFf9a825).withOpacity(.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFFf9a825).withOpacity(.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.monetization_on,
                              color: Color(0xFFf9a825), size: 16),
                          const SizedBox(width: 4),
                          Text('${player.piecesOr}',
                              style: const TextStyle(
                                  color: Color(0xFFf9a825),
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                const Icon(Icons.grass, color: Color(0xFF4caf50), size: 80),
                const SizedBox(height: 12),
                const Text('AgroPast-Game',
                    style: TextStyle(
                        color: Color(0xFFf9a825),
                        fontSize: 28,
                        fontWeight: FontWeight.w900)),
                const Text('Gère ta ferme. Vendange ta vigne.',
                    style: TextStyle(color: Colors.white60, fontSize: 13)),

                const SizedBox(height: 40),

                // Jouer
                _MenuButton(
                  icon: Icons.sports_esports,
                  label: 'Jouer',
                  subtitle: '${player.nombreRecoltes} récoltes effectuées',
                  color: const Color(0xFF2e7d32),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const GameScreen())),
                ),
                const SizedBox(height: 14),

                // Classement
                _MenuButton(
                  icon: Icons.emoji_events,
                  label: 'Classement',
                  subtitle: 'Voir les meilleurs fermiers',
                  color: const Color(0xFF1565c0),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const LeaderboardScreen())),
                ),
                const SizedBox(height: 14),

                // Mon profil
                _MenuButton(
                  icon: Icons.settings,
                  label: 'Mon profil',
                  subtitle: 'Modifier ton pseudo',
                  color: const Color(0xFF4a148c),
                  onTap: _showPseudoDialog,
                ),
                const SizedBox(height: 14),

                // Retrait
                _MenuButton(
                  icon: Icons.account_balance_wallet,
                  label: 'Retirer mes gains',
                  subtitle: 'Min. 33 334 pts = 2 000 FCFA',
                  color: const Color(0xFF827717),
                  onTap: _showWithdrawDialog,
                ),

                const SizedBox(height: 24),
                const Text('v1.0.0 • Gratuit • Financé par la pub',
                    style: TextStyle(color: Colors.white24, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white54, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
