import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/constants.dart';
import '../../core/services/business_rules_service.dart';
import '../../models/business_rules_model.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;
  bool _isFetchingTickets = false;
  Timer? _refreshTimer;
  List<Map<String, dynamic>> _tickets = [];
  BusinessRules? _businessRules;

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadTickets();
    _loadBusinessRules();
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) => _loadTickets());
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

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    if (_isFetchingTickets || !mounted) return;
    final userId = _currentUserId;
    if (userId == null) return;

    _isFetchingTickets = true;
    try {
      final response = await Supabase.instance.client
          .from('support_tickets')
          .select('id, subject, message, status, admin_response, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _tickets = List<Map<String, dynamic>>.from(response as List);
      });
    } catch (e) {
      debugPrint('Support tickets refresh error: $e');
    } finally {
      _isFetchingTickets = false;
    }
  }

  Future<void> _submitTicket() async {
    if (_subjectController.text.isEmpty || _messageController.text.isEmpty) return;
    final userId = _currentUserId;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session non disponible. Recharge la page.')),
        );
      }
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.from('support_tickets').insert({
        'user_id': userId,
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
        'status': 'OPEN',
      });
      
      _subjectController.clear();
      _messageController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message envoyé au support !')),
        );
        _loadTickets();
      }
    } catch (e) {
      debugPrint("Support Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _currentUserId;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Support Client')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Chargement de la session support...\nSi l’écran reste vide, recharge la page.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Support Client')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
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
          const SizedBox(height: 12),
          // -- LIST OF TICKETS (REALTIME) --
          Expanded(
            child: _tickets.isEmpty
                ? const Center(child: Text('Aucun ticket trouvé.'))
                : ListView.builder(
                    itemCount: _tickets.length,
                    itemBuilder: (context, index) {
                      final ticket = _tickets[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ExpansionTile(
                          title: Text(ticket['subject']?.toString() ?? ''),
                          subtitle: Text('Status: ${ticket['status']}'),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Votre message :', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text(ticket['message']?.toString() ?? ''),
                                  if (ticket['admin_response'] != null) ...[
                                    const Divider(),
                                    const Text('Réponse Support :', style: TextStyle(fontWeight: FontWeight.bold, color: Color(AppConstants.primaryColor))),
                                    Text(ticket['admin_response']),
                                  ]
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
          ),
          
          // -- INPUT FORM --
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _subjectController,
                  decoration: const InputDecoration(labelText: 'Sujet', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _messageController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Message...', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppConstants.primaryColor),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('ENVOYER'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
