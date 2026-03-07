import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/constants.dart';
import '../auth/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final profile = authProvider.userProfile;

    if (profile == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(title: const Text('Mon Profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // -- HEADER AVATAR --
            const CircleAvatar(
              radius: 50,
              backgroundColor: Color(AppConstants.primaryColor),
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(profile.email, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (profile.isVip)
              const Chip(
                label: Text('STATUT VIP', style: TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: Colors.amber,
              ),
            const SizedBox(height: 32),

            // -- MODE DE TRADING --
            _buildProfileTile(
              title: 'Mode de Trading',
              subtitle: profile.needsVps ? 'Téléphone (VPS)' : 'Ordinateur',
              icon: profile.needsVps ? Icons.phone_android : Icons.laptop,
              trailing: Switch(
                value: profile.needsVps,
                onChanged: (val) async {
                  await Supabase.instance.client
                      .from('profiles')
                      .update({'needs_vps': val})
                      .eq('id', profile.id);
                  // Idéalement, rafraîchir le profil ici
                },
              ),
            ),

            // -- PARRAINAGE --
            _buildProfileTile(
              title: 'Code de Parrainage',
              subtitle: profile.referralCode ?? 'Indisponible',
              icon: Icons.share,
              onTap: () {
                Clipboard.setData(ClipboardData(text: profile.referralCode ?? ""));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copié !')));
              },
            ),

            const SizedBox(height: 24),
            const Divider(),

            // -- ACTIONS --
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Centre d\'aide'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.security),
              title: const Text('Sécurité & Biométrie'),
              onTap: () {},
            ),
            const SizedBox(height: 24),

            // -- LOGOUT --
            ElevatedButton.icon(
              onPressed: () => authProvider.signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('DÉCONNEXION'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.1),
                foregroundColor: Colors.red,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTile({
    required String title,
    required String subtitle,
    required IconData icon,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: const Color(AppConstants.primaryColor)),
        title: Text(title, style: const TextStyle(fontSize: 14, color: Colors.white60)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
