import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_supabase_queries.dart';

class ErrorAdminService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> fetchErrors() async {
    try {
      final response = await _client
          .from('errors_logs')
          .select(AdminSupabaseQueries.errorLogsSelect)
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
