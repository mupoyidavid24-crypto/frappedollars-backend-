import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/constants.dart';
import 'api_key_admin_service.dart';

class AdminApiKeysScreen extends StatefulWidget {
  const AdminApiKeysScreen({super.key});

  @override
  State<AdminApiKeysScreen> createState() => _AdminApiKeysScreenState();
}

class _AdminApiKeysScreenState extends State<AdminApiKeysScreen> {
  final TextEditingController _loginController = TextEditingController();
  String _selectedRole = 'CLIENT';
  bool _loading = false;
  Map<String, dynamic>? _generatedKey;
  String? _errorMessage;

  @override
  void dispose() {
    _loginController.dispose();
    super.dispose();
  }

  Future<void> _generateKey() async {
    final mt5Login = _loginController.text.trim();
    if (mt5Login.isEmpty) {
      setState(() {
        _errorMessage = 'Le login MT5 est requis.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _generatedKey = null;
    });

    try {
      final result = await ApiKeyAdminService.generateApiKey(
        mt5Login: mt5Login,
        accountRole: _selectedRole,
      );
      if (!mounted) return;
      setState(() {
        _generatedKey = result;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clé API générée avec succès.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _copyKey(String key) async {
    await Clipboard.setData(ClipboardData(text: key));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Clé copiée dans le presse-papiers.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final generatedKey = _generatedKey?['api_key']?.toString();
    final generatedRole = _generatedKey?['account_role']?.toString();
    final generatedLogin = _generatedKey?['mt5_login']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F14),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF071116), Color(0xFF0C161B), Color(0xFF05080B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Clés API MT5',
                            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Génération des accès master et client pour les EAs',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: const Color(AppConstants.primaryColor).withOpacity(0.12),
                        border: Border.all(color: const Color(AppConstants.primaryColor).withOpacity(0.35)),
                      ),
                      child: const Text(
                        'Backend only',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 900;
                      final generatorPanel = _Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Générateur',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _loginController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Login MT5',
                              ),
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              value: _selectedRole,
                              dropdownColor: const Color(0xFF101821),
                              decoration: const InputDecoration(labelText: 'Rôle'),
                              items: const [
                                DropdownMenuItem(value: 'CLIENT', child: Text('CLIENT')),
                                DropdownMenuItem(value: 'MASTER', child: Text('MASTER')),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedRole = value;
                                });
                              },
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  backgroundColor: const Color(AppConstants.primaryColor),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _loading ? null : _generateKey,
                                icon: _loading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.key),
                                label: const Text('Générer la clé API'),
                              ),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 14),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            ],
                          ],
                        ),
                      );

                      final infoPanel = _Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Résultat',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            if (generatedKey == null)
                              const Text(
                                'La clé générée apparaîtra ici. Elle doit être copiée immédiatement et ajoutée dans le EA MT5.',
                                style: TextStyle(color: Colors.white54),
                              )
                            else ...[
                              _InfoRow(label: 'Login', value: generatedLogin ?? '-'),
                              const SizedBox(height: 8),
                              _InfoRow(label: 'Rôle', value: generatedRole ?? '-'),
                              const SizedBox(height: 8),
                              _InfoRow(label: 'Clé API', value: generatedKey),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _copyKey(generatedKey),
                                      icon: const Icon(Icons.copy),
                                      label: const Text('Copier la clé'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Usage MT5',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'La clé doit être envoyée dans le header x-api-key du master EA ou client EA selon le rôle généré.',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ],
                          ],
                        ),
                      );

                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: generatorPanel),
                            const SizedBox(width: 16),
                            Expanded(child: infoPanel),
                          ],
                        );
                      }

                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            generatorPanel,
                            const SizedBox(height: 16),
                            infoPanel,
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(color: Colors.white54)),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}