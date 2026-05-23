import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/constants.dart';
import 'payment_admin_service.dart';

class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  _AdminPaymentsScreenState createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  List<Map<String, dynamic>> payments = [];
  String filterStatus = 'TOUS';
  bool loading = false;
  bool _isFetchingPayments = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    fetchPayments();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) {
        fetchPayments();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void fetchPayments() async {
    if (_isFetchingPayments) return;
    _isFetchingPayments = true;
    setState(() {
      loading = true;
    });
    try {
      final result = await PaymentAdminService.fetchPayments();
      if (!mounted) return;
      setState(() {
        payments = filterStatus == 'TOUS'
            ? result
            : result.where((p) => _paymentStatusOf(p) == filterStatus).toList();
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void validatePayment(String paymentId) async {
    try {
      final ok = await PaymentAdminService.validatePayment(paymentId);
      if (ok) {
        fetchPayments();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Paiement validé')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void refusePayment(String paymentId, String motif) async {
    try {
      final ok = await PaymentAdminService.refusePayment(paymentId, motif);
      if (ok) {
        fetchPayments();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Paiement refusé')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
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
                _HeaderRow(
                  title: 'Gestion des paiements',
                  subtitle: 'Validation, refus et suivi des dépôts',
                  action: PopupMenuButton<String>(
                    onSelected: (value) {
                      setState(() {
                        filterStatus = value;
                      });
                      fetchPayments();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'TOUS', child: Text('Tous')),
                      PopupMenuItem(value: 'PENDING_VALIDATION', child: Text('En attente')),
                      PopupMenuItem(value: 'APPROVED', child: Text('Approuvés')),
                      PopupMenuItem(value: 'REJECTED', child: Text('Rejetés')),
                    ],
                    icon: const Icon(Icons.filter_list, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatPill(label: 'Total', value: '${payments.length}'),
                    _StatPill(label: 'En attente', value: '${payments.where((p) => _paymentStatusOf(p) == 'PENDING_VALIDATION').length}'),
                    _StatPill(label: 'Approuvés', value: '${payments.where((p) => _paymentStatusOf(p) == 'APPROVED').length}'),
                    _StatPill(label: 'Rejetés', value: '${payments.where((p) => _paymentStatusOf(p) == 'REJECTED').length}'),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator(color: Color(AppConstants.primaryColor)))
                      : payments.isEmpty
                          ? const Center(
                              child: Text('Aucun paiement', style: TextStyle(color: Colors.white60)),
                            )
                          : ListView.separated(
                              itemCount: payments.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final p = payments[index];
                                return _PaymentCard(
                                  payment: p,
                                  onValidate: () => validatePayment(p['id']),
                                  onRefuse: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        String motif = '';
                                        return AlertDialog(
                                          backgroundColor: const Color(0xFF101821),
                                          title: const Text('Motif du refus', style: TextStyle(color: Colors.white)),
                                          content: TextField(
                                            style: const TextStyle(color: Colors.white),
                                            onChanged: (v) => motif = v,
                                            decoration: const InputDecoration(hintText: 'Motif'),
                                          ),
                                          actions: [
                                            TextButton(
                                              child: const Text('Annuler'),
                                              onPressed: () => Navigator.pop(context),
                                            ),
                                            TextButton(
                                              child: const Text('Refuser'),
                                              onPressed: () {
                                                refusePayment(p['id'], motif);
                                                Navigator.pop(context);
                                              },
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
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

  String _paymentStatusOf(Map<String, dynamic> p) => (p['payment_status'] ?? p['status'])?.toString().toUpperCase() ?? '';
}

class _HeaderRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget action;

  const _HeaderRow({required this.title, required this.subtitle, required this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          backgroundColor: Color(AppConstants.primaryColor),
          child: Icon(Icons.payment, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: Colors.white54)),
            ],
          ),
        ),
        action,
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;

  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final VoidCallback onValidate;
  final VoidCallback onRefuse;

  const _PaymentCard({required this.payment, required this.onValidate, required this.onRefuse});

  String get _status => (payment['payment_status'] ?? payment['status'])?.toString().toUpperCase() ?? '';

  Color get _statusColor {
    switch (_status) {
      case 'APPROVED':
        return const Color(0xFF3EE7B6);
      case 'REJECTED':
        return const Color(0xFFFF7C7C);
      default:
        return const Color(0xFFFFD66B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: _statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.receipt_long, color: _statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Montant: ${payment['montant'] ?? payment['amount']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Utilisateur: ${payment['client'] ?? payment['user_id']}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: _statusColor.withOpacity(0.14),
                  border: Border.all(color: _statusColor.withOpacity(0.35)),
                ),
                child: Text(_status, style: TextStyle(color: _statusColor, fontWeight: FontWeight.w700, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Type: ${payment['payment_type'] ?? 'n/a'}', style: const TextStyle(color: Colors.white70)),
          Text('Moyen: ${payment['moyen'] ?? 'Mobile Money'}', style: const TextStyle(color: Colors.white70)),
          Text('Numéro utilisé: ${payment['payer_phone'] ?? payment['numero'] ?? 'n/a'}', style: const TextStyle(color: Colors.white70)),
          Text('Numéro destinataire: ${payment['recipient_number'] ?? payment['destination_number'] ?? 'n/a'}', style: const TextStyle(color: Colors.white70)),
          Text('Date: ${payment['date'] ?? payment['created_at'] ?? 'n/a'}', style: const TextStyle(color: Colors.white70)),
          if ((payment['proof_url'] ?? payment['preuve']) != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                final url = Uri.tryParse((payment['proof_url'] ?? payment['preuve']).toString());
                if (url != null) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('Voir preuve'),
            ),
          ],
          const SizedBox(height: 8),
          if (_status == 'PENDING_VALIDATION')
            Row(
              children: [
                ElevatedButton.icon(onPressed: onValidate, icon: const Icon(Icons.check), label: const Text('APPROVE')),
                const SizedBox(width: 10),
                OutlinedButton.icon(onPressed: onRefuse, icon: const Icon(Icons.close), label: const Text('REJECT')),
              ],
            ),
        ],
      ),
    );
  }
}
