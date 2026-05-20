import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/constants.dart';
import '../../models/trading_account_model.dart';
import '../../models/subscription_model.dart';
import '../../models/trade_model.dart';
import '../../models/business_rules_model.dart';
import '../../core/services/ea_download_helper.dart';
import 'package:flutter/services.dart' show rootBundle;


class DashboardProvider extends ChangeNotifier {
  Timer? _liveRefreshTimer;
  String? _activeUserId;
  bool _isRefreshing = false;
  bool _liveSyncPaused = false;
  
  TradingAccount? _account;
  Subscription? _subscription;
  BusinessRules? _businessRules;
  List<Trade> _trades = [];
  bool _isLoading = false;

  TradingAccount? get account => _account;
  Subscription? get subscription => _subscription;
  BusinessRules? get businessRules => _businessRules;
  List<Trade> get trades => _trades;
  bool get isLoading => _isLoading;

  Future<void> startLiveSync(String userId) async {
    if (_activeUserId == userId && _liveRefreshTimer != null) {
      return;
    }

    _activeUserId = userId;
    _liveSyncPaused = false;
    _liveRefreshTimer?.cancel();
    await loadDashboardData(userId);

    if (_liveSyncPaused) {
      return;
    }

    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      refreshDashboardData();
    });
  }

  Future<void> refreshDashboardData() async {
    final userId = _activeUserId;
    if (userId == null || _isRefreshing) {
      return;
    }

    _isRefreshing = true;

    try {
      await _loadFromBackend(userId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing dashboard data: $e');
      if (_isNetworkFailure(e)) {
        _pauseLiveSync('refresh');
      }
    } finally {
      _isRefreshing = false;
    }
  }

  void stopLiveSync() {
    _liveRefreshTimer?.cancel();
    _liveRefreshTimer = null;
    _activeUserId = null;
  }

  Future<void> loadDashboardData(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadFromBackend(userId);
    } catch (e) {
      debugPrint("Error loading dashboard data: $e");
      if (_isNetworkFailure(e)) {
        _pauseLiveSync('load');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadFromBackend(String userId) async {
    final accessToken = Supabase.instance.client.auth.currentSession?.accessToken;
    final response = await http.get(
      Uri.parse('${AppConstants.backendBaseUrl}/dashboard/state/$userId'),
      headers: {
        'Accept': 'application/json',
        if (accessToken != null && accessToken.isNotEmpty) 'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 404) {
      _account = null;
      _subscription = null;
      _trades = [];
      return;
    }

    if (response.statusCode >= 500) {
      throw Exception('Backend dashboard error ${response.statusCode}');
    }

    if (response.statusCode != 200) {
      throw Exception('Backend dashboard error ${response.statusCode}: ${response.body}');
    }

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    final accountJson = decoded['account'];
    final subscriptionJson = decoded['subscription'];
    final businessRulesJson = decoded['business_rules'];
    final tradesJson = decoded['trades'];

    _account = accountJson is Map<String, dynamic>
        ? TradingAccount.fromJson(accountJson)
        : null;
    _subscription = subscriptionJson is Map<String, dynamic>
        ? Subscription.fromJson(subscriptionJson)
        : null;
    _businessRules = businessRulesJson is Map<String, dynamic>
      ? BusinessRules.fromJson(businessRulesJson)
      : null;
    _trades = tradesJson is List
        ? tradesJson
            .whereType<Map>()
            .map((item) => Trade.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : [];
  }

  void _pauseLiveSync(String source) {
    if (_liveSyncPaused) {
      return;
    }

    _liveSyncPaused = true;
    _liveRefreshTimer?.cancel();
    _liveRefreshTimer = null;
    debugPrint('Dashboard live sync paused after $source network failure.');
  }

  bool _isNetworkFailure(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('failed to fetch') ||
        message.contains('clientexception') ||
        message.contains('name_not_resolved') ||
        message.contains('network changed') ||
        message.contains('insufficient_resources') ||
        message.contains('socket') ||
        message.contains('connection');
  }

  Future<bool> connectMT5(String userId, String login, String server, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('kyc_status, kyc_blocked')
          .eq('id', userId)
          .maybeSingle();
      final profile = profileResponse;
      final kycStatus = (profile?['kyc_status']?.toString() ?? 'PENDING').toUpperCase();
      final kycBlocked = profile?['kyc_blocked'] ?? true;
      if (AppConstants.kycRequired && (kycStatus != 'APPROVED' || kycBlocked == true)) {
        throw Exception('KYC_REQUIRED');
      }

      final accessToken = Supabase.instance.client.auth.currentSession?.accessToken;
      final response = await http.post(
        Uri.parse('${AppConstants.backendBaseUrl}/dashboard/connect_mt5'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (accessToken != null && accessToken.isNotEmpty) 'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({
          'user_id': userId,
          'mt5_login': login,
          'mt5_server': server,
          'account_type': 'CLIENT',
          'is_active': true,
        }),
      );

      if (response.statusCode >= 500) {
        throw Exception('Backend connect error ${response.statusCode}');
      }
      if (response.statusCode != 200) {
        throw Exception('Backend connect error ${response.statusCode}: ${response.body}');
      }

      await loadDashboardData(userId);
      return true;
    } catch (e) {
      debugPrint("Error connecting MT5: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> disconnectMT5(String userId) async {
     _isLoading = true;
    notifyListeners();
    try {
      final accessToken = Supabase.instance.client.auth.currentSession?.accessToken;
      final response = await http.post(
        Uri.parse('${AppConstants.backendBaseUrl}/dashboard/disconnect_mt5/$userId'),
        headers: {
          'Accept': 'application/json',
          if (accessToken != null && accessToken.isNotEmpty) 'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode >= 500) {
        throw Exception('Backend disconnect error ${response.statusCode}');
      }
      if (response.statusCode != 200) {
        throw Exception('Backend disconnect error ${response.statusCode}: ${response.body}');
      }

      _account = null;
      _trades = [];
      _subscription = null;
      _businessRules = null;
    } catch (e) {
      debugPrint("Error disconnecting MT5: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> downloadEa(String mt5Login, String userId) async {
    try {
      final template = await rootBundle.loadString('mt5/FrappedDollarsClient.mq5');
      final fileName = 'FrappedDollarsClient_$mt5Login.mq5';
      final downloaded = await downloadEaFile(fileName, template);
      if (downloaded) {
        return 'downloaded';
      }
    } catch (e) {
      debugPrint('Erreur téléchargement EA local: $e');
    }

    return null;
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    super.dispose();
  }
}
