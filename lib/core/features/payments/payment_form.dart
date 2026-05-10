import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/constants.dart';
import 'payment_upload_service.dart';

class PaymentForm extends StatefulWidget {
  final String paymentType;
  final double expectedAmount;
  final String? fullName;
  final String? phoneNumber;

  const PaymentForm({
    super.key,
    required this.paymentType,
    required this.expectedAmount,
    this.fullName,
    this.phoneNumber,
  });

  @override
  State<PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<PaymentForm> {
  static const List<_PaymentDestination> _destinations = [
    _PaymentDestination(number: '0856425342', name: 'JACQUE'),
    _PaymentDestination(number: '0977338230', name: 'JACQUE'),
  ];

  final PaymentUploadService _uploadService = PaymentUploadService();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _payerPhoneController = TextEditingController();

  PlatformFile? _proofFile;
  String _selectedDestination = _destinations.first.number;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fullNameController.text = widget.fullName ?? '';
    _amountController.text = widget.expectedAmount.toStringAsFixed(0);
    _payerPhoneController.text = widget.phoneNumber ?? '';
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _amountController.dispose();
    _payerPhoneController.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) {
      return;
    }
    setState(() {
      _proofFile = result.files.first;
    });
  }

  Future<void> _submit() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final session = client.auth.currentSession;
    if (user == null || session == null) {
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Montant invalide.')));
      return;
    }

    if (_payerPhoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le numéro utilisé est obligatoire.')));
      return;
    }

    if (_proofFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajoutez une preuve de paiement.')));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final proofUrl = await _uploadService.uploadProof(_proofFile!, user.id);
      if (proofUrl == null) {
        throw Exception('Téléversement de la preuve impossible.');
      }

      final response = await http.post(
        Uri.parse('${AppConstants.backendBaseUrl}/payments/manual_request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          'user_id': user.id,
          'payment_type': widget.paymentType,
          'amount': amount,
          'payer_phone': _payerPhoneController.text.trim(),
          'destination_number': _selectedDestination,
          'proof_url': proofUrl,
        }),
      );

      if (response.statusCode >= 400) {
        final decoded = jsonDecode(response.body);
        final message = decoded is Map && decoded['detail'] != null ? decoded['detail'].toString() : response.body;
        throw Exception(message);
      }

      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demande envoyée. En attente de validation admin.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paiement Mobile Money')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Effectuez le paiement puis soumettez la preuve',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Numéros autorisés pour le dépôt Mobile Money.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ..._destinations.map(
              (destination) => Card(
                color: const Color(0xFF111B24),
                child: ListTile(
                  leading: const Icon(Icons.phone_android, color: Colors.white),
                  title: Text(destination.number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  subtitle: Text(destination.name, style: const TextStyle(color: Colors.white70)),
                  trailing: TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedDestination = destination.number;
                      });
                    },
                    child: Text(
                      _selectedDestination == destination.number ? 'Sélectionné' : 'Utiliser',
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(labelText: 'Nom complet'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Montant payé',
                hintText: widget.expectedAmount.toStringAsFixed(0),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _payerPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Numéro utilisé'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickProof,
              icon: const Icon(Icons.image_outlined),
              label: Text(_proofFile == null ? 'Joindre une preuve (image)' : 'Preuve sélectionnée'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Envoyer la demande'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Statut attendu: PENDING_VALIDATION',
              style: TextStyle(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentDestination {
  final String number;
  final String name;

  const _PaymentDestination({required this.number, required this.name});
}