import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'https://agropast-game.online/api';

  // Sync score avec token JWT (authentification)
  static Future<bool> syncScore({
    required String token,
    required int    scoreTotal,
    required int    nombreRecoltes,
    required String eventType,
    int    bonusPoints = 0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/sync_score.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token':           token,
          'score_total':     scoreTotal,
          'nombre_recoltes': nombreRecoltes,
          'event_type':      eventType,
          'bonus_points':    bonusPoints,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // Récupérer le leaderboard
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
