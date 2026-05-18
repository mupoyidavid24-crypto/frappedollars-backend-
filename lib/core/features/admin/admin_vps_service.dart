import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../constants/constants.dart';
import 'admin_auth.dart';

class AdminVpsService {
  static String get baseUrl => AppConstants.adminBaseUrl;

  static Future<List<Map<String, dynamic>>> fetchAssignments() async {
    final response = await http.get(
      Uri.parse('$baseUrl/vps/assignments'),
      headers: AdminAuth.headers(),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur chargement VPS');
    }

    final decoded = json.decode(response.body);
    if (decoded is List) {
      return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }

    return const [];
  }

  static Future<void> updateAssignment(
    String userId, {
    required String status,
    String? provider,
    String? hostLabel,
    String? notes,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/vps/assignments/$userId/action'),
      headers: AdminAuth.headers(jsonContent: true),
      body: json.encode({
        'status': status,
        'provider': provider,
        'host_label': hostLabel,
        'notes': notes,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur mise à jour VPS');
    }
  }
}
