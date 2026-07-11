import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../services/game_provider.dart';
import '../services/web_bridge.dart';
import '../models/player.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Taux de conversion FCFA — 60 FCFA par 1 000 pts (même constante que player.dart)
  static const double _kFcfaParMille = kFcfaParMille;

  // Pseudo editing
  bool _editingPseudo = false;
  late TextEditingController _pseudoCtrl;

  // Pour le convertisseur FCFA interactif
  final TextEditingController _ptsCtrl = TextEditingController();
  double _fcfaConverti = 0;

  @override
  void initState() {
    super.initState();
    final player = context.read<GameProvider>().player;
    _pseudoCtrl = TextEditingController(text: player.pseudo);
  }

  @override
  void dispose() {
    _pseudoCtrl.dispose();
    _ptsCtrl.dispose();
    super.dispose();
  }

  // ── Lien de parrainage ──────────────────────────────────
  String get _refId => WebBridge.getLocalStorage('apg_ref_id');
  String get _refLink =>
      'https://agropast-game.online?ref=${_refId.isNotEmpty ? _refId : 'XXXXXX'}';

  // ── Copier lien ─────────────────────────────────────────
  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _refLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔗 Lien copié !'),
        backgroundColor: Color(0xFF2e7d32),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ── Modifier pseudo ─────────────────────────────────────
  void _savePseudo() {
    final value = _pseudoCtrl.text.trim();
    if (value.length >= 2) {
      context.read<GameProvider>().setPseudo(value);
      setState(() => _editingPseudo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Pseudo mis à jour'),
          backgroundColor: Color(0xFF2e7d32),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Déconnexion ─────────────────────────────────────────
  void _logout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1b2a1b),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Se déconnecter',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
            'Tu vas être redirigé vers la page de connexion.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFc62828)),
            onPressed: () {
              WebBridge.removeLocalStorage('apg_token');
              WebBridge.removeLocalStorage('apg_nom');
              WebBridge.removeLocalStorage('apg_whatsapp');
              WebBridge.removeLocalStorage('apg_ref_id');
              WebBridge.navigateTo('/login.html');
            },
            child: const Text('Se déconnecter',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Convertisseur FCFA ──────────────────────────────────
  void _convertPts(String val) {
    final pts = int.tryParse(val.replaceAll(' ', '')) ?? 0;
    setState(() => _fcfaConverti = (pts / 1000) * _kFcfaParMille);
  }

  @override
  Widget build(BuildContext context) {
    final gp     = context.watch<GameProvider>();
    final player = gp.player;
    final info   = player.niveauInfo;

    return Scaffold(
      backgroundColor: const Color(0xFF1b2a1b),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0d1f0d),
        title: const Text('Mon Profil',
            style: TextStyle(color: Color(0xFFf9a825),
                fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white70),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Se déconnecter',
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Avatar + pseudo ─────────────────────────
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2e7d32).withOpacity(.3),
                        border: Border.all(
                            color: const Color(0xFF2e7d32), width: 2),
                      ),
                      child: Center(
                        child: Text(info.emoji,
                            style: const TextStyle(fontSize: 40)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_editingPseudo) ...[
                      SizedBox(
                        width: 220,
                        child: TextField(
                          controller: _pseudoCtrl,
                          autofocus: true,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 18),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: 'Ton pseudo',
                            hintStyle:
                                const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: Colors.white12,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _savePseudo(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () =>
                                setState(() => _editingPseudo = false),
                            child: const Text('Annuler',
                                style: TextStyle(color: Colors.white54)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF2e7d32)),
                            onPressed: _savePseudo,
                            child: const Text('Sauvegarder'),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(player.pseudo,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _editingPseudo = true),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.edit,
                                color: Color(0xFF4caf50), size: 14),
                            SizedBox(width: 4),
                            Text('Modifier pseudo',
                                style: TextStyle(
                                    color: Color(0xFF4caf50),
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Carte stats ─────────────────────────────
              _SectionTitle(title: '📊 Statistiques'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0d1f0d),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _StatRow(
                      icon: Icons.stairs,
                      label: 'Niveau',
                      value: 'Niv. ${player.niveau} — ${info.nom}',
                      color: const Color(0xFFf9a825),
                    ),
                    const _Divider(),
                    _StatRow(
                      icon: Icons.stars,
                      label: 'Score total',
                      value: _fmt(player.scoreTotal),
                      color: const Color(0xFFf9a825),
                    ),
                    const _Divider(),
                    _StatRow(
                      icon: Icons.agriculture,
                      label: 'Récoltes',
                      value: '${player.nombreRecoltes}',
                      color: const Color(0xFF4caf50),
                    ),
                    const _Divider(),
                    _StatRow(
                      icon: null,
                      assetPath: 'assets/images/coin_f.svg',
                      label: 'Pièces d\'or',
                      value: '${player.piecesOr}',
                      color: const Color(0xFFf9a825),
                    ),
                    const _Divider(),
                    _StatRow(
                      icon: Icons.account_balance,
                      label: 'FCFA estimé',
                      value: player.revenusFcfaStr,
                      color: const Color(0xFF29b6f6),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Historique niveaux ──────────────────────
              _SectionTitle(title: '🏅 Niveaux atteints'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0d1f0d),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kNiveaux.map((n) {
                    final atteint =
                        player.niveauxAtteints.contains(n.niveau);
                    return Chip(
                      backgroundColor: atteint
                          ? const Color(0xFF2e7d32).withOpacity(.8)
                          : Colors.white12,
                      avatar: Text(n.emoji,
                          style: const TextStyle(fontSize: 14)),
                      label: Text(
                        'Niv. ${n.niveau}',
                        style: TextStyle(
                          color: atteint
                              ? Colors.white
                              : Colors.white38,
                          fontSize: 12,
                          fontWeight: atteint
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // ── Lien de parrainage ──────────────────────
              _SectionTitle(title: '🔗 Ton lien de parrainage'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0d1f0d),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF2e7d32).withOpacity(.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _refLink,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontFamily: 'monospace'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF2e7d32),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          icon: const Icon(Icons.copy, size: 14),
                          label: const Text('Copier',
                              style: TextStyle(fontSize: 12)),
                          onPressed: _copyLink,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ref ID : ${_refId.isNotEmpty ? _refId : "—"}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Convertisseur FCFA ──────────────────────
              _SectionTitle(title: '💱 Convertisseur FCFA'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0d1f0d),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _ptsCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      onChanged: _convertPts,
                      decoration: InputDecoration(
                        hintText: 'Entrer un nombre de points',
                        hintStyle:
                            const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.stars,
                            color: Color(0xFFf9a825)),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_downward,
                            color: Colors.white38, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${_fcfaConverti.toStringAsFixed(0)} FCFA',
                          style: const TextStyle(
                              color: Color(0xFF29b6f6),
                              fontSize: 24,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Taux : $_kFcfaParMille FCFA / 1 000 pts',
                      style: const TextStyle(
                          color: Colors.white30, fontSize: 10),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Conditions du programme ─────────────────
              _SectionTitle(title: '📜 Conditions du programme de récompense'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0d1f0d),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• Points gagnés en jouant et en regardant des pubs',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    SizedBox(height: 8),
                    Text('• Pubs quotidiennes : 8 pubs/jour maximum (AdMob + Unity Ads)',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    SizedBox(height: 8),
                    Text('• Taux de conversion actuel : 60 FCFA / 1 000 pts',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    SizedBox(height: 8),
                    Text('• Retrait minimum : 33 334 pts = 2 000 FCFA',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    SizedBox(height: 8),
                    Text('• Programme réservé aux joueurs de 18 ans ou plus',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Bouton Modifier pseudo (raccourci) ──────
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4caf50),
                  side: const BorderSide(color: Color(0xFF4caf50)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.edit),
                label: const Text('Modifier mon pseudo'),
                onPressed: () => setState(() {
                  _editingPseudo = true;
                }),
              ),
              const SizedBox(height: 12),

              // ── Bouton déconnexion ──────────────────────
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFc62828).withOpacity(.85),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Se déconnecter',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                onPressed: _logout,
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

// ── Widgets locaux ─────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) => Text(
        title,
        style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.bold),
      );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(color: Colors.white12, height: 16);
}

class _StatRow extends StatelessWidget {
  final IconData? icon;
  final String? assetPath;
  final String label, value;
  final Color color;
  const _StatRow({
    this.icon,
    this.assetPath,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          if (assetPath != null)
            SvgPicture.asset(assetPath!, width: 18, height: 18)
          else
            Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      );
}
