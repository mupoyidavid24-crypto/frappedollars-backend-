import 'package:flutter/material.dart';
import '../../core/constants/constants.dart';
import '../../core/services/supabase_service.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final supabaseService = SupabaseService();

    return Scaffold(
      appBar: AppBar(title: const Text('Classement Top 10')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabaseService.getLeaderboardStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final users = snapshot.data!;
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final profit = (user['total_profit'] ?? 0.0).toDouble();
              
              // Anonymisation : David Mupoyi -> D*** M***
              final String rawName = user['full_name'] ?? user['email'].split('@')[0];
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
          );
        },
      ),
    );
  }

  String _anonymize(String name) {
    List<String> parts = name.split(' ');
    return parts.map((p) => p.isNotEmpty ? '${p[0]}***' : '').join(' ');
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0: return Colors.amber; // Or
      case 1: return Colors.grey;  // Argent
      case 2: return Colors.brown; // Bronze
      default: return Colors.white24;
    }
  }
}
