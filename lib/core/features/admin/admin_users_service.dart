import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../constants/constants.dart';
import 'admin_auth.dart';

class AdminUsersService {
  static Future<List<Map<String, dynamic>>> fetchUsers() async {
    final response = await http.get(
      Uri.parse('${AppConstants.adminBaseUrl}/users'),
      headers: AdminAuth.headers(),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur chargement utilisateurs admin');
    }

    final decoded = json.decode(response.body);
    if (decoded is List) {
      return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }

    return const [];
  }
}