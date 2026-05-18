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

  static Future<void> activateUser(String userId) async {
    final response = await http.post(
      Uri.parse('${AppConstants.adminBaseUrl}/users/activate/$userId'),
      headers: AdminAuth.headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur activation utilisateur');
    }
  }

  static Future<void> suspendUser(String userId) async {
    final response = await http.post(
      Uri.parse('${AppConstants.adminBaseUrl}/users/suspend/$userId'),
      headers: AdminAuth.headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur suspension utilisateur');
    }
  }

  static Future<void> deleteUser(String userId) async {
    final response = await http.delete(
      Uri.parse('${AppConstants.adminBaseUrl}/users/$userId'),
      headers: AdminAuth.headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur suppression utilisateur');
    }
  }
}