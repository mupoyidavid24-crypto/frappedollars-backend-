import 'package:flutter/material.dart';
import '../../constants/constants.dart';
import 'logs_admin_service.dart';

class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({Key? key}) : super(key: key);

  @override
  _AdminLogsScreenState createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
  List<Map<String, dynamic>> logs = [];
  bool loading = false;

  void fetchLogs() async {
    setState(() { loading = true; });
    try {
      final result = await LogsAdminService.fetchLogs();
      setState(() { logs = result; loading = false; });
    } catch (e) {
      setState(() { loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur chargement logs'))
      );
    }
  }

  @override
  void initState() {
    super.initState();
    fetchLogs();
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
                const Text('Journalisation Admin', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Traçabilité des accès et actions critiques', style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _LogStat(label: 'Logs', value: '${logs.length}'),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator(color: Color(AppConstants.primaryColor)))
                      : logs.isEmpty
                          ? const Center(child: Text('Aucun log', style: TextStyle(color: Colors.white60)))
                          : ListView.separated(
                              itemCount: logs.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final l = logs[index];
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
                                      child: Icon(Icons.list_alt, color: Colors.white),
                                    ),
                                    title: Text('Action: ${l['action']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Admin: ${l['admin_id']}', style: const TextStyle(color: Colors.white70)),
                                        Text('Date: ${l['timestamp']}', style: const TextStyle(color: Colors.white70)),
                                        Text('IP: ${l['ip_address']}', style: const TextStyle(color: Colors.white70)),
                                      ],
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

class _LogStat extends StatelessWidget {
  final String label;
  final String value;

  const _LogStat({required this.label, required this.value});

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
