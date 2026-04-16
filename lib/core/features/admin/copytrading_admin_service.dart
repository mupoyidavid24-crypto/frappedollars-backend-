import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../constants/constants.dart';
import 'admin_auth.dart';

class CopyTradingAdminService {
  static String get baseUrl => AppConstants.adminBaseUrl;

  static Future<bool> toggleCopyTrading(String clientId) async {
    final response = await http.post(Uri.parse('$baseUrl/sync_with_master/$clientId'), headers: AdminAuth.headers());
    return response.statusCode == 200;
  }

  static Future<List<Map<String, dynamic>>> fetchHistory() async {
    final response = await http.get(Uri.parse('$baseUrl/copytrading/history'), headers: AdminAuth.headers());
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Erreur chargement historique');
    }
  }
}
