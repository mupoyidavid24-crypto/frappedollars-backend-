import 'package:flutter/material.dart';

import 'admin_users_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = AdminUsersService.fetchUsers();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = AdminUsersService.fetchUsers();
    });
  }

  String _nameOf(Map<String, dynamic> user) {
    final fullName = user['full_name']?.toString().trim() ?? '';
    if (fullName.isNotEmpty) return fullName;
    final email = user['email']?.toString().trim() ?? '';
    return email.isNotEmpty ? email : 'Utilisateur';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des utilisateurs'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          final users = snapshot.data ?? const <Map<String, dynamic>>[];
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final user = users[index];
              final userId = user['id']?.toString() ?? '';
              final suspended = (user['role']?.toString().toUpperCase() ?? '') == 'SUSPENDED';
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_nameOf(user), style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(user['email']?.toString() ?? '', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text('KYC: ${user['kyc_status'] ?? 'PENDING'}'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton(
                            onPressed: userId.isEmpty
                                ? null
                                : () async {
                                    await AdminUsersService.activateUser(userId);
                                    await _refresh();
                                  },
                            child: const Text('Activer'),
                          ),
                          OutlinedButton(
                            onPressed: userId.isEmpty
                                ? null
                                : () async {
                                    await AdminUsersService.suspendUser(userId);
                                    await _refresh();
                                  },
                            child: const Text('Suspendre'),
                          ),
                          TextButton(
                            onPressed: userId.isEmpty
                                ? null
                                : () async {
                                    await AdminUsersService.deleteUser(userId);
                                    await _refresh();
                                  },
                            child: const Text('Supprimer'),
                          ),
                          Chip(label: Text(suspended ? 'SUSPENDED' : 'ACTIVE')),
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
