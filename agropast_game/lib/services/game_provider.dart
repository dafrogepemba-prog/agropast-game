import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/parcelle.dart';
import '../models/player.dart';
import 'api_service.dart';
import 'web_bridge.dart';

class GameProvider extends ChangeNotifier {
  List<Parcelle> parcelles = List.generate(6, (i) => Parcelle(id: i));

  Player player  = Player();
  bool  _loading = true;
  String message = '';
  String _webToken = '';
  NiveauInfo? _levelUpEvent; // non-null = montée de niveau à afficher

  bool get loading => _loading;
  NiveauInfo? get levelUpEvent => _levelUpEvent;
  void clearLevelUpEvent() { _levelUpEvent = null; }

  // ── Init : charge joueur + état des parcelles ────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Nom depuis localStorage web (login.html) ou SharedPreferences
    String pseudo = prefs.getString('pseudo') ?? 'Fermier';
    String email  = prefs.getString('email')  ?? '';
    try {
      final webNom   = WebBridge.getLocalStorage('apg_nom');
      final webWa    = WebBridge.getLocalStorage('apg_whatsapp');
      final webToken = WebBridge.getLocalStorage('apg_token');
      if (webNom.isNotEmpty)   pseudo    = webNom;
      if (webWa.isNotEmpty)    email     = webWa;
      if (webToken.isNotEmpty) _webToken = webToken;
    } catch (_) {}

    player = Player(
      pseudo:          pseudo,
      email:           email,
      scoreTotal:      prefs.getInt('scoreTotal')     ?? 0,
      nombreRecoltes:  prefs.getInt('nombreRecoltes') ?? 0,
      niveau:          prefs.getInt('niveau')         ?? 1,
      piecesOr:        prefs.getInt('piecesOr')       ?? 100,
      niveauxAtteints: (jsonDecode(prefs.getString('niveauxAtteints') ?? '[1]') as List)
                           .map((e) => e as int).toList(),
    );

    // ── Restaurer l'état des parcelles ───────────────────
    final parcellesJson = prefs.getString('parcelles_state');
    if (parcellesJson != null) {
      try {
        final List<dynamic> list = jsonDecode(parcellesJson);
        parcelles = List.generate(6, (i) {
          if (i < list.length) {
            return Parcelle.fromMap(Map<String, dynamic>.from(list[i]));
          }
          return Parcelle(id: i);
        });
      } catch (_) {
        parcelles = List.generate(6, (i) => Parcelle(id: i));
      }
    }

    _loading = false;
    notifyListeners();
  }

  // ── Sauvegarde locale ─────────────────────────────────────
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('pseudo',         player.pseudo);
    prefs.setString('email',          player.email);
    prefs.setInt('scoreTotal',        player.scoreTotal);
    prefs.setInt('nombreRecoltes',    player.nombreRecoltes);
    prefs.setInt('niveau',            player.niveau);
    prefs.setInt('piecesOr',          player.piecesOr);
    prefs.setString('niveauxAtteints', jsonEncode(player.niveauxAtteints));
    // Sauvegarder l'état des parcelles
    prefs.setString('parcelles_state',
        jsonEncode(parcelles.map((p) => p.toMap()).toList()));
  }

  // ---- Interaction parcelle ----------------------------------
  void interagir(int index) {
    final p = parcelles[index];
    if (p.etat == ParcelleEtat.recoltee) return;

    final wasVide = p.estVide;
    final wasMure = p.estMure;

    p.interagir();

    if (wasVide) {
      message = '🌱 Graine plantée sur la parcelle ${index + 1} !';
      _save(); // sauvegarder l'état de la parcelle
    } else if (wasMure) {
      final montee = player.ajouterScore(p.score);
      message = '🍉 Récolte ! +${p.score} pts';
      _save();
      _syncScore(eventType: 'recolte');
      if (montee != null) _levelUpEvent = montee;
    } else if (p.etat == ParcelleEtat.mure) {
      message = '🍉 Pastèque mûre ! Clique pour récolter.';
    } else {
      message = '💧 Arrosage ${_waterLabel(p.etat)}';
      _save(); // sauvegarder état arrosage
    }

    notifyListeners();
  }

  // ---- Bonus AdMob -------------------------------------------
  // Appelé UNIQUEMENT depuis onUserEarnedReward (callback officiel AdMob)
  // Règle stricte : pas de récompense si la pub est fermée avant la fin
  void appliquerBonusAdMob(int amount, String type) {
    player.piecesOr += amount;
    final bonusScore = amount * 10;
    final montee = player.ajouterScore(bonusScore);
    message = '🎬 Pub regardée ! +$amount 🪙 & +$bonusScore pts';
    _save();
    _syncScore(eventType: 'admob_reward', bonusPoints: bonusScore);
    if (montee != null) _levelUpEvent = montee;
    notifyListeners();
  }

  // ---- Nouvelle saison ----------------------------------------
  void nouvelleSaison() {
    for (final p in parcelles) p.reset();
    message = '🌾 Nouvelle saison ! Commence à semer.';
    _save();
    _syncScore(eventType: 'saison');
    notifyListeners();
  }

  // ---- Sync API avec token JWT (fire & forget) --------------
  Future<void> _syncScore({
    required String eventType,
    int bonusPoints = 0,
  }) async {
    if (_webToken.isEmpty) return; // pas de token = pas connecté
    await ApiService.syncScore(
      token:          _webToken,
      scoreTotal:     player.scoreTotal,
      nombreRecoltes: player.nombreRecoltes,
      eventType:      eventType,
      bonusPoints:    bonusPoints,
    );
  }

  // ---- Getters -----------------------------------------------
  bool get saisonTerminee =>
      parcelles.every((p) =>
          p.etat == ParcelleEtat.recoltee || p.etat == ParcelleEtat.vide) &&
      parcelles.any((p) => p.etat == ParcelleEtat.recoltee);

  String _waterLabel(ParcelleEtat e) {
    switch (e) {
      case ParcelleEtat.arrosee1: return '1/3';
      case ParcelleEtat.arrosee2: return '2/3';
      case ParcelleEtat.arrosee3: return '3/3';
      default: return '';
    }
  }

  // ---- Setters -----------------------------------------------
  void setPseudo(String value) {
    player.pseudo = value;
    _save();
    notifyListeners();
  }

  void setEmail(String value) {
    player.email = value;
    _save();
    notifyListeners();
  }
}
