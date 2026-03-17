import 'package:flutter/material.dart';

class PaymentForm extends StatefulWidget {
  const PaymentForm({super.key});

  @override
  _PaymentFormState createState() => _PaymentFormState();
}

class _PaymentFormState extends State<PaymentForm> {
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedMethod;
  List<String> _paymentMethods = [];
    @override
    void initState() {
      super.initState();
      _fetchPaymentMethods();
    }

    Future<void> _fetchPaymentMethods() async {
      final client = Supabase.instance.client;
      final response = await client.from('payment_methods').select('name');
      setState(() {
        _paymentMethods = List<String>.from(response.map((e) => e['name']));
        if (_paymentMethods.isNotEmpty) _selectedMethod = _paymentMethods.first;
      });
    }
  String? _proofUrl;
  final String _status = 'En attente de validation';

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
            _paymentMethods.isEmpty
                ? const CircularProgressIndicator()
                : DropdownButton<String>(
                    value: _selectedMethod,
                    items: _paymentMethods
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (val) {
                      setState(() => _selectedMethod = val!);
                    },
                  ),
            const SizedBox(height: 16),
            Text(
              'Instructions : Envoyez ${_amountController.text.isEmpty ? 'X' : _amountController.text} USD à ${_selectedMethod == 'Airtel Money' ? '0977338230' : '0851125664'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                // TODO: upload proof logic
                // Simule un fichier (remplace par la vraie logique de sélection de fichier)
                File? proofFile;
                // TODO: Ajoute la logique pour sélectionner le fichier
                // Appelle le service d'upload avec le moyen de paiement
                final userId = 'user_id'; // Remplace par la vraie logique utilisateur
                if (proofFile != null) {
                  final url = await PaymentUploadService().uploadProof(proofFile, userId, _selectedMethod);
                  setState(() => _proofUrl = url);
                }
              },
              child: Text(_proofUrl == null ? 'Uploader une preuve' : 'Preuve uploadée'),
            ),
            const SizedBox(height: 16),
            Text('Statut : $_status'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // TODO: submit payment logic
              },
              child: const Text('Soumettre paiement'),
            ),
          ],
        ),
      ),
    );
  }
}
