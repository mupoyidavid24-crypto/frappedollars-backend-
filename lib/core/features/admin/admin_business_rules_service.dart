import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../constants/constants.dart';
import '../../../models/business_rules_model.dart';
import 'admin_auth.dart';

class AdminBusinessRulesService {
  static String get baseUrl => AppConstants.adminBaseUrl;

  static Future<BusinessRules> fetchBusinessRules() async {
    final response = await http.get(
      Uri.parse('$baseUrl/business-rules'),
      headers: AdminAuth.headers(),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur chargement des règles métier');
    }

    final decoded = json.decode(response.body);
    if (decoded is Map<String, dynamic>) {
      return BusinessRules.fromJson(decoded);
    }
    if (decoded is Map) {
      return BusinessRules.fromJson(Map<String, dynamic>.from(decoded));
    }
    throw Exception('Réponse invalide pour les règles métier');
  }

  static Future<bool> updateBusinessRules(Map<String, dynamic> payload) async {
    final response = await http.put(
      Uri.parse('$baseUrl/business-rules'),
      headers: AdminAuth.headers(jsonContent: true),
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return true;
    }

    final detail = _extractError(response);
    throw Exception('Erreur mise à jour des règles métier: $detail');
  }

  static String _extractError(http.Response response) {
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map && decoded.containsKey('detail')) {
        return decoded['detail'].toString();
      }
    } catch (_) {
      // ignore
    }
    return response.body;
  }
}
