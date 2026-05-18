import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_settings_provider.dart';
import '../../../models/app_settings_model.dart';

class AdminBrandingScreen extends StatefulWidget {
  const AdminBrandingScreen({super.key});

  @override
  State<AdminBrandingScreen> createState() => _AdminBrandingScreenState();
}

class _AdminBrandingScreenState extends State<AdminBrandingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _appNameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _logoUrlController = TextEditingController();
  final _primaryColorController = TextEditingController();
  final _backgroundColorController = TextEditingController();
  final _supportEmailController = TextEditingController();
  final _supportPhoneController = TextEditingController();
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _appNameController.dispose();
    _taglineController.dispose();
    _logoUrlController.dispose();
    _primaryColorController.dispose();
    _backgroundColorController.dispose();
    _supportEmailController.dispose();
    _supportPhoneController.dispose();
    super.dispose();
  }

  void _seedControllers(AppSettings settings) {
    _appNameController.text = settings.appName;
    _taglineController.text = settings.tagline;
    _logoUrlController.text = settings.logoUrl ?? '';
    _primaryColorController.text = settings.primaryColorHex;
    _backgroundColorController.text = settings.backgroundColorHex;
    _supportEmailController.text = settings.supportEmail ?? '';
    _supportPhoneController.text = settings.supportPhone ?? '';
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    final provider = context.read<AppSettingsProvider>();
    final current = provider.settings;
    try {
      await provider.update(
        current.copyWith(
          appName: _appNameController.text.trim(),
          tagline: _taglineController.text.trim(),
          logoUrl: _logoUrlController.text.trim().isEmpty ? null : _logoUrlController.text.trim(),
          primaryColorHex: _primaryColorController.text.trim(),
          backgroundColorHex: _backgroundColorController.text.trim(),
          supportEmail: _supportEmailController.text.trim().isEmpty ? null : _supportEmailController.text.trim(),
          supportPhone: _supportPhoneController.text.trim().isEmpty ? null : _supportPhoneController.text.trim(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Identité de l’application mise à jour.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur branding: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppSettingsProvider>();
    final settings = provider.settings;
    if (!_initialized) {
      _seedControllers(settings);
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Branding application'),
        actions: [
          IconButton(
            onPressed: provider.isLoading ? null : () => provider.refresh(),
            icon: const Icon(Icons.refresh),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Sauvegarder'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.white.withOpacity(0.04),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: settings.primaryColor.withOpacity(0.15),
                      child: settings.logoUrl != null && settings.logoUrl!.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                settings.logoUrl!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(Icons.image_outlined, color: settings.primaryColor),
                              ),
                            )
                          : Icon(Icons.public, color: settings.primaryColor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(settings.appName, style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(settings.tagline, style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _appNameController,
                    decoration: const InputDecoration(labelText: 'Nom de l’application', prefixIcon: Icon(Icons.title)),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Nom requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _taglineController,
                    decoration: const InputDecoration(labelText: 'Slogan', prefixIcon: Icon(Icons.short_text)),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Slogan requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _logoUrlController,
                    decoration: const InputDecoration(labelText: 'URL du logo', prefixIcon: Icon(Icons.image_outlined)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _primaryColorController,
                          decoration: const InputDecoration(labelText: 'Couleur principale', prefixIcon: Icon(Icons.palette_outlined)),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Couleur requise' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _backgroundColorController,
                          decoration: const InputDecoration(labelText: 'Couleur fond', prefixIcon: Icon(Icons.wallpaper_outlined)),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Couleur requise' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _supportEmailController,
                          decoration: const InputDecoration(labelText: 'Email support', prefixIcon: Icon(Icons.email_outlined)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _supportPhoneController,
                          decoration: const InputDecoration(labelText: 'Téléphone support', prefixIcon: Icon(Icons.phone_outlined)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
