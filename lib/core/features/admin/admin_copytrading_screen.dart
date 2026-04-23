import 'dart:async';

import 'package:flutter/material.dart';
import '../../constants/constants.dart';
import 'copytrading_admin_service.dart';

class AdminCopyTradingScreen extends StatefulWidget {
  const AdminCopyTradingScreen({Key? key}) : super(key: key);

  @override
  _AdminCopyTradingScreenState createState() => _AdminCopyTradingScreenState();
}

class _AdminCopyTradingScreenState extends State<AdminCopyTradingScreen> {
  bool isActive = false;
  List<Map<String, dynamic>> history = [];
  bool loading = false;
  final TextEditingController _clientIdController = TextEditingController();
  Timer? _refreshTimer;

  void toggleCopyTrading(String clientId) async {
    setState(() { loading = true; });
    final ok = await CopyTradingAdminService.toggleCopyTrading(clientId);
    setState(() { loading = false; });
    if (ok) {
      setState(() { isActive = !isActive; });
      fetchHistory();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copy trading synchronisé'))
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur synchronisation'))
      );
    }
  }

  void fetchHistory() async {
    setState(() { loading = true; });
    try {
      final result = await CopyTradingAdminService.fetchHistory();
      setState(() { history = result; loading = false; });
    } catch (e) {
      setState(() { loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur chargement historique'))
      );
    }
  }

  @override
  void initState() {
    super.initState();
    fetchHistory();
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 5), (_) {
      if (mounted) {
        fetchHistory();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _clientIdController.dispose();
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
                const Text('Copy Trading', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Synchronisation des clients et historique d’exécution', style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _CopyStat(label: 'Historique', value: '${history.length}'),
                    _CopyStat(label: 'Statut', value: isActive ? 'Actif' : 'Inactif'),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white.withOpacity(0.04),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _clientIdController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'ID du client à synchroniser',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        activeColor: const Color(AppConstants.primaryColor),
                        title: const Text('Statut Copy Trading', style: TextStyle(color: Colors.white)),
                        subtitle: Text(isActive ? 'Pipeline actif' : 'Pipeline désactivé', style: const TextStyle(color: Colors.white54)),
                        value: isActive,
                        onChanged: (val) {
                          final clientId = _clientIdController.text.trim();
                          if (clientId.isNotEmpty) {
                            toggleCopyTrading(clientId);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Veuillez saisir un ID client valide')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator(color: Color(AppConstants.primaryColor)))
                      : history.isEmpty
                          ? const Center(child: Text('Aucun historique', style: TextStyle(color: Colors.white60)))
                          : ListView.separated(
                              itemCount: history.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final h = history[index];
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: Colors.white.withOpacity(0.04),
                                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                                  ),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const CircleAvatar(
                                      backgroundColor: Color(AppConstants.primaryColor),
                                      child: Icon(Icons.sync_alt, color: Colors.white),
                                    ),
                                    title: Text(h['action'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                    subtitle: Text('Date: ${h['date']}', style: const TextStyle(color: Colors.white70)),
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

class _CopyStat extends StatelessWidget {
  final String label;
  final String value;

  const _CopyStat({required this.label, required this.value});

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
