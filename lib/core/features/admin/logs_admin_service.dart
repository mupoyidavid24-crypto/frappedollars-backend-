import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../constants/constants.dart';
import 'admin_auth.dart';

class LogsAdminService {
  static String get baseUrl => AppConstants.adminBaseUrl;

  static Future<List<Map<String, dynamic>>> fetchLogs() async {
    final response = await http.get(Uri.parse('$baseUrl/logs'), headers: AdminAuth.headers());
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Erreur chargement logs');
    }
  }
}
