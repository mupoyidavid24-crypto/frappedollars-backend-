import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_supabase_queries.dart';

class PaymentAdminService {
  static SupabaseClient get _client => Supabase.instance.client;

  // Récupérer la liste des paiements
  static Future<List<Map<String, dynamic>>> fetchPayments() async {
    final response = await _client
        .from('payments')
      .select(AdminSupabaseQueries.paymentsSelect)
        .order('created_at', ascending: false);
    return (response as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  // Valider un paiement
  static Future<bool> validatePayment(String paymentId) async {
    await _client.from('payments').update({
      'payment_status': 'APPROVED',
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', paymentId);
    return true;
  }

  // Refuser un paiement
  static Future<bool> refusePayment(String paymentId, String motif) async {
    await _client.from('payments').update({
      'payment_status': 'REJECTED',
      'review_reason': motif,
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', paymentId);
    return true;
  }
}
