import 'package:flutter/material.dart';
import '../../core/features/admin/admin_auth.dart';
import '../../core/features/admin/admin_copytrading_screen.dart';
import '../../core/features/admin/admin_notifications_screen.dart';
import '../../core/features/admin/admin_payments_screen.dart';
import '../../core/features/admin/admin_vip_screen.dart';
import 'admin_user_list.dart';
import 'admin_logs_list.dart';
import 'admin_support_list.dart';
import 'admin_actions.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Future<void> _logout() async {
    await AdminAuth.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/admin/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text('Déconnexion', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Session admin active',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AdminAuth.adminKey != null
                        ? 'La clé admin est chargée et les appels API sont autorisés.'
                        : 'Aucune clé admin chargée.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.payment),
            title: const Text('Paiements'),
            subtitle: const Text('Listing, validation, refus'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminPaymentsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            subtitle: const Text('Push, historique, diffusion'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminNotificationsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.star),
            title: const Text('Gestion VIP'),
            subtitle: const Text('Bascule VIP, profils prioritaires'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminVIPScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.sync_alt),
            title: const Text('Copy Trading'),
            subtitle: const Text('Statut, synchronisation, historique'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminCopyTradingScreen()),
              );
            },
          ),
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
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminPaymentsScreen()),
              );
            },
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
