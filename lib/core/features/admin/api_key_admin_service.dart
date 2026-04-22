import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../constants/constants.dart';
import 'admin_auth.dart';

class ApiKeyAdminService {
  static String get baseUrl => AppConstants.adminBaseUrl;

  static Future<Map<String, dynamic>> generateApiKey({
    required String mt5Login,
    required String accountRole,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/generate_api_key'),
      headers: AdminAuth.headers(jsonContent: true),
      body: jsonEncode({
        'mt5_login': mt5Login,
        'account_role': accountRole,
      }),
    );

    final decoded = _decodeResponse(response.body);
    if (response.statusCode >= 400) {
      final detail = decoded['detail']?.toString() ?? 'Erreur serveur (${response.statusCode}).';
      throw Exception(detail);
    }
    return decoded;
  }

  static Map<String, dynamic> _decodeResponse(String body) {
    if (body.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return <String, dynamic>{'data': decoded};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}