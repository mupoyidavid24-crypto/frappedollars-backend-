import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/constants.dart';
import '../../core/services/kyc_service.dart';
import '../../models/profile_model.dart';
import 'auth_provider.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _documentNumberController = TextEditingController();
  final KycService _kycService = KycService();

  String _documentType = 'NATIONAL_ID';
  bool _isSubmitting = false;
  bool _isRefreshing = false;
  DateTime? _dateOfBirth;
  PlatformFile? _pickedDocument;

  @override
  void dispose() {
    _addressController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _documentNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    try {
      final document = await _kycService.pickDocument();
      if (!mounted) return;
      setState(() => _pickedDocument = document);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur sélection fichier: $e')),
      );
    }
  }

  Future<void> _pickDateOfBirth() async {
    final profile = context.read<AuthProvider>().userProfile;
    final now = DateTime.now();
    final initialDate = _dateOfBirth ?? profile?.dateOfBirth ?? DateTime(now.year - 18, now.month, now.day);
    final lastAllowedDate = DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(lastAllowedDate) ? lastAllowedDate : initialDate,
      firstDate: DateTime(1940),
      lastDate: lastAllowedDate,
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() => _dateOfBirth = picked);
  }

  Future<void> _refreshProfile() async {
    setState(() => _isRefreshing = true);
    await context.read<AuthProvider>().refreshProfile();
    if (!mounted) return;
    setState(() => _isRefreshing = false);
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final pickedDocument = _pickedDocument;
    if (pickedDocument == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez joindre une pièce d\'identité.')),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final profile = authProvider.userProfile;
    final dateOfBirth = _dateOfBirth ?? profile?.dateOfBirth;
    if (profile == null || dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez renseigner une date de naissance valide.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _kycService.submitKyc(
        userId: profile.id,
        fullName: profile.fullName ?? '',
        phoneNumber: profile.phoneNumber ?? '',
        dateOfBirth: dateOfBirth,
        addressLine: _addressController.text.trim(),
        country: _countryController.text.trim(),
        city: _cityController.text.trim(),
        documentType: _documentType,
        documentNumber: _documentNumberController.text.trim().isEmpty ? null : _documentNumberController.text.trim(),
        document: pickedDocument,
      );

      await authProvider.refreshProfile();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('KYC soumis. Validation en attente de vérification.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur KYC: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final profile = authProvider.userProfile;

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final kycStatus = profile.kycStatus.name.toUpperCase();
    final statusMessage = switch (profile.kycStatus) {
      KycStatus.approved => 'Vérification approuvée. Votre accès au copy trading est débloqué.',
      KycStatus.rejected => 'Vérification refusée. Corrigez vos informations et soumettez à nouveau.',
      KycStatus.pending => 'Votre dossier est en cours de vérification.',
      KycStatus.notSubmitted => 'Complétez la vérification KYC pour activer le copy trading.',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérification KYC'),
        actions: [
          IconButton(
            onPressed: _isRefreshing ? null : _refreshProfile,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authProvider.signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2A1B0F), Color(0xFF111111)],
                  ),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Phase 2 - Vérification KYC',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      statusMessage,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    Chip(label: Text(kycStatus)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Adresse complète',
                  prefixIcon: Icon(Icons.home_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Adresse requise' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _countryController,
                      decoration: const InputDecoration(
                        labelText: 'Pays',
                        prefixIcon: Icon(Icons.public_outlined),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Pays requis' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'Ville',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Ville requise' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDateOfBirth,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date de naissance',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                  child: Text(
                    (_dateOfBirth ?? profile.dateOfBirth) == null
                        ? 'Sélectionner votre date de naissance'
                        : '${(_dateOfBirth ?? profile.dateOfBirth)!.year.toString().padLeft(4, '0')}-${(_dateOfBirth ?? profile.dateOfBirth)!.month.toString().padLeft(2, '0')}-${(_dateOfBirth ?? profile.dateOfBirth)!.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _documentNumberController,
                decoration: const InputDecoration(
                  labelText: 'Numéro du document',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _documentType,
                decoration: const InputDecoration(
                  labelText: 'Type de document',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'NATIONAL_ID', child: Text('Carte nationale')),
                  DropdownMenuItem(value: 'VOTER_ID', child: Text('Carte d\'électeur')),
                  DropdownMenuItem(value: 'PASSPORT', child: Text('Passeport')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _documentType = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickDocument,
                icon: const Icon(Icons.upload_file),
                label: Text(
                  _pickedDocument == null
                      ? 'Joindre une pièce d\'identité'
                      : 'Fichier sélectionné',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Le fichier doit être lisible et correspondre à votre identité. L\'accès au copy trading reste bloqué tant que le statut n\'est pas approuvé.',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(AppConstants.primaryColor),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Soumettre le KYC'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}