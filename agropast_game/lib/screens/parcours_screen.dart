// ============================================================
// parcours_screen.dart — Parcours Quotidien
// Grille 2×2 des cultures + arrosoir + particules
// ============================================================
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/culture.dart';
import '../models/player.dart';
import '../services/parcours_provider.dart';
import '../services/game_provider.dart';
import '../widgets/particules_painter.dart';

enum EtatCulture { locked, active, done }

class ParcoursQuotidienScreen extends StatefulWidget {
  const ParcoursQuotidienScreen({super.key});
  @override
  State<ParcoursQuotidienScreen> createState() =>
      _ParcoursQuotidienScreenState();
}

class _ParcoursQuotidienScreenState extends State<ParcoursQuotidienScreen>
    with TickerProviderStateMixin {

  // ── Particules ────────────────────────────────────────────
  late AnimationController _partCtrl;
  final ParticulesController _partCtrlLogic = ParticulesController();

  // ── Arrosoir rotation ─────────────────────────────────────
  late AnimationController _rotCtrl;
  late Animation<double>    _rotAnim;

  // ── +5% flottant ─────────────────────────────────────────
  late AnimationController _plusCtrl;
  late Animation<double>    _plusFade;
  Offset _tapPos = Offset.zero;

  @override
  void initState() {
    super.initState();
    _partCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))
      ..addListener(() {
        if (!_partCtrlLogic.tick()) _partCtrl.stop();
        setState(() {});
      });

    _rotCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _rotAnim = Tween<double>(begin: 0, end: 0.25).animate(
        CurvedAnimation(parent: _rotCtrl, curve: Curves.easeInOut));

    _plusCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _plusFade = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _plusCtrl, curve: Curves.easeOut));

    // Init provider
    Future.microtask(() =>
        context.read<ParcoursQuotidienProvider>().init());
  }

  @override
  void dispose() {
    _partCtrl.dispose();
    _rotCtrl.dispose();
    _plusCtrl.dispose();
    super.dispose();
  }

  // ── Tap arrosoir ─────────────────────────────────────────
  void _onTap(Offset globalPos) {
    // Haptique Android uniquement (Req. 8.1)
    if (!kIsWeb) HapticFeedback.lightImpact();

    final pq = context.read<ParcoursQuotidienProvider>();
    if (pq.sessionDone) return;

    // Particules
    final box = context.findRenderObject() as RenderBox?;
    final localPos = box?.globalToLocal(globalPos) ?? globalPos;
    _partCtrlLogic.spawn(localPos);
    if (!_partCtrl.isAnimating) _partCtrl.repeat();

    // Rotation arrosoir
    _rotCtrl.forward(from: 0);

    // +5% fade
    setState(() => _tapPos = localPos);
    _plusCtrl.forward(from: 0);

    // Logique provider
    pq.onTapArrosoir();

    // Montée de niveau ?
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ev = pq.levelUpEvent;
      if (ev != null && mounted) {
        _showLevelUpDialog(ev);
        pq.clearLevelUpEvent();
      }
    });
  }

  void _showLevelUpDialog(NiveauInfo info) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1b2a1b),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(info.emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 10),
          const Text('Niveau supérieur !',
              style: TextStyle(color: Color(0xFFf9a825),
                  fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(info.nom,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          if (info.bonusPiecesOr > 0) ...[
            const SizedBox(height: 12),
            Text('+${info.bonusPiecesOr} 🪙',
                style: const TextStyle(
                    color: Color(0xFFf9a825), fontWeight: FontWeight.bold)),
          ],
        ]),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2e7d32),
                minimumSize: const Size.fromHeight(42)),
            onPressed: () => Navigator.pop(context),
            child: const Text('Super !'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d1b0f),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0a150a),
        foregroundColor: Colors.white,
        title: const Text('Parcours Quotidien',
            style: TextStyle(fontWeight: FontWeight.bold,
                color: Color(0xFF4caf50))),
        elevation: 0,
      ),
      body: Consumer<ParcoursQuotidienProvider>(
        builder: (ctx, pq, _) {
          if (!pq.initialized) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF4caf50)));
          }
          return Stack(
            children: [
              // Particules
              Positioned.fill(
                child: CustomPaint(
                  painter: ParticulesPainter(
                    groups: _partCtrlLogic.groups,
                    repaint: _partCtrl,
                  ),
                ),
              ),

              // Contenu principal
              Column(
                children: [
                  // Bannière Web (Req. 10.3)
                  if (kIsWeb)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      color: const Color(0xFF1c3320),
                      child: const Text(
                        '💡 Sur navigateur, la progression est liée au cache. '
                        'Vide-le et tu repars de zéro.',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Grille 2×2
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.1,
                      children: List.generate(4, (i) {
                        final etat = _etatCulture(i, pq);
                        return _CultureCard(
                          culture: kCultures[i],
                          etat: etat,
                          progression: i == pq.cultureIndex
                              ? pq.progression
                              : 0.0,
                        );
                      }),
                    ),
                  ),

                  // Score session
                  if (pq.sessionScore > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Session : +${pq.sessionScore} pts',
                        style: const TextStyle(
                            color: Color(0xFFf9a825),
                            fontWeight: FontWeight.bold),
                      ),
                    ),

                  const Spacer(),

                  // Résultat session terminée
                  if (pq.sessionDone)
                    _ResultatWidget(score: pq.sessionScore)
                  else
                    // Arrosoir
                    Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: _ArrosoirButton(
                        rotAnim: _rotAnim,
                        onTap: _onTap,
                        culture: pq.cultureCourante,
                        progression: pq.progression,
                      ),
                    ),
                ],
              ),

              // +5% flottant
              if (_plusCtrl.isAnimating)
                Positioned(
                  left: _tapPos.dx - 20,
                  top:  _tapPos.dy - 40,
                  child: FadeTransition(
                    opacity: _plusFade,
                    child: const Text('+5%',
                        style: TextStyle(
                            color: Color(0xFF4caf50),
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  EtatCulture _etatCulture(int i, ParcoursQuotidienProvider pq) {
    if (pq.sessionDone || i < pq.cultureIndex) return EtatCulture.done;
    if (i == pq.cultureIndex) return EtatCulture.active;
    return EtatCulture.locked;
  }
}

// ── Carte de culture ────────────────────────────────────────
class _CultureCard extends StatelessWidget {
  final Culture culture;
  final EtatCulture etat;
  final double progression;

  const _CultureCard({
    required this.culture,
    required this.etat,
    required this.progression,
  });

  @override
  Widget build(BuildContext context) {
    final isLocked = etat == EtatCulture.locked;
    final isDone   = etat == EtatCulture.done;

    return LayoutBuilder(builder: (ctx, constraints) {
      return AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isLocked ? 0.45 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1c3320),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDone
                  ? const Color(0xFF2e7d32)
                  : etat == EtatCulture.active
                      ? const Color(0xFF4caf50)
                      : Colors.white12,
              width: etat == EtatCulture.active ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              // Contenu principal
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icône ou cadenas
                    isLocked
                        ? const Icon(Icons.lock_outline,
                            color: Colors.white38, size: 32)
                        : Text(culture.emoji,
                            style: const TextStyle(fontSize: 32)),
                    const SizedBox(height: 6),
                    Text(culture.label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    const SizedBox(height: 4),
                    // Statut
                    Text(
                      isDone
                          ? 'Récoltée'
                          : isLocked
                              ? 'Verrouillée'
                              : '${progression.toInt()}%',
                      style: TextStyle(
                          color: isDone
                              ? const Color(0xFF4caf50)
                              : Colors.white54,
                          fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    // Barre de progression (active uniquement)
                    if (etat == EtatCulture.active)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (progression / 100).clamp(0.0, 1.0),
                          backgroundColor: Colors.white12,
                          color: const Color(0xFF4caf50),
                          minHeight: 6,
                        ),
                      ),
                  ],
                ),
              ),
              // Badge ✅
              if (isDone)
                Positioned(
                  top: 6, right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2e7d32),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check,
                        color: Colors.white, size: 12),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

// ── Bouton arrosoir ─────────────────────────────────────────
class _ArrosoirButton extends StatelessWidget {
  final Animation<double> rotAnim;
  final void Function(Offset) onTap;
  final Culture culture;
  final double progression;

  const _ArrosoirButton({
    required this.rotAnim,
    required this.onTap,
    required this.culture,
    required this.progression,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Culture cible
        Text('Arrose ${culture.label} ${culture.emoji}',
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 12),
        // Barre de maturité principale
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (progression / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.white12,
              color: Color.lerp(
                const Color(0xFF4caf50),
                const Color(0xFFb9f6ca),
                progression / 100,
              ),
              minHeight: 12,
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Bouton arrosoir
        GestureDetector(
          onTapDown: (d) => onTap(d.globalPosition),
          child: RotationTransition(
            turns: rotAnim,
            child: Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1c3320),
                border: Border.all(
                    color: const Color(0xFF4caf50), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4caf50).withOpacity(.4),
                    blurRadius: 16, spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.water_drop,
                  color: Color(0xFF29b6f6), size: 44),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Tape pour arroser !',
            style: TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}

// ── Résultats ───────────────────────────────────────────────
class _ResultatWidget extends StatelessWidget {
  final int score;
  const _ResultatWidget({required this.score});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          const Text('Parcours terminé !',
              style: TextStyle(
                  color: Color(0xFFf9a825),
                  fontSize: 22,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('+$score pts gagnés aujourd\'hui',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 15)),
          const SizedBox(height: 6),
          const Text('Reviens demain pour une nouvelle session.',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2e7d32),
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14)),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.home),
            label: const Text('Retour à l\'accueil'),
          ),
        ],
      ),
    );
  }
}
