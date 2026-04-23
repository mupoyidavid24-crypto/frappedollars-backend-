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
    final response = await http.get(Uri.parse('$baseUrl/trade_dispatches'), headers: AdminAuth.headers());
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is Map && decoded['items'] is List) {
        return List<Map<String, dynamic>>.from(decoded['items'] as List);
      }
      return List<Map<String, dynamic>>.from(decoded as List);
    } else {
      throw Exception('Erreur chargement historique');
    }
  }
}
