import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ad_mediation_service.dart';

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

  // Connexion (WhatsApp ou email + PIN)
  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String pin,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action':     'login',
          'identifier': identifier,
          'pin':        pin,
        }),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (_) {
      return {'success': false, 'error': 'Connexion impossible. Vérifie ta connexion internet.'};
    }
  }

  // Inscription (PIN généré automatiquement par le serveur)
  static Future<Map<String, dynamic>> register({
    required String whatsapp,
    required String email,
    required String nom,
    String pays = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action':   'register',
          'whatsapp': whatsapp,
          'email':    email,
          'nom':      nom,
          'pays':     pays,
        }),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (_) {
      return {'success': false, 'error': 'Inscription impossible. Vérifie ta connexion internet.'};
    }
  }

  // Récupère le score/niveau réels du serveur pour un token donné.
  // Réutilise sync_score.php avec un événement neutre (0 point) : le
  // serveur ignore de toute façon tout score envoyé par le client et
  // renvoie toujours son propre total authoritatif — pratique pour
  // simplement "lire" l'état sans créer de doublon d'endpoint.
  static Future<Map<String, dynamic>> fetchScore(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/sync_score.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token, 'event_type': 'saison'}),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (_) {
      return {'success': false};
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

  // Get today's ad view count
  static Future<Map<String, dynamic>> getAdViewsToday(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/ad_view.php?token=$token'),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'ads_watched_today': 0};
    } catch (_) {
      return {'success': false, 'ads_watched_today': 0};
    }
  }

  // Record an ad view
  static Future<Map<String, dynamic>> recordAdView({
    required String token,
    required AdNetwork adNetwork,
  }) async {
    try {
      final networkString = adNetwork.toString().split('.').last;
      final response = await http.post(
        Uri.parse('$_baseUrl/ad_view.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'ad_network': networkString,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false};
    } catch (_) {
      return {'success': false};
    }
  }
}
