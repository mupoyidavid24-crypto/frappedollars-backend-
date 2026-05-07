import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../constants/constants.dart';
import 'admin_auth.dart';

class ErrorAdminService {
  static String get baseUrl => AppConstants.adminBaseUrl;

  static Future<List<Map<String, dynamic>>> fetchErrors() async {
    final response = await http.get(Uri.parse('$baseUrl/errors'), headers: AdminAuth.headers());
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(decoded);
      }
      return <Map<String, dynamic>>[];
    }
    throw Exception('Erreur chargement erreurs');
  }
}
