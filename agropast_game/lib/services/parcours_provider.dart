// ============================================================
// parcours_provider.dart — Logique Parcours Quotidien
// ============================================================
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/culture.dart';
import '../models/player.dart';
import 'game_provider.dart';

class ParcoursQuotidienProvider extends ChangeNotifier {
  final GameProvider _gameProvider;

  // ── Clés SharedPreferences ───────────────────────────────
  static const _kDate    = 'pq_last_date';
  static const _kIndex   = 'pq_culture_index';
  static const _kProg    = 'pq_progression';
  static const _kDone    = 'pq_session_done';
  static const _kScore   = 'pq_session_score';

  // ── État en mémoire ───────────────────────────────────────
  int    _cultureIndex = 0;
  double _progression  = 0.0;
  bool   _sessionDone  = false;
  int    _sessionScore = 0;
  String _lastDate     = '';
  bool   _initialized  = false;

  NiveauInfo? levelUpEvent;

  // ── Getters publics ───────────────────────────────────────
  int     get cultureIndex    => _cultureIndex;
  double  get progression     => _progression;
  bool    get sessionDone     => _sessionDone;
  int     get sessionScore    => _sessionScore;
  bool    get initialized     => _initialized;
  Culture get cultureCourante => kCultures[_cultureIndex.clamp(0, 3)];

  // Stats joueur depuis GameProvider
  int get totalScore => _gameProvider.player.scoreTotal;
  int get niveau     => _gameProvider.player.niveau;
  int get recoltes   => _gameProvider.player.nombreRecoltes;
  int get pieces     => _gameProvider.player.piecesOr;

  // Nombre de cultures terminées aujourd'hui
  int get culturesDoneCount =>
      _sessionDone ? 4 : _cultureIndex;

  ParcoursQuotidienProvider(this._gameProvider);

  // ── Init ──────────────────────────────────────────────────
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastDate     = prefs.getString(_kDate)   ?? '';
      _cultureIndex = prefs.getInt(_kIndex)     ?? 0;
      _progression  = prefs.getDouble(_kProg)   ?? 0.0;
      _sessionDone  = prefs.getBool(_kDone)     ?? false;
      _sessionScore = prefs.getInt(_kScore)     ?? 0;
    } catch (_) {
      // continuer en mémoire — Req. 2.4
    }
    _checkReset(_todayStr());
    _initialized = true;
    notifyListeners();
  }

  // ── Action principale ─────────────────────────────────────
  void onTapArrosoir() {
    if (_sessionDone) return; // Req. 4.7
    _incrementProgression();
    if (_progression >= 100.0) {
      _recolterCulture();
      _avancerCulture();
    }
    _save();
    notifyListeners();
  }

  // ── Interne ───────────────────────────────────────────────
  void _incrementProgression() {
    _progression = (_progression + 5.0).clamp(0.0, 100.0); // Req. 4.6
  }

  void _recolterCulture() {
    final score = kCultures[_cultureIndex].scoreRecolte; // Req. 9.1
    _sessionScore += score;                               // Req. 9.4
    final montee = _gameProvider.player.ajouterScore(score); // Req. 9.2
    if (montee != null) levelUpEvent = montee;            // Req. 4.5
  }

  void _avancerCulture() {
    if (_cultureIndex < 3) {
      _cultureIndex++;        // Req. 5.2
      _progression = 0.0;
    } else {
      _sessionDone = true;    // Req. 5.6
      _gameProvider.savePublic(); // Req. 9.3
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDate,  _lastDate);
      await prefs.setInt(_kIndex,    _cultureIndex);
      await prefs.setDouble(_kProg,  _progression);
      await prefs.setBool(_kDone,    _sessionDone);
      await prefs.setInt(_kScore,    _sessionScore);
    } catch (_) {} // silencieux — Req. 2.4
  }

  void _checkReset(String today) {
    if (_lastDate.isEmpty || _lastDate.compareTo(today) < 0) {
      _cultureIndex = 0;
      _progression  = 0.0;
      _sessionDone  = false;
      _sessionScore = 0;
      _lastDate     = today;
      _save();
    }
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4,'0')}-'
           '${now.month.toString().padLeft(2,'0')}-'
           '${now.day.toString().padLeft(2,'0')}';
  }

  void clearLevelUpEvent() {
    levelUpEvent = null;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
