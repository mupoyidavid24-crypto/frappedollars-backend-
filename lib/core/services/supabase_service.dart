import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/profile_model.dart';
import '../../models/trading_account_model.dart';
import '../../models/subscription_model.dart';
import '../../models/trade_model.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // -- AUTHENTICATION --

  Future<AuthResponse> signUp(String email, String password) async {
    return await _client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;

  // -- PROFILE --

  Future<Profile?> getUserProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    
    if (response == null) return null;
    return Profile.fromJson(response);
  }

  // -- TRADING ACCOUNTS --

  Future<TradingAccount?> getTradingAccount(String userId) async {
    final response = await _client
      .from('trading_accounts')
      .select()
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .limit(1);
    if (response == null || (response is List && response.isEmpty)) return null;
    final data = response is List ? response.first : response;
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
    if (response == null || (response is List && response.isEmpty)) return null;
    final data = response is List ? response.first : response;
    return Subscription.fromJson(Map<String, dynamic>.from(data as Map));
  }

  // -- TRADES --

  Future<List<Trade>> getCopiedTrades(String accountId) async {
    final response = await _client
        .from('copied_trades')
        .select('*, signals(*)')
        .eq('client_account_id', accountId)
        .order('created_at', ascending: false);
    
    return (response as List).map((json) => Trade.fromJson(json)).toList();
  }

  // -- LEADERBOARD --

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
