import 'package:flutter/material.dart';
import 'vip_admin_service.dart';

class AdminVIPScreen extends StatefulWidget {
  const AdminVIPScreen({Key? key}) : super(key: key);

  @override
  _AdminVIPScreenState createState() => _AdminVIPScreenState();
}

class _AdminVIPScreenState extends State<AdminVIPScreen> {
  List<Map<String, dynamic>> vipUsers = [];
  bool loading = false;

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
    setState(() { loading = true; });
    try {
      final result = await VIPAdminService.fetchVIPUsers();
      setState(() { vipUsers = result; loading = false; });
    } catch (e) {
      setState(() { loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur chargement VIP'))
      );
    }
  }

  @override
  void initState() {
    super.initState();
    fetchVIPUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestion VIP')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : vipUsers.isEmpty
              ? const Center(child: Text('Aucun VIP'))
              : ListView.builder(
                  itemCount: vipUsers.length,
                  itemBuilder: (context, index) {
                    final u = vipUsers[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: ListTile(
                        leading: Icon(Icons.star, color: u['is_vip'] ? Colors.amber : Colors.grey),
                        title: Text(u['full_name'] ?? ''),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Email: ${u['email']}'),
                            Text('Statut: ${u['is_vip'] ? 'VIP' : 'Normal'}'),
                            Text('Historique: ${u['history'] ?? ''}'),
                          ],
                        ),
                        trailing: Switch(
                          value: u['is_vip'] ?? false,
                          onChanged: (val) => toggleVIP(u['id'], val),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
