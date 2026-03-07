import 'package:flutter/material.dart';

class AdminDashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Centre de contrôle Admin'),
      ),
      body: ListView(
        children: [
          _DashboardTile(
            icon: Icons.payment,
            title: 'Paiements',
            subtitle: 'Listing, validation/refus, filtres',
            onTap: () => Navigator.pushNamed(context, '/admin/payments'),
          ),
          _DashboardTile(
            icon: Icons.notifications,
            title: 'Notifications',
            subtitle: 'Push, EA, historique, personnalisation',
            onTap: () => Navigator.pushNamed(context, '/admin/notifications'),
          ),
          _DashboardTile(
            icon: Icons.star,
            title: 'Gestion VIP',
            subtitle: 'Fiche, bascule, historique',
            onTap: () => Navigator.pushNamed(context, '/admin/vip'),
          ),
          _DashboardTile(
            icon: Icons.sync_alt,
            title: 'Copy Trading',
            subtitle: 'Démarrage, statut, historique',
            onTap: () => Navigator.pushNamed(context, '/admin/copytrading'),
          ),
          _DashboardTile(
            icon: Icons.list_alt,
            title: 'Logs',
            subtitle: 'Journalisation accès/actions',
            onTap: () => Navigator.pushNamed(context, '/admin/logs'),
          ),
        ],
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DashboardTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}
