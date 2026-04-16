import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/constants/constants.dart';
import '../../core/features/admin/admin_auth.dart';

class AdminActions extends StatefulWidget {
  const AdminActions({super.key});

  @override
  State<AdminActions> createState() => _AdminActionsState();
}

class _AdminActionsState extends State<AdminActions> {
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _paymentMethodController = TextEditingController();
  final TextEditingController _vipClientIdController = TextEditingController();
  final TextEditingController _syncClientIdController = TextEditingController();
  String? _result;

  Future<void> _addPaymentMethod() async {
    final method = {"name": _paymentMethodController.text};
    final response = await http.post(
      Uri.parse('${AppConstants.adminBaseUrl}/add_payment_method'),
      headers: AdminAuth.headers(jsonContent: true),
      body: json.encode(method),
    );
    setState(() {
      _result = response.statusCode == 200 ? 'Moyen de paiement ajouté.' : 'Erreur: ${response.body}';
    });
  }

  Future<void> _blockUser() async {
    final userId = _userIdController.text;
    final response = await http.post(
      Uri.parse('${AppConstants.adminBaseUrl}/block_user/$userId'),
      headers: AdminAuth.headers(),
    );
    setState(() {
      _result = response.statusCode == 200 ? 'Compte bloqué.' : 'Erreur: ${response.body}';
    });
  }

  Future<void> _addVipClient() async {
    final vipId = _vipClientIdController.text;
    final response = await http.post(
      Uri.parse('${AppConstants.adminBaseUrl}/add_vip_client'),
      headers: AdminAuth.headers(jsonContent: true),
      body: json.encode({"id": vipId}),
    );
    setState(() {
      _result = response.statusCode == 200 ? 'Client VIP ajouté.' : 'Erreur: ${response.body}';
    });
  }

  Future<void> _syncWithMaster() async {
    final clientId = _syncClientIdController.text;
    final response = await http.post(
      Uri.parse('${AppConstants.adminBaseUrl}/sync_with_master/$clientId'),
      headers: AdminAuth.headers(),
    );
    setState(() {
      _result = response.statusCode == 200 ? 'Synchronisation réussie.' : 'Erreur: ${response.body}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Actions admin')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _paymentMethodController,
              decoration: const InputDecoration(labelText: 'Nom du moyen de paiement'),
            ),
            ElevatedButton(
              onPressed: _addPaymentMethod,
              child: const Text('Ajouter moyen de paiement'),
            ),
            const Divider(),
            TextField(
              controller: _userIdController,
              decoration: const InputDecoration(labelText: 'ID utilisateur à bloquer'),
            ),
            ElevatedButton(
              onPressed: _blockUser,
              child: const Text('Bloquer compte (sauf VIP)'),
            ),
            const Divider(),
            TextField(
              controller: _vipClientIdController,
              decoration: const InputDecoration(labelText: 'ID client à passer VIP'),
            ),
            ElevatedButton(
              onPressed: _addVipClient,
              child: const Text('Ajouter client VIP'),
            ),
            const Divider(),
            TextField(
              controller: _syncClientIdController,
              decoration: const InputDecoration(labelText: 'ID client à synchroniser avec master'),
            ),
            ElevatedButton(
              onPressed: _syncWithMaster,
              child: const Text('Synchroniser avec compte master'),
            ),
            const SizedBox(height: 16),
            if (AdminAuth.adminKey == null)
              const Text(
                'Aucune clé admin chargée. Renseigne-la dans le dashboard avant d’utiliser les actions.',
                style: TextStyle(color: Colors.orange),
              ),
            if (_result != null) ...[
              const SizedBox(height: 16),
              Text(_result!, style: const TextStyle(color: Colors.blue)),
            ],
          ],
        ),
      ),
    );
  }
}
