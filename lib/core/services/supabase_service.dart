import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/constants.dart';
import '../../models/profile_model.dart';
import '../../models/trading_account_model.dart';
import '../../models/subscription_model.dart';
import '../../models/trade_model.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // -- AUTHENTICATION --

  Future<AuthResponse> signUp(
    String email,
    String password, {
    Map<String, dynamic>? metadata,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: AppConstants.authRedirectUrl,
      data: metadata,
    );
  }

  Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth
        .signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut(scope: SignOutScope.local);
  }

  User? get currentUser => _client.auth.currentUser;

  // -- PROFILE --

  Future<Profile?> getUserProfile(String userId) async {
    final response =
        await _client.from('profiles').select().eq('id', userId).maybeSingle();

    if (response == null) return null;
    final merged = Map<String, dynamic>.from(response);
    final currentUser = _client.auth.currentUser;
    final metadata = currentUser?.userMetadata;
    if (merged['date_of_birth'] == null && metadata != null) {
      final metaDateOfBirth = metadata['date_of_birth'];
      if (metaDateOfBirth != null && metaDateOfBirth.toString().trim().isNotEmpty) {
        merged['date_of_birth'] = metaDateOfBirth;
      }
    }
    return Profile.fromJson(merged);
  }

  // -- TRADING ACCOUNTS --

  Future<TradingAccount?> getTradingAccount(String userId) async {
    final response = await _client
        .from('trading_accounts')
        .select()
        .eq('user_id', userId)
        .order('last_sync', ascending: false)
        .limit(1);
    if (response.isEmpty) return null;
    final data = response.first;
    return TradingAccount.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> saveTradingAccount(TradingAccount account) async {
    await _client.from('trading_accounts').upsert(account.toJson());
  }

  // -- SUBSCRIPTIONS --

  Future<Subscription?> getSubscription(String userId) async {
    final response = await _client
        .from('subscriptions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1);
    if (response.isEmpty) return null;
    final data = response.first;
    return Subscription.fromJson(Map<String, dynamic>.from(data as Map));
  }

  // -- TRADES --

  Future<List<Trade>> getCopiedTrades(String accountId) async {
    try {
      final response = await _client
          .from('copied_trades')
          .select(
              'id, signal_id, client_account_id, client_ticket_id, volume_executed, execution_status, profit, error_message, created_at, closed_at')
          .eq('client_account_id', accountId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => Trade.fromJson(json)).toList();
    } catch (e) {
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('403') ||
          errorMessage.contains('forbidden') ||
          errorMessage.contains('permission')) {
        return [];
      }
      rethrow;
    }
  }

  // -- LEADERBOARD --

  Future<List<Map<String, dynamic>>> getLeaderboardSnapshot() async {
    final response = await _client
        .from('profiles')
        .select('id, email, full_name, total_profit')
        .order('total_profit', ascending: false)
        .limit(10);

    return (response as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Stream<List<Map<String, dynamic>>> getLeaderboardStream() {
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .order('total_profit', ascending: false)
        .limit(10);
  }

  // -- REALTIME STREAMS --

  Stream<List<Map<String, dynamic>>> getAccountStream(String userId) {
    return _client
        .from('trading_accounts')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .limit(1);
  }

  Stream<List<Map<String, dynamic>>> getTradesStream(String accountId) {
    return _client
        .from('copied_trades')
        .stream(primaryKey: ['id'])
        .eq('client_account_id', accountId)
        .order('created_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> getSubscriptionStream(String userId) {
    return _client
        .from('subscriptions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .limit(1);
  }
}
