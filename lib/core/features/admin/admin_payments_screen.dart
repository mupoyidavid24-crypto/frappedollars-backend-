import 'package:flutter/material.dart';
import 'payment_admin_service.dart';

class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  _AdminPaymentsScreenState createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  List<Map<String, dynamic>> payments = [];
  String filterStatus = 'TOUS';
  bool loading = false;

  @override
  void initState() {
    super.initState();
    fetchPayments();
  }

  void fetchPayments() async {
    setState(() {
      loading = true;
    });
    try {
      final result = await PaymentAdminService.fetchPayments();
      setState(() {
        payments = filterStatus == 'TOUS'
            ? result
            : result.where((p) => p['status'] == filterStatus).toList();
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void validatePayment(String paymentId) async {
    try {
      final ok = await PaymentAdminService.validatePayment(paymentId);
      if (ok) {
        fetchPayments();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Paiement validé')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void refusePayment(String paymentId, String motif) async {
    try {
      final ok = await PaymentAdminService.refusePayment(paymentId, motif);
      if (ok) {
        fetchPayments();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Paiement refusé')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des paiements'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                filterStatus = value;
              });
              // fetchPayments();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'TOUS', child: Text('Tous')),
              const PopupMenuItem(
                  value: 'EN_ATTENTE', child: Text('En attente')),
              const PopupMenuItem(value: 'VALIDATED', child: Text('Validés')),
              const PopupMenuItem(value: 'REFUSED', child: Text('Refusés')),
            ],
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : payments.isEmpty
              ? const Center(child: Text('Aucun paiement'))
              : ListView.builder(
                  itemCount: payments.length,
                  itemBuilder: (context, index) {
                    final p = payments[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      child: ListTile(
                        leading: const Icon(Icons.receipt_long),
                        title: Text('Montant: ${p['amount']}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Utilisateur: ${p['user_id']}'),
                            Text('Méthode: ${p['method']}'),
                            Text('Statut: ${p['status']}'),
                            Text('Date: ${p['created_at']}'),
                            if (p['proof_url'] != null)
                              TextButton(
                                child: const Text('Voir preuve'),
                                onPressed: () {
                                  // TODO: open proof URL
                                },
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (p['status'] == 'EN_ATTENTE')
                              IconButton(
                                icon: const Icon(Icons.check,
                                    color: Colors.green),
                                tooltip: 'Valider',
                                onPressed: () => validatePayment(p['id']),
                              ),
                            if (p['status'] == 'EN_ATTENTE')
                              IconButton(
                                icon:
                                    const Icon(Icons.close, color: Colors.red),
                                tooltip: 'Refuser',
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      String motif = '';
                                      return AlertDialog(
                                        title: const Text('Motif du refus'),
                                        content: TextField(
                                          onChanged: (v) => motif = v,
                                          decoration: const InputDecoration(
                                              hintText: 'Motif'),
                                        ),
                                        actions: [
                                          TextButton(
                                            child: const Text('Annuler'),
                                            onPressed: () =>
                                                Navigator.pop(context),
                                          ),
                                          TextButton(
                                            child: const Text('Refuser'),
                                            onPressed: () {
                                              refusePayment(p['id'], motif);
                                              Navigator.pop(context);
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
