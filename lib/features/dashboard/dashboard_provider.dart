import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';
import '../../models/trading_account_model.dart';
import '../../models/subscription_model.dart';
import '../../models/trade_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class DashboardProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  
  TradingAccount? _account;
  Subscription? _subscription;
  List<Trade> _trades = [];
  bool _isLoading = false;

  TradingAccount? get account => _account;
  Subscription? get subscription => _subscription;
  List<Trade> get trades => _trades;
  bool get isLoading => _isLoading;

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
      final response = await http.get(Uri.parse('http://localhost:8000/client/download_ea?mt5_login=$mt5Login&user_id=$userId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['download_url'] as String?;
      }
    } catch (e) {
      debugPrint('Erreur téléchargement EA: $e');
    }
    return null;
  }
}
