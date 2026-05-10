import 'dart:async';

import 'package:flutter/material.dart';
import '../../constants/constants.dart';
import 'vip_admin_service.dart';

class AdminVIPScreen extends StatefulWidget {
  const AdminVIPScreen({Key? key}) : super(key: key);

  @override
  _AdminVIPScreenState createState() => _AdminVIPScreenState();
}

class _AdminVIPScreenState extends State<AdminVIPScreen> {
  List<Map<String, dynamic>> vipUsers = [];
  bool loading = false;
  bool _isFetchingVIP = false;
  Timer? _refreshTimer;

  void toggleVIP(String userId, bool isVIP) async {
    setState(() { loading = true; });
    final ok = await VIPAdminService.toggleVIP(userId, isVIP);
    setState(() { loading = false; });
    if (ok) {
      fetchVIPUsers();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isVIP ? 'VIP activé' : 'VIP désactivé'))
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur VIP'))
      );
    }
  }

  void fetchVIPUsers() async {
    if (_isFetchingVIP) return;
    _isFetchingVIP = true;
    setState(() { loading = true; });
    try {
      final result = await VIPAdminService.fetchVIPUsers();
      if (!mounted) return;
      setState(() { vipUsers = result; loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur chargement VIP'))
      );
    } finally {
      _isFetchingVIP = false;
    }
  }

  @override
  void initState() {
    super.initState();
    fetchVIPUsers();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        fetchVIPUsers();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F14),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF071116), Color(0xFF0C161B), Color(0xFF05080B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gestion VIP', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Bascule des clients prioritaires et suivi', style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _VipStat(label: 'VIP actifs', value: '${vipUsers.where((u) => u['is_vip'] == true).length}'),
                    _VipStat(label: 'Total visibles', value: '${vipUsers.length}'),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator(color: Color(AppConstants.primaryColor)))
                      : vipUsers.isEmpty
                          ? const Center(child: Text('Aucun VIP', style: TextStyle(color: Colors.white60)))
                          : ListView.separated(
                              itemCount: vipUsers.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final u = vipUsers[index];
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: Colors.white.withOpacity(0.04),
                                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                                  ),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: (u['is_vip'] == true ? Colors.amber : Colors.white24),
                                      child: Icon(Icons.star, color: u['is_vip'] == true ? Colors.black : Colors.white),
                                    ),
                                    title: Text(u['full_name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Email: ${u['email']}', style: const TextStyle(color: Colors.white70)),
                                        Text('Statut: ${u['is_vip'] ? 'VIP' : 'Normal'}', style: const TextStyle(color: Colors.white70)),
                                      ],
                                    ),
                                    trailing: Switch(
                                      activeThumbColor: const Color(AppConstants.primaryColor),
                                      value: u['is_vip'] ?? false,
                                      onChanged: (val) => toggleVIP(u['id'], val),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VipStat extends StatelessWidget {
  final String label;
  final String value;

  const _VipStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
