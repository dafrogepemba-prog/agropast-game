import 'dart:convert';
import 'package:http/http.dart' as http;

// ============================================================
// API Service — Synchronisation score avec le backend LWS
// Endpoint : POST https://agropast-game.online/api/sync_score.php
// ============================================================

class ApiService {
  static const String _baseUrl = 'https://agropast-game.online/api';

  // Sync score après récompense AdMob ou récolte
  static Future<bool> syncScore({
    required String pseudo,
    required String email,   // identifiant unique du joueur
    required int    scoreTotal,
    required int    nombreRecoltes,
    required String eventType, // 'recolte' | 'admob_reward' | 'saison'
    int    bonusPoints = 0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/sync_score.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'pseudo':          pseudo,
          'email':           email,
          'score_total':     scoreTotal.toString(),
          'nombre_recoltes': nombreRecoltes.toString(),
          'event_type':      eventType,
          'bonus_points':    bonusPoints.toString(),
          'timestamp':       DateTime.now().toIso8601String(),
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      // Pas de crash si pas de réseau — le jeu continue localement
      return false;
    }
  }

  // Récupérer le leaderboard réel
  static Future<List<Map<String, dynamic>>> getLeaderboard() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/leaderboard.php'),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['leaders'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
