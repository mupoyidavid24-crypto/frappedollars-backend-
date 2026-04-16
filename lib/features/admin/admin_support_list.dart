import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/constants/constants.dart';
import '../../core/features/admin/admin_auth.dart';

class AdminSupportList extends StatefulWidget {
  const AdminSupportList({super.key});

  @override
  State<AdminSupportList> createState() => _AdminSupportListState();
}

class _AdminSupportListState extends State<AdminSupportList> {
  bool _isLoading = true;
  List<dynamic> _tickets = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await http.get(Uri.parse('${AppConstants.adminBaseUrl}/support_tickets'), headers: AdminAuth.headers());
      if (response.statusCode == 200) {
        setState(() {
          _tickets = json.decode(response.body);
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
    if (_tickets.isEmpty) {
      return const Center(child: Text('Aucun ticket trouvé.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _tickets.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final ticket = _tickets[index];
        return ListTile(
          leading: const Icon(Icons.support_agent),
          title: Text(ticket['subject'] ?? 'Ticket'),
          subtitle: Text(ticket['status'] ?? ''),
          trailing: Text(ticket['created_at']?.toString() ?? ''),
        );
      },
    );
  }
}
