import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../models/parcelle.dart';
import '../models/player.dart';
import 'api_service.dart';

class GameProvider extends ChangeNotifier {
  final List<Parcelle> parcelles = List.generate(6, (i) => Parcelle(id: i));

  Player player  = Player();
  bool  _loading = true;
  String message = '';
  String _webToken = ''; // token JWT depuis localStorage

  bool get loading => _loading;

  // ---- Init depuis SharedPreferences + localStorage web ------
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    String pseudo = prefs.getString('pseudo') ?? 'Fermier';
    String email  = prefs.getString('email')  ?? '';

    // Lire les données web depuis localStorage (posé par login.html)
    try {
      final webNom   = html.window.localStorage['apg_nom']      ?? '';
      final webWa    = html.window.localStorage['apg_whatsapp'] ?? '';
      final webToken = html.window.localStorage['apg_token']    ?? '';
      if (webNom.isNotEmpty)   pseudo     = webNom;
      if (webWa.isNotEmpty)    email      = webWa;
      if (webToken.isNotEmpty) _webToken  = webToken;
    } catch (_) {}

    player = Player(
      pseudo:         pseudo,
      email:          email,
      scoreTotal:     prefs.getInt('scoreTotal')        ?? 0,
      nombreRecoltes: prefs.getInt('nombreRecoltes')    ?? 0,
      niveau:         prefs.getInt('niveau')            ?? 1,
      piecesOr:       prefs.getInt('piecesOr')          ?? 100,
    );
    _loading = false;
    notifyListeners();
  }

  // ---- Sauvegarde locale -------------------------------------
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('pseudo',         player.pseudo);
    prefs.setString('email',          player.email);
    prefs.setInt('scoreTotal',        player.scoreTotal);
    prefs.setInt('nombreRecoltes',    player.nombreRecoltes);
    prefs.setInt('niveau',            player.niveau);
    prefs.setInt('piecesOr',          player.piecesOr);
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
    } else if (wasMure) {
      player.ajouterScore(p.score);
      message = '🍉 Récolte ! +${p.score} pts';
      _save();
      _syncScore(eventType: 'recolte');
    } else if (p.etat == ParcelleEtat.mure) {
      message = '🍉 Pastèque mûre ! Clique pour récolter.';
    } else {
      message = '💧 Arrosage ${_waterLabel(p.etat)}';
    }

    notifyListeners();
  }

  // ---- Bonus AdMob -------------------------------------------
  // Appelé UNIQUEMENT depuis onUserEarnedReward (callback officiel AdMob)
  // Règle stricte : pas de récompense si la pub est fermée avant la fin
  void appliquerBonusAdMob(int amount, String type) {
    player.piecesOr += amount;
    final bonusScore = amount * 10; // 50 pièces = 500 pts bonus
    player.ajouterScore(bonusScore);
    message = '🎬 Pub regardée ! +$amount 🪙 & +$bonusScore pts';
    _save();
    _syncScore(eventType: 'admob_reward', bonusPoints: bonusScore);
    notifyListeners();
  }

  // ---- Nouvelle saison ----------------------------------------
  void nouvelleSaison() {
    for (final p in parcelles) p.reset();
    message = '🌾 Nouvelle saison ! Commence à semer.';
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
