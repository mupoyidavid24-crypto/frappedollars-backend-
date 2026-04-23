import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';
import '../../models/trading_account_model.dart';
import '../../models/subscription_model.dart';
import '../../models/trade_model.dart';
import '../../core/services/ea_download_helper.dart';
import 'package:flutter/services.dart' show rootBundle;


class DashboardProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  Timer? _liveRefreshTimer;
  String? _activeUserId;
  
  TradingAccount? _account;
  Subscription? _subscription;
  List<Trade> _trades = [];
  bool _isLoading = false;

  TradingAccount? get account => _account;
  Subscription? get subscription => _subscription;
  List<Trade> get trades => _trades;
  bool get isLoading => _isLoading;

  Future<void> startLiveSync(String userId) async {
    if (_activeUserId == userId && _liveRefreshTimer != null) {
      return;
    }

    _activeUserId = userId;
    _liveRefreshTimer?.cancel();
    _liveRefreshTimer = Timer.periodic(const Duration(milliseconds: 5), (_) {
      refreshDashboardData();
    });

    await loadDashboardData(userId);
  }

  Future<void> refreshDashboardData() async {
    final userId = _activeUserId;
    if (userId == null) {
      return;
    }

    try {
      final account = await _supabaseService.getTradingAccount(userId);
      final subscription = await _supabaseService.getSubscription(userId);
      List<Trade> trades = <Trade>[];

      if (account != null && account.id != null) {
        trades = await _supabaseService.getCopiedTrades(account.id!);
      }

      _account = account;
      _subscription = subscription;
      _trades = trades;
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing dashboard data: $e');
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
      _account = await _supabaseService.getTradingAccount(userId);
      _subscription = await _supabaseService.getSubscription(userId);
      
      if (_account != null && _account!.id != null) {
        _trades = await _supabaseService.getCopiedTrades(_account!.id!);
      } else {
        _trades = [];
      }
    } catch (e) {
      debugPrint("Error loading dashboard data: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> connectMT5(String userId, String login, String server, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final newAccount = TradingAccount(
        userId: userId,
        mt5Login: login,
        mt5Server: server,
        accountType: 'CLIENT',
        balance: 0.0,
        equity: 0.0,
        isActive: true,
      );
      await _supabaseService.saveTradingAccount(newAccount);
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
      _account = null;
      _trades = [];
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
