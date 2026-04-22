import 'package:flutter/material.dart';
import '../../core/features/admin/admin_auth.dart';
import 'admin_login_screen.dart';
import 'admin_register_screen.dart';
import '../../core/features/admin/admin_dashboard_screen.dart' as modern_admin;

class AdminEntryScreen extends StatelessWidget {
  const AdminEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (AdminAuth.adminKey != null) {
      return const modern_admin.AdminDashboardScreen();
    }
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0E1117), Color(0xFF162033), Color(0xFF0E1117)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  elevation: 10,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.admin_panel_settings, size: 72, color: Colors.blueGrey),
                        const SizedBox(height: 20),
                        const Text(
                          'Espace Admin',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Choisis si tu veux te connecter ou créer un nouvel accès administrateur.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
                            );
                          },
                          icon: const Icon(Icons.login),
                          label: const Text('Se connecter comme admin'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AdminRegisterScreen()),
                            );
                          },
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('Créer un accès admin'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}