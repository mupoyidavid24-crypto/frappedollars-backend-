import 'dart:convert';
import 'package:http/http.dart' as http;

class VIPAdminService {
  static const String baseUrl = 'http://localhost:8000/admin';

  static Future<List<Map<String, dynamic>>> fetchVIPUsers() async {
    final response = await http.get(Uri.parse('$baseUrl/users'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body).where((u) => u['is_vip'] == true));
    } else {
      throw Exception('Erreur chargement VIP');
    }
  }

  static Future<bool> toggleVIP(String userId, bool isVIP) async {
    final url = isVIP ? '$baseUrl/add_vip_client' : '$baseUrl/block_user/$userId';
    final response = isVIP
        ? await http.post(Uri.parse(url), body: json.encode({'id': userId}), headers: {'Content-Type': 'application/json'})
        : await http.post(Uri.parse(url));
    return response.statusCode == 200;
  }
}
