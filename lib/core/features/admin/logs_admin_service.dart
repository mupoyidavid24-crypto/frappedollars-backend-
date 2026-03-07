import 'dart:convert';
import 'package:http/http.dart' as http;

class LogsAdminService {
  static const String baseUrl = 'http://localhost:8000/admin';

  static Future<List<Map<String, dynamic>>> fetchLogs() async {
    final response = await http.get(Uri.parse('$baseUrl/logs'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Erreur chargement logs');
    }
  }
}
