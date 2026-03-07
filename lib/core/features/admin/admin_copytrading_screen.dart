import 'package:flutter/material.dart';
import 'copytrading_admin_service.dart';

class AdminCopyTradingScreen extends StatefulWidget {
  @override
  _AdminCopyTradingScreenState createState() => _AdminCopyTradingScreenState();
}

  bool isActive = false;
  List<Map<String, dynamic>> history = [];
  bool loading = false;

  void toggleCopyTrading(String clientId) async {
    setState(() { loading = true; });
    final ok = await CopyTradingAdminService.toggleCopyTrading(clientId);
    setState(() { loading = false; });
    if (ok) {
      setState(() { isActive = !isActive; });
      fetchHistory();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copy trading synchronisé')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur synchronisation')));
    }
  }
  void fetchHistory() async {
    setState(() { loading = true; });
    try {
      final result = await CopyTradingAdminService.fetchHistory();
      setState(() { history = result; loading = false; });
    } catch (e) {
      setState(() { loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur chargement historique')));
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
      appBar: AppBar(title: Text('Copy Trading')), 
      body: loading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SwitchListTile(
                  title: Text('Statut Copy Trading'),
                  value: isActive,
                  onChanged: (val) => toggleCopyTrading('client_id'), // Remplacer par l'ID réel
                ),
                Divider(),
                Expanded(
                  child: history.isEmpty
                      ? Center(child: Text('Aucun historique'))
                      : ListView.builder(
                          itemCount: history.length,
                          itemBuilder: (context, index) {
                            final h = history[index];
                            return ListTile(
                              leading: Icon(Icons.sync_alt),
                              title: Text(h['action'] ?? ''),
                              subtitle: Text('Date: ${h['date']}'),
                            );
                          },
                        ),
                ),
              ],
            ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
