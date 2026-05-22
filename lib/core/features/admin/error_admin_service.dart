import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorAdminService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> fetchErrors() async {
    try {
      final response = await _client
          .from('errors_logs')
          .select('id, source, component, severity, message, details, user_id, mt5_login, trade_id, created_at')
          .order('created_at', ascending: false)
          .limit(100);
      if (response is List) {
        return response.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
      return <Map<String, dynamic>>[];
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }
}
