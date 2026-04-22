import 'package:flutter/material.dart';

class PaymentForm extends StatefulWidget {
  const PaymentForm({super.key});

  @override
  State<PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<PaymentForm> {
  static const String _paymentMethodName = 'Airtel Money';
  static const String _paymentNumber = '+243977338230';

  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  final String _status = 'En attente de validation';

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paiement local')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Montant à payer'),
            ),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Numéro de téléphone'),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Moyen de paiement'),
                subtitle: Text('$_paymentMethodName - $_paymentNumber'),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Instructions : Envoyez ${_amountController.text.isEmpty ? 'X' : _amountController.text} USD à $_paymentNumber via $_paymentMethodName.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Paiement Airtel sélectionné. Joins la preuve via le flux de validation.'),
                  ),
                );
              },
              child: const Text('Continuer'),
            ),
            const SizedBox(height: 16),
            Text('Statut : $_status'),
          ],
        ),
      ),
    );
  }
}
