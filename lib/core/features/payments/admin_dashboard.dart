import 'package:flutter/material.dart';

class AdminPaymentsDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: fetch payments from backend
    return Scaffold(
      appBar: AppBar(title: Text('Dashboard Paiements')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // TODO: filters (date, moyen, statut)
            Expanded(
              child: ListView.builder(
                itemCount: 10, // TODO: replace with payments.length
                itemBuilder: (context, index) {
                  // TODO: replace with real payment data
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Icon(Icons.person)),
                      title: Text('Client Nom/Email'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Montant: 100 USD'),
                          Text('Moyen: Airtel Money'),
                          Text('Numéro: 0977338230'),
                          Text('Date: 2026-03-07'),
                          Text('Statut: En attente'),
                          Text('Preuve: voir capture'),
                        ],
                      ),
                      trailing: Column(
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              // TODO: validate payment
                            },
                            child: Text('Valider'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              // TODO: refuse payment
                            },
                            child: Text('Refuser'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // TODO: export CSV logic
              },
              child: Text('Exporter CSV'),
            ),
          ],
        ),
      ),
    );
  }
}
