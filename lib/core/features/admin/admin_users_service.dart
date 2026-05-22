import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/constants.dart';
import 'admin_auth.dart';

class AdminUsersService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> fetchUsers() async {
    final profilesResponse = await _client
        .from('profiles')
        .select('id, email, full_name, phone_number, date_of_birth, kyc_status, kyc_blocked, role, is_vip, needs_vps, created_at')
        .order('created_at', ascending: false);
    final accountsResponse = await _client
        .from('trading_accounts')
      .select('id, user_id, mt5_login, account_type, is_active, created_at')
        .order('created_at', ascending: false);

    final accountsByUserId = <String, List<Map<String, dynamic>>>{};
    for (final item in accountsResponse as List) {
      final account = Map<String, dynamic>.from(item as Map);
      final userId = account['user_id']?.toString() ?? '';
      if (userId.isEmpty) continue;
      accountsByUserId.putIfAbsent(userId, () => <Map<String, dynamic>>[]).add(account);
    }

    return (profilesResponse as List).map((item) {
      final profile = Map<String, dynamic>.from(item as Map);
      final userId = profile['id']?.toString() ?? '';
      final linkedAccounts = accountsByUserId[userId] ?? const <Map<String, dynamic>>[];
      final activeAccounts = linkedAccounts.where((account) => account['is_active'] == true).toList();
      return {
        ...profile,
        'trading_accounts': linkedAccounts,
        'mt5_logins': linkedAccounts.map((account) => account['mt5_login']).whereType<String>().toList(),
        'has_trading_account': linkedAccounts.isNotEmpty,
        'active_trading_accounts': activeAccounts.length,
        'inactive_trading_accounts': linkedAccounts.length - activeAccounts.length,
        'primary_mt5_login': linkedAccounts.isNotEmpty ? linkedAccounts.first['mt5_login'] : null,
      };
    }).toList();
  }

  static Future<void> activateUser(String userId) async {
    final response = await http.post(
      Uri.parse('${AppConstants.adminBaseUrl}/users/activate/$userId'),
      headers: AdminAuth.headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur activation utilisateur');
    }
  }

  static Future<void> suspendUser(String userId) async {
    final response = await http.post(
      Uri.parse('${AppConstants.adminBaseUrl}/users/suspend/$userId'),
      headers: AdminAuth.headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur suspension utilisateur');
    }
  }

  static Future<void> deleteUser(String userId) async {
    final response = await http.delete(
      Uri.parse('${AppConstants.adminBaseUrl}/users/$userId'),
      headers: AdminAuth.headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur suppression utilisateur');
    }
  }
}