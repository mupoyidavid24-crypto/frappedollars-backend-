import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_supabase_queries.dart';

class NotificationAdminService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<bool> sendNotification(Map<String, dynamic> data) async {
    await _client.from('notifications').insert(data);
    return true;
  }

  static Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final response = await _client
        .from('notifications')
      .select(AdminSupabaseQueries.notificationsSelect)
        .order('created_at', ascending: false);
    return (response as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }
}
