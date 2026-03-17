import 'package:flutter/material.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Copy Trading')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _clientIdController,
                    decoration: const InputDecoration(
                      labelText: 'ID du client à synchroniser',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Statut Copy Trading'),
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
                const Divider(),
                Expanded(
                  child: history.isEmpty
                      ? const Center(child: Text('Aucun historique'))
                      : ListView.builder(
                          itemCount: history.length,
                          itemBuilder: (context, index) {
                            final h = history[index];
                            return ListTile(
                              leading: const Icon(Icons.sync_alt),
                              title: Text(h['action'] ?? ''),
                              subtitle: Text('Date: ${h['date']}'),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
