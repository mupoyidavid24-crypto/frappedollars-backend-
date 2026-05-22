import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_supabase_queries.dart';

class CopyTradingAdminService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<bool> toggleCopyTrading(String clientId) async {
    await _client.from('trading_accounts').update({'is_active': true}).eq('user_id', clientId);
    return true;
  }

  static Future<List<Map<String, dynamic>>> fetchHistory() async {
    try {
      final response = await _client
          .from('copied_trades')
          .select(AdminSupabaseQueries.copiedTradesSelect)
          .order('created_at', ascending: false)
          .limit(100);
      return (response as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }
}
