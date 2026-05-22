import 'package:supabase_flutter/supabase_flutter.dart';

class AdminVpsService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> fetchAssignments() async {
    final assignments = List<Map<String, dynamic>>.from(await _client
        .from('vps_assignments')
        .select('id, user_id, status, provider, host_label, notes, last_heartbeat, last_restart_requested_at, created_at, updated_at')
        .order('updated_at', ascending: false));
    final assignmentIds = assignments
        .map((item) => item['user_id'])
        .whereType<String>()
        .toList();

    if (assignmentIds.isEmpty) {
      return assignments;
    }

    final profilesResponse = List<Map<String, dynamic>>.from(await _client
        .from('profiles')
        .select('id, email, full_name')
        .inFilter('id', assignmentIds));

    final profilesById = {
      for (final item in profilesResponse) item['id']?.toString() ?? '': item,
    };

    return assignments.map((assignment) {
      final userId = assignment['user_id']?.toString() ?? '';
      assignment['profile'] = profilesById[userId] ?? <String, dynamic>{};
      return assignment;
    }).toList();
  }

  static Future<void> updateAssignment(
    String userId, {
    required String status,
    String? provider,
    String? hostLabel,
    String? notes,
  }) async {
    final payload = {
      'user_id': userId,
      'status': status,
      'provider': provider,
      'host_label': hostLabel,
      'notes': notes,
    };

    final existing = await _client.from('vps_assignments').select('id').eq('user_id', userId).maybeSingle();
    if (existing != null && existing['id'] != null) {
      await _client.from('vps_assignments').update(payload).eq('user_id', userId);
      return;
    }

    await _client.from('vps_assignments').insert(payload);
  }
}
