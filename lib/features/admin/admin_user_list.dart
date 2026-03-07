import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminUserList extends StatefulWidget {
  const AdminUserList({super.key});

  @override
  State<AdminUserList> createState() => _AdminUserListState();
}

class _AdminUserListState extends State<AdminUserList> {
  bool _isLoading = true;
  List<dynamic> _users = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await http.get(Uri.parse('http://localhost:8000/admin/users'));
      if (response.statusCode == 200) {
        setState(() {
          _users = json.decode(response.body);
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
    if (_users.isEmpty) {
      return const Center(child: Text('Aucun utilisateur trouvé.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final user = _users[index];
        return ListTile(
          leading: const Icon(Icons.person),
          title: Text(user['full_name'] ?? user['email'] ?? 'Utilisateur'),
          subtitle: Text('Role: ${user['role']} | VIP: ${user['is_vip'] ? "Oui" : "Non"}'),
          trailing: Text(user['created_at']?.toString() ?? ''),
        );
      },
    );
  }
}
