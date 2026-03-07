import 'package:flutter/material.dart';
import 'payment_admin_service.dart';

class AdminPaymentsScreen extends StatefulWidget {
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
    setState(() { loading = true; });
    try {
      final result = await PaymentAdminService.fetchPayments();
      setState(() {
        payments = filterStatus == 'TOUS'
            ? result
            : result.where((p) => p['status'] == filterStatus).toList();
        loading = false;
      });
    } catch (e) {
      setState(() { loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void validatePayment(String paymentId) async {
    try {
      final ok = await PaymentAdminService.validatePayment(paymentId);
      if (ok) {
        fetchPayments();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Paiement validé')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void refusePayment(String paymentId, String motif) async {
    try {
      final ok = await PaymentAdminService.refusePayment(paymentId, motif);
      if (ok) {
        fetchPayments();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Paiement refusé')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestion des paiements'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() { filterStatus = value; });
              // fetchPayments();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'TOUS', child: Text('Tous')), 
              PopupMenuItem(value: 'EN_ATTENTE', child: Text('En attente')), 
              PopupMenuItem(value: 'VALIDATED', child: Text('Validés')), 
              PopupMenuItem(value: 'REFUSED', child: Text('Refusés')),
            ],
            icon: Icon(Icons.filter_list),
          ),
        ],
      ),
        body: loading
          ? Center(child: CircularProgressIndicator())
          : payments.isEmpty
            ? Center(child: Text('Aucun paiement'))
            : ListView.builder(
              itemCount: payments.length,
              itemBuilder: (context, index) {
              final p = payments[index];
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: ListTile(
                    leading: Icon(Icons.receipt_long),
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
                            child: Text('Voir preuve'),
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
                            icon: Icon(Icons.check, color: Colors.green),
                            tooltip: 'Valider',
                            onPressed: () => validatePayment(p['id']),
                          ),
                        if (p['status'] == 'EN_ATTENTE')
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.red),
                            tooltip: 'Refuser',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  String motif = '';
                                  return AlertDialog(
                                    title: Text('Motif du refus'),
                                    content: TextField(
                                      onChanged: (v) => motif = v,
                                      decoration: InputDecoration(hintText: 'Motif'),
                                    ),
                                    actions: [
                                      TextButton(
                                        child: Text('Annuler'),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                      TextButton(
                                        child: Text('Refuser'),
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
