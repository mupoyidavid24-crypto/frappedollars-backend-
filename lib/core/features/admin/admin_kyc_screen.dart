import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/constants.dart';
import 'kyc_admin_service.dart';

class AdminKycScreen extends StatefulWidget {
  const AdminKycScreen({super.key});

  @override
  State<AdminKycScreen> createState() => _AdminKycScreenState();
}

class _AdminKycScreenState extends State<AdminKycScreen> {
  List<Map<String, dynamic>> _documents = [];
  String _filter = 'TOUS';
  bool _loading = false;
  bool _fetching = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) {
        _fetchDocuments();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchDocuments() async {
    if (_fetching) {
      return;
    }
    _fetching = true;
    setState(() => _loading = true);
    try {
      final items = await KycAdminService.fetchKycDocuments();
      if (!mounted) return;
      setState(() {
        _documents = _filter == 'TOUS'
            ? items
            : items.where((document) => _statusOf(document) == _filter).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
      _fetching = false;
    }
  }

  Future<void> _updateStatus(String documentId, String status, {String? reviewerNote}) async {
    try {
      final ok = await KycAdminService.updateStatus(
        documentId,
        status,
        reason: reviewerNote?.trim().isNotEmpty == true ? reviewerNote!.trim() : (status == 'APPROVED' ? 'Dossier approuvé après vérification' : 'Dossier remis en attente pour révision'),
      );
      if (ok) {
        await _fetchDocuments();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('KYC ${status.toLowerCase()}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _showRejectDialog(Map<String, dynamic> document) async {
    final noteController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        bool canReject = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF101821),
              title: const Text('Rejeter le KYC', style: TextStyle(color: Colors.white)),
              content: TextField(
                controller: noteController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                onChanged: (value) {
                  setDialogState(() {
                    canReject = value.trim().isNotEmpty;
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Motif du rejet',
                  hintStyle: TextStyle(color: Colors.white54),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: canReject ? () => Navigator.pop(context, true) : null,
                  child: const Text('Rejeter'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      await _updateStatus(
        document['id'].toString(),
        'REJECTED',
        reviewerNote: noteController.text.trim(),
      );
    }
  }

  Future<void> _openDocument(Map<String, dynamic> document) async {
    final fileUrl = document['file_url']?.toString() ?? '';
    if (fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document introuvable.')),
      );
      return;
    }

    try {
      final signedUrl = await Supabase.instance.client.storage.from('kyc-documents').createSignedUrl(fileUrl, 3600);
      final uri = Uri.parse(signedUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Impossible d\'ouvrir le document');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur ouverture document: $e')));
    }
  }

  String _statusOf(Map<String, dynamic> document) {
    return document['status']?.toString().toUpperCase() ?? 'PENDING';
  }

  int _calculateAge(Map<String, dynamic> profile, Map<String, dynamic> document) {
    final rawDate = profile['date_of_birth'] ?? document['date_of_birth'];
    if (rawDate == null) {
      return 0;
    }

    try {
      final parsed = DateTime.parse(rawDate.toString());
      final today = DateTime.now();
      return today.year - parsed.year - ((today.month < parsed.month || (today.month == parsed.month && today.day < parsed.day)) ? 1 : 0);
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _documents.where((document) => _statusOf(document) == 'PENDING').length;
    final approvedCount = _documents.where((document) => _statusOf(document) == 'APPROVED').length;
    final rejectedCount = _documents.where((document) => _statusOf(document) == 'REJECTED').length;

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
                    const CircleAvatar(
                      backgroundColor: Color(AppConstants.primaryColor),
                      child: Icon(Icons.verified_user, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('KYC Admin', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                          SizedBox(height: 4),
                          Text('Documents, âge, validation et notifications', style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        setState(() => _filter = value);
                        _fetchDocuments();
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'TOUS', child: Text('Tous')),
                        PopupMenuItem(value: 'PENDING', child: Text('En attente')),
                        PopupMenuItem(value: 'APPROVED', child: Text('Approuvés')),
                        PopupMenuItem(value: 'REJECTED', child: Text('Rejetés')),
                      ],
                      icon: const Icon(Icons.filter_list, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatPill(label: 'Total', value: '${_documents.length}'),
                    _StatPill(label: 'En attente', value: '$pendingCount'),
                    _StatPill(label: 'Approuvés', value: '$approvedCount'),
                    _StatPill(label: 'Rejetés', value: '$rejectedCount'),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: Color(AppConstants.primaryColor)))
                      : _documents.isEmpty
                          ? const Center(child: Text('Aucun document KYC', style: TextStyle(color: Colors.white60)))
                          : ListView.separated(
                              itemCount: _documents.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final document = _documents[index];
                                final profile = Map<String, dynamic>.from(document['profile'] as Map? ?? {});
                                final status = _statusOf(document);
                                final statusColor = switch (status) {
                                  'APPROVED' => const Color(0xFF3EE7B6),
                                  'REJECTED' => const Color(0xFFFF7C7C),
                                  _ => const Color(0xFFFFD66B),
                                };
                                final age = _calculateAge(profile, document);
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
                                            width: 42,
                                            height: 42,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(14),
                                              color: statusColor.withOpacity(0.15),
                                            ),
                                            child: Icon(Icons.badge_outlined, color: statusColor),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  profile['full_name']?.toString().isNotEmpty == true ? profile['full_name'].toString() : profile['email']?.toString() ?? 'Utilisateur',
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Email: ${profile['email'] ?? 'n/a'}',
                                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                                ),
                                                Text(
                                                  'Téléphone: ${profile['phone_number'] ?? 'n/a'}',
                                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(999),
                                              color: statusColor.withOpacity(0.14),
                                              border: Border.all(color: statusColor.withOpacity(0.35)),
                                            ),
                                            child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 11)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          _InfoChip(label: 'Âge', value: age > 0 ? '$age ans' : 'n/a'),
                                          _InfoChip(label: 'Document', value: document['document_type']?.toString() ?? 'n/a'),
                                          _InfoChip(label: 'Pays', value: document['country']?.toString() ?? 'n/a'),
                                          _InfoChip(label: 'Ville', value: document['city']?.toString() ?? 'n/a'),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Adresse: ${document['address_line'] ?? 'n/a'}',
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Numéro document: ${document['document_number'] ?? 'n/a'}',
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Soumis le: ${document['submitted_at'] ?? 'n/a'}',
                                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                                      ),
                                      if ((document['reason']?.toString().isNotEmpty ?? false) || (document['reviewer_note']?.toString().isNotEmpty ?? false)) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'Motif: ${document['reason'] ?? document['reviewer_note']}',
                                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () => _openDocument(document),
                                            icon: const Icon(Icons.open_in_new),
                                            label: const Text('Voir le document'),
                                          ),
                                          ElevatedButton(
                                            onPressed: status == 'APPROVED' ? null : () => _updateStatus(document['id'].toString(), 'APPROVED', reviewerNote: 'Dossier approuvé après vérification'),
                                            child: const Text('APPROVE'),
                                          ),
                                          ElevatedButton(
                                            onPressed: status == 'PENDING' ? null : () => _updateStatus(document['id'].toString(), 'PENDING', reviewerNote: 'Dossier remis en attente pour révision'),
                                            child: const Text('PENDING'),
                                          ),
                                          OutlinedButton(
                                            onPressed: () => _showRejectDialog(document),
                                            child: const Text('REJECT'),
                                          ),
                                        ],
                                      ),
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

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}
