import 'package:flutter/material.dart';
import 'logs_admin_service.dart';

class AdminLogsScreen extends StatefulWidget {
  @override
  _AdminLogsScreenState createState() => _AdminLogsScreenState();
}

  List<Map<String, dynamic>> logs = [];
  bool loading = false;
  void fetchLogs() async {
    setState(() { loading = true; });
    try {
      final result = await LogsAdminService.fetchLogs();
      setState(() { logs = result; loading = false; });
    } catch (e) {
      setState(() { loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur chargement logs')));
    }
  }

  @override
  void initState() {
    super.initState();
    fetchLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Journalisation Admin')),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : logs.isEmpty
              ? Center(child: Text('Aucun log'))
              : ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final l = logs[index];
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: ListTile(
                        leading: Icon(Icons.list_alt),
                        title: Text('Action: ${l['action']}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Admin: ${l['admin_id']}'),
                            Text('Date: ${l['timestamp']}'),
                            Text('IP: ${l['ip_address']}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
