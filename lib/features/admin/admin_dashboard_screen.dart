import 'package:flutter/material.dart';
import 'admin_user_list.dart';
import 'admin_logs_list.dart';
import 'admin_support_list.dart';
import 'admin_actions.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Gestion des utilisateurs'),
            subtitle: const Text('Voir, suspendre, supprimer'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminUserList()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('Transactions & abonnements'),
            subtitle: const Text('Superviser les activités'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('Tickets de support'),
            subtitle: const Text('Gérer les demandes clients'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminSupportList()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.warning),
            title: const Text('Logs & alertes'),
            subtitle: const Text('Voir les erreurs et alertes'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminLogsList()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Actions admin'),
            subtitle: const Text('Paiement, blocage, VIP, synchronisation'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminActions()),
              );
            },
          ),
        ],
      ),
    );
  }
}
