import 'package:supabase_flutter/supabase_flutter.dart';

class VIPAdminService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> fetchVIPUsers() async {
    final response = await _client
        .from('profiles')
        .select('id, email, full_name, is_vip, created_at, total_profit')
        .eq('is_vip', true)
        .order('created_at', ascending: false);
    return (response as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  static Future<bool> toggleVIP(String userId, bool isVIP) async {
    if (isVIP) {
      await _client.from('profiles').update({'is_vip': true}).eq('id', userId);
    } else {
      await _client.from('profiles').update({'is_vip': false}).eq('id', userId);
    }
    return true;
  }
}
