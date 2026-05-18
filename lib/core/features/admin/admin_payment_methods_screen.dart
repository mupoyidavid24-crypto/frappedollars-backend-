import 'package:flutter/material.dart';

import 'admin_payment_methods_service.dart';

class AdminPaymentMethodsScreen extends StatefulWidget {
  const AdminPaymentMethodsScreen({super.key});

  @override
  State<AdminPaymentMethodsScreen> createState() => _AdminPaymentMethodsScreenState();
}

class _AdminPaymentMethodsScreenState extends State<AdminPaymentMethodsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = AdminPaymentMethodsService.fetchPaymentMethods();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = AdminPaymentMethodsService.fetchPaymentMethods();
    });
  }

  Future<void> _toggleActive(Map<String, dynamic> method) async {
    final methodId = method['id']?.toString() ?? '';
    if (methodId.isEmpty) return;
    await AdminPaymentMethodsService.updatePaymentMethod(methodId, {
      'provider': method['provider'],
      'label': method['label'],
      'account_name': method['account_name'],
      'account_number': method['account_number'],
      'is_active': method['is_active'] != true,
      'metadata': method['metadata'],
    });
    await _refresh();
  }

  Future<void> _deleteMethod(Map<String, dynamic> method) async {
    final methodId = method['id']?.toString() ?? '';
    if (methodId.isEmpty) return;
    await AdminPaymentMethodsService.deletePaymentMethod(methodId);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moyens de paiement'),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          final methods = snapshot.data ?? const <Map<String, dynamic>>[];
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: methods.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final method = methods[index];
              return Card(
                child: ListTile(
                  title: Text(method['label']?.toString() ?? 'Moyen de paiement'),
                  subtitle: Text('${method['provider'] ?? '-'} • ${method['account_number'] ?? '-'}'),
                  trailing: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Chip(label: Text(method['is_active'] == true ? 'Actif' : 'Inactif')),
                      IconButton(
                        tooltip: 'Basculer',
                        onPressed: () => _toggleActive(method),
                        icon: const Icon(Icons.swap_horiz),
                      ),
                      IconButton(
                        tooltip: 'Supprimer',
                        onPressed: () => _deleteMethod(method),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
