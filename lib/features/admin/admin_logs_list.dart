import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/constants/constants.dart';
import '../../core/features/admin/admin_auth.dart';

class AdminLogsList extends StatefulWidget {
  const AdminLogsList({super.key});

  @override
  State<AdminLogsList> createState() => _AdminLogsListState();
}

class _AdminLogsListState extends State<AdminLogsList> {
  bool _isLoading = true;
  List<dynamic> _logs = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await http.get(Uri.parse('${AppConstants.adminBaseUrl}/logs'), headers: AdminAuth.headers());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _logs = data['logs'] ?? [];
        });
      } else {
        setState(() {
          _error = 'Erreur serveur: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur réseau: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    if (_logs.isEmpty) {
      return const Center(child: Text('Aucun log trouvé.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _logs.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final log = _logs[index];
        return ListTile(
          leading: const Icon(Icons.warning),
          title: Text(log.toString()),
        );
      },
    );
  }
}
