import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/constants.dart';
import '../../core/services/business_rules_service.dart';
import '../../models/business_rules_model.dart';
import 'dashboard_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  bool _isLoading = false;
  BusinessRules? _businessRules;

  @override
  void initState() {
    super.initState();
    _loadBusinessRules();
  }

  Future<void> _loadBusinessRules() async {
    final rules = await BusinessRulesService.instance.fetchBusinessRules();
    if (!mounted) {
      return;
    }
    setState(() {
      _businessRules = rules;
    });
  }

  Future<void> _selectMode(bool needsVps) async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('kyc_status, kyc_blocked')
          .eq('id', userId)
          .maybeSingle();
      final profile = profileResponse;
      final kycStatus = (profile?['kyc_status']?.toString() ?? 'PENDING').toUpperCase();
      final kycBlocked = profile?['kyc_blocked'] ?? true;
      if (AppConstants.kycRequired && (kycStatus != 'APPROVED' || kycBlocked == true)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('KYC temporairement désactivé.')));
      }

      await Supabase.instance.client
          .from('profiles')
          .update({'needs_vps': needsVps})
          .eq('id', userId);
      
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Comment allez-vous trader ?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              _buildOptionCard(
                title: 'J\'ai un ordinateur',
                subtitle: 'Installation de l\'EA manuelle.\nHébergement gratuit.',
                icon: Icons.laptop,
                onTap: () => _selectMode(false),
              ),
              const SizedBox(height: 24),
              _buildOptionCard(
                title: 'J\'utilise mon téléphone',
                subtitle: _businessRules == null
                    ? 'Installation sur nos serveurs.\nChargement des règles commerciales...'
                    : 'Installation sur nos serveurs.\nHébergement VPS : ${_businessRules!.vpsMonthlyPrice.toStringAsFixed(0)}\$/mois.',
                icon: Icons.phone_android,
                onTap: () => _selectMode(true),
                highlight: true,
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  _businessRules?.weeklyProfitLimitLabel ??
                      'Limite technique de protection: la copie s\'arrete automatiquement lorsque le profit hebdomadaire atteint 120 USD.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              if (_isLoading) ...[
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: highlight ? const Color(AppConstants.primaryColor).withValues(red: 255, green: 255, blue: 255, alpha: 100) : Colors.white10,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlight ? const Color(AppConstants.primaryColor) : Colors.white24,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 40, color: highlight ? const Color(AppConstants.primaryColor) : Colors.white),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(color: Colors.white60)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
