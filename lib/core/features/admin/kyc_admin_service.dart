import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../constants/constants.dart';
import 'admin_auth.dart';

class KycAdminService {
  static String get baseUrl => AppConstants.adminBaseUrl;

  static Future<List<Map<String, dynamic>>> fetchKycDocuments() async {
    final response = await http.get(
      Uri.parse('$baseUrl/kyc/documents'),
      headers: AdminAuth.headers(),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur chargement KYC');
    }

    final decoded = json.decode(response.body);
    if (decoded is List) {
      return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }

    return const [];
  }

  static Future<bool> updateStatus(
    String documentId,
    String status, {
    required String reason,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/kyc/documents/$documentId/status'),
      headers: AdminAuth.headers(jsonContent: true),
      body: json.encode({
        'status': status,
        'reason': reason,
        'reviewer_note': reason,
      }),
    );

    if (response.statusCode == 200) {
      return true;
    }

    final decoded = _extractError(response);
    throw Exception('Erreur mise à jour KYC: $decoded');
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
