import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPaymentMethodsService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> fetchPaymentMethods() async {
    final response = await _client
        .from('payment_methods')
        .select('id, provider, label, account_name, account_number, is_active, metadata, created_at, updated_at')
        .order('created_at', ascending: false);
    return (response as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  static Future<void> createPaymentMethod(Map<String, dynamic> payload) async {
    await _client.from('payment_methods').insert(payload);
  }

  static Future<void> updatePaymentMethod(String methodId, Map<String, dynamic> payload) async {
    await _client.from('payment_methods').update(payload).eq('id', methodId);
  }

  static Future<void> deletePaymentMethod(String methodId) async {
    await _client.from('payment_methods').delete().eq('id', methodId);
  }
}
