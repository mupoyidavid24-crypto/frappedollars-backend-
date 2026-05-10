import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../constants/constants.dart';
import 'admin_auth.dart';

class PaymentAdminService {
  static String get baseUrl => AppConstants.adminBaseUrl;

  // Récupérer la liste des paiements
  static Future<List<Map<String, dynamic>>> fetchPayments() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/payments'), headers: AdminAuth.headers());
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      } else {
        final msg = _extractError(response);
        throw Exception('Erreur chargement paiements: $msg');
      }
    } catch (e) {
      throw Exception('Erreur réseau ou serveur: ${e.toString()}');
    }
  }

  // Valider un paiement
  static Future<bool> validatePayment(String paymentId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payments/approve/$paymentId'),
        headers: AdminAuth.headers(),
      );
      if (response.statusCode == 200) return true;
      final msg = _extractError(response);
      throw Exception('Erreur validation: $msg');
    } catch (e) {
      throw Exception('Erreur réseau ou serveur: ${e.toString()}');
    }
  }

  // Refuser un paiement
  static Future<bool> refusePayment(String paymentId, String motif) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payments/reject/$paymentId'),
        body: json.encode({'motif': motif}),
        headers: AdminAuth.headers(jsonContent: true),
      );
      if (response.statusCode == 200) return true;
      final msg = _extractError(response);
      throw Exception('Erreur refus: $msg');
    } catch (e) {
      throw Exception('Erreur réseau ou serveur: ${e.toString()}');
    }
  }
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
