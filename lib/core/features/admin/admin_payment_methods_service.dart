import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../constants/constants.dart';
import 'admin_auth.dart';

class AdminPaymentMethodsService {
  static String get baseUrl => AppConstants.adminBaseUrl;

  static Future<List<Map<String, dynamic>>> fetchPaymentMethods() async {
    final response = await http.get(
      Uri.parse('$baseUrl/payment-methods'),
      headers: AdminAuth.headers(),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur chargement moyens de paiement');
    }

    final decoded = json.decode(response.body);
    if (decoded is List) {
      return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }

    return const [];
  }

  static Future<void> createPaymentMethod(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payment-methods'),
      headers: AdminAuth.headers(jsonContent: true),
      body: json.encode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur création moyen de paiement');
    }
  }

  static Future<void> updatePaymentMethod(String methodId, Map<String, dynamic> payload) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/payment-methods/$methodId'),
      headers: AdminAuth.headers(jsonContent: true),
      body: json.encode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur mise à jour moyen de paiement');
    }
  }

  static Future<void> deletePaymentMethod(String methodId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/payment-methods/$methodId'),
      headers: AdminAuth.headers(),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur suppression moyen de paiement');
    }
  }
}
