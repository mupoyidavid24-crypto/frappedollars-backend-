import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../constants/constants.dart';
import 'admin_auth.dart';

class NotificationAdminService {
  static String get baseUrl => AppConstants.adminBaseUrl;

  static Future<bool> sendNotification(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notifications/send'),
        body: json.encode(data),
        headers: AdminAuth.headers(jsonContent: true),
      );
      if (response.statusCode == 200) return true;
      final msg = _extractError(response);
      throw Exception('Erreur envoi notification: $msg');
    } catch (e) {
      throw Exception('Erreur réseau ou serveur: ${e.toString()}');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchNotifications() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/notifications'), headers: AdminAuth.headers());
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      } else {
        final msg = _extractError(response);
        throw Exception('Erreur chargement notifications: $msg');
      }
    } catch (e) {
      throw Exception('Erreur réseau ou serveur: ${e.toString()}');
    }
  }
  // Extraction d’erreur pour messages backend
  static String _extractError(http.Response response) {
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map && decoded.containsKey('detail')) {
        return decoded['detail'];
      }
      return response.body;
    } catch (_) {
      return response.body;
    }
  }
}
