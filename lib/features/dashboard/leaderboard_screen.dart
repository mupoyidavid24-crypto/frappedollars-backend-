import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/constants/constants.dart';
import '../../core/services/supabase_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  Timer? _refreshTimer;
  bool _loading = true;
  bool _refreshing = false;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) => _loadLeaderboard(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLeaderboard({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!silent && mounted) {
      setState(() => _loading = true);
    }

    try {
      final response = await _supabaseService.getLeaderboardSnapshot();
      if (!mounted) return;
      setState(() {
        _users = response;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Leaderboard refresh error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Classement Top 10')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('Aucun classement disponible.'))
              : RefreshIndicator(
                  onRefresh: () => _loadLeaderboard(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final profit = (user['total_profit'] ?? 0.0).toDouble();

                      final String rawName = user['full_name']?.toString() ?? user['email']?.toString().split('@')[0] ?? 'Utilisateur';
                      final String anonymousName = _anonymize(rawName);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getRankColor(index),
                            child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(anonymousName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: Text(
                            '+\$${profit.toStringAsFixed(2)}',
                            style: const TextStyle(color: Color(AppConstants.primaryColor), fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _anonymize(String name) {
    final parts = name.split(' ');
    return parts.map((p) => p.isNotEmpty ? '${p[0]}***' : '').join(' ');
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber;
      case 1:
        return Colors.grey;
      case 2:
        return Colors.brown;
      default:
        return Colors.white24;
    }
  }
}