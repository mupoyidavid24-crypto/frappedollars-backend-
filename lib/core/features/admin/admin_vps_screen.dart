import 'package:flutter/material.dart';

import 'admin_vps_service.dart';

class AdminVpsScreen extends StatefulWidget {
  const AdminVpsScreen({super.key});

  @override
  State<AdminVpsScreen> createState() => _AdminVpsScreenState();
}

class _AdminVpsScreenState extends State<AdminVpsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = AdminVpsService.fetchAssignments();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = AdminVpsService.fetchAssignments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion VPS'),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          final assignments = snapshot.data ?? const <Map<String, dynamic>>[];
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: assignments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final assignment = assignments[index];
              final profile = Map<String, dynamic>.from(assignment['profile'] as Map? ?? {});
              final userId = assignment['user_id']?.toString() ?? '';
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile['full_name']?.toString() ?? profile['email']?.toString() ?? userId),
                      const SizedBox(height: 4),
                      Text('Statut: ${assignment['status'] ?? 'DISCONNECTED'}'),
                      Text('Provider: ${assignment['provider'] ?? '-'}'),
                      Text('Host: ${assignment['host_label'] ?? '-'}'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton(
                            onPressed: userId.isEmpty
                                ? null
                                : () async {
                                    await AdminVpsService.updateAssignment(userId, status: 'CONNECTED');
                                    await _refresh();
                                  },
                            child: const Text('Connecté'),
                          ),
                          OutlinedButton(
                            onPressed: userId.isEmpty
                                ? null
                                : () async {
                                    await AdminVpsService.updateAssignment(userId, status: 'DISCONNECTED');
                                    await _refresh();
                                  },
                            child: const Text('Déconnecté'),
                          ),
                          TextButton(
                            onPressed: userId.isEmpty
                                ? null
                                : () async {
                                    await AdminVpsService.updateAssignment(userId, status: 'RESTART_REQUESTED');
                                    await _refresh();
                                  },
                            child: const Text('Restart demandé'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
