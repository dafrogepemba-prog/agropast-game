import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../services/game_provider.dart';
import '../services/web_bridge.dart';
import '../models/player.dart';
import 'game_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _referralCount = 0; // nombre de filleuls

  @override
  void initState() {
    super.initState();
    _loadReferralCount();
  }

  // ── Charger le nombre de filleuls depuis l'API ───────────
  Future<void> _loadReferralCount() async {
    final refId = WebBridge.getLocalStorage('apg_ref_id');
    if (refId.isEmpty) return;
    try {
      final res = await http
          .get(Uri.parse(
              'https://agropast-game.online/api/referral_stats.php?ref_id=$refId'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _referralCount = (data['filleuls'] as num?)?.toInt() ?? 0;
          });
        }
      }
    } catch (_) {} // silencieux — pas bloquant
  }

  // ── Partager via WhatsApp ────────────────────────────────
  void _inviterAmi() {
    final refId = WebBridge.getLocalStorage('apg_ref_id');
    final link = 'https://agropast-game.online?ref=$refId';
    final message = Uri.encodeComponent(
        '🍉 Rejoins-moi sur AgroPast-Game ! '
        'Cultive ta ferme et gagne des FCFA. '
        'Inscris-toi ici : $link');
    WebBridge.share('https://wa.me/?text=$message');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Détecter montée de niveau après retour du jeu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gp = context.read<GameProvider>();
      if (gp.levelUpEvent != null) {
        _showLevelUpDialog(gp.levelUpEvent!);
        gp.clearLevelUpEvent();
      }
    });
  }

  // ── Dialog montée de niveau ───────────────────────────────
  void _showLevelUpDialog(NiveauInfo info) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1b2a1b),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(info.emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            const Text('Niveau supérieur !',
                style: TextStyle(
                    color: Color(0xFFf9a825),
                    fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(info.nom,
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 16),
            if (info.bonusPiecesOr > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFf9a825).withOpacity(.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFf9a825).withOpacity(.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.monetization_on,
                        color: Color(0xFFf9a825), size: 20),
                    const SizedBox(width: 8),
                    Text('+${info.bonusPiecesOr} pièces d\'or !',
                        style: const TextStyle(
                            color: Color(0xFFf9a825),
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Text('Culture débloquée : ${info.culture}',
                style: const TextStyle(
                    color: Color(0xFF4caf50), fontSize: 13)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2e7d32),
                minimumSize: const Size.fromHeight(44)),
            onPressed: () => Navigator.pop(context),
            child: const Text('Super ! Continuer'),
          ),
        ],
      ),
    );
  }

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
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            content: score < seuil
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      'Il te faut $seuil pts minimum\n'
                      'pour retirer $montant FCFA.\n\n'
                      'Ton score : $score pts\n'
                      'Il te manque : ${seuil - score} pts',
                      style: const TextStyle(
                          color: Colors.white70, height: 1.6),
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
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
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
                  onPressed: loading
                      ? null
                      : () async {
                          final tel = telCtrl.text.trim();
                          if (tel.length < 8) return;
                          setS(() => loading = true);
                          try {
                            final token =
                                WebBridge.getLocalStorage('apg_token');
                            final res = await http
                                .post(
                                  Uri.parse('https://agropast-game.online/api/withdraw.php'),
                                  headers: {'Content-Type': 'application/json'},
                                  body: jsonEncode(
                                      {'token': token, 'telephone': tel}),
                                )
                                .timeout(const Duration(seconds: 10));
                            final data = jsonDecode(res.body);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text(data['message'] ??
                                    data['error'] ??
                                    'Erreur'),
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
                                const SnackBar(
                                    content: Text('Erreur réseau.')),
                              );
                            }
                          }
                        },
                  child: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Text('Envoyer la demande',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold)),
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
    final gp     = context.watch<GameProvider>();
    final player = gp.player;
    final info   = player.niveauInfo;

    return Scaffold(
      backgroundColor: const Color(0xFF1b2a1b),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── En-tête joueur ──────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bonjour, ${player.pseudo} ${info.emoji}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold)),
                        Text('${info.nom} • Niv. ${player.niveau}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  // Pièces d'or
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
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Barre de progression niveau ─────────────
              if (player.niveau < kNiveaux.length) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Niv. ${player.niveau} → ${player.niveau + 1}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                    Text('${player.ptsVersProchainNiveau} pts restants',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: player.progressionNiveau,
                    backgroundColor: Colors.white12,
                    color: const Color(0xFF4caf50),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Carte stats + FCFA ───────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0d1f0d),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatBox(
                      icon: Icons.stars,
                      value: _fmt(player.scoreTotal),
                      label: 'Points',
                      color: const Color(0xFFf9a825),
                    ),
                    _StatBox(
                      icon: Icons.agriculture,
                      value: '${player.nombreRecoltes}',
                      label: 'Récoltes',
                      color: const Color(0xFF4caf50),
                    ),
                    _StatBox(
                      icon: Icons.account_balance,
                      value: player.revenusFcfaStr,
                      label: 'FCFA estimé',
                      color: const Color(0xFF29b6f6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '* 60 FCFA / 1 000 pts — estimation indicative',
                style: TextStyle(
                    color: Colors.white.withOpacity(.2), fontSize: 10),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // ── Logo ────────────────────────────────────
              const Icon(Icons.grass, color: Color(0xFF4caf50), size: 64),
              const SizedBox(height: 8),
              const Text('AgroPast-Game',
                  style: TextStyle(
                      color: Color(0xFFf9a825),
                      fontSize: 26,
                      fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center),
              const Text('Gère ta ferme. Vendange ta vigne.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                  textAlign: TextAlign.center),

              const SizedBox(height: 28),

              // ── Menu principal ───────────────────────────
              _MenuButton(
                icon: Icons.sports_esports,
                label: 'Jouer',
                subtitle: '${player.nombreRecoltes} récoltes • Culture : ${info.culture}',
                color: const Color(0xFF2e7d32),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const GameScreen())),
              ),
              const SizedBox(height: 12),

              _MenuButton(
                icon: Icons.settings,
                label: 'Mon profil',
                subtitle: 'Statistiques, parrainage, pseudo',
                color: const Color(0xFF4a148c),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const ProfileScreen())),
              ),
              const SizedBox(height: 12),

              _MenuButton(
                icon: Icons.emoji_events,
                label: 'Classement',
                subtitle: 'Voir les meilleurs fermiers',
                color: const Color(0xFF1565c0),
                badge: _referralCount > 0
                    ? '$_referralCount filleul${_referralCount > 1 ? 's' : ''}'
                    : null,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const LeaderboardScreen())),
              ),
              const SizedBox(height: 12),

              _MenuButton(
                icon: Icons.share,
                label: 'Inviter un ami',
                subtitle: 'Partage ton lien sur WhatsApp',
                color: const Color(0xFF00695c),
                onTap: _inviterAmi,
              ),
              const SizedBox(height: 12),

              _MenuButton(
                icon: Icons.account_balance_wallet,
                label: 'Retirer mes gains',
                subtitle:
                    '${player.revenusFcfaStr} estimé • Min. 2 000 FCFA',
                color: const Color(0xFF827717),
                badge: player.scoreTotal >= 33334 ? '✓ Éligible' : null,
                onTap: _showWithdrawDialog,
              ),

              const SizedBox(height: 20),
              const Text('v1.0.0 • Gratuit • Financé par la pub',
                  style: TextStyle(color: Colors.white24, fontSize: 11),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

// ── Widgets ────────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _StatBox(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style:
                  const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      );
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final Color color;
  final VoidCallback onTap;
  final String? badge;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badge,
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(label,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold)),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4caf50),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(badge!,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white54, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
