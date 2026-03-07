import 'package:flutter/material.dart';

class PaymentForm extends StatefulWidget {
  @override
  _PaymentFormState createState() => _PaymentFormState();
}

class _PaymentFormState extends State<PaymentForm> {
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedMethod = 'Airtel Money';
  String? _proofUrl;
  String _status = 'En attente de validation';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Paiement local')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Montant à payer'),
            ),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: 'Numéro de téléphone'),
            ),
            SizedBox(height: 16),
            DropdownButton<String>(
              value: _selectedMethod,
              items: ['Airtel Money', 'Orange Money']
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (val) {
                setState(() => _selectedMethod = val!);
              },
            ),
            SizedBox(height: 16),
            Text(
              'Instructions : Envoyez ${_amountController.text.isEmpty ? 'X' : _amountController.text} USD à ${_selectedMethod == 'Airtel Money' ? '0977338230' : '0851125664'}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // TODO: upload proof logic
              },
              child: Text(_proofUrl == null ? 'Uploader une preuve' : 'Preuve uploadée'),
            ),
            SizedBox(height: 16),
            Text('Statut : $_status'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // TODO: submit payment logic
              },
              child: Text('Soumettre paiement'),
            ),
          ],
        ),
      ),
    );
  }
}
