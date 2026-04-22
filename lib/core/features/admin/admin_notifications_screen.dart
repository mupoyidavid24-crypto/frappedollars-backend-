import 'dart:async';

import 'package:flutter/material.dart';
import '../../constants/constants.dart';
import 'notification_admin_service.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({Key? key}) : super(key: key);

  @override
  _AdminNotificationsScreenState createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  List<Map<String, dynamic>> notifications = [];
  bool loading = false;
  Timer? _refreshTimer;

  void sendNotification({String? userId, String? title, String? message, String? priority}) async {
    setState(() { loading = true; });
    final ok = await NotificationAdminService.sendNotification({
      'user_id': userId,
      'title': title,
      'message': message,
      'priority': priority ?? 'NORMAL',
    });
    setState(() { loading = false; });
    if (ok) {
      fetchNotifications();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification envoyée'))
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur envoi notification'))
      );
    }
  }

  void fetchNotifications() async {
    setState(() { loading = true; });
    try {
      final result = await NotificationAdminService.fetchNotifications();
      setState(() { notifications = result; loading = false; });
    } catch (e) {
      setState(() { loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur chargement notifications'))
      );
    }
  }

  @override
  void initState() {
    super.initState();
    fetchNotifications();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        fetchNotifications();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F14),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(AppConstants.primaryColor),
        icon: const Icon(Icons.send, color: Colors.white),
        label: const Text('Envoyer', style: TextStyle(color: Colors.white)),
        onPressed: () {
          String userId = '';
          String title = '';
          String message = '';
          String priority = 'NORMAL';
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                backgroundColor: const Color(0xFF101821),
                title: const Text('Envoyer une notification', style: TextStyle(color: Colors.white)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'ID utilisateur'),
                      onChanged: (v) => userId = v,
                    ),
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Titre'),
                      onChanged: (v) => title = v,
                    ),
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Message'),
                      onChanged: (v) => message = v,
                    ),
                    const SizedBox(height: 12),
                    DropdownButton<String>(
                      dropdownColor: const Color(0xFF101821),
                      value: priority,
                      items: ['NORMAL', 'URGENT', 'EA']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white))))
                          .toList(),
                      onChanged: (v) {
                        setState(() { priority = v!; });
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(child: const Text('Annuler'), onPressed: () => Navigator.pop(context)),
                  TextButton(child: const Text('Envoyer'), onPressed: () {
                    sendNotification(userId: userId, title: title, message: message, priority: priority);
                    Navigator.pop(context);
                  }),
                ],
              );
            },
          );
        },
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF071116), Color(0xFF0C161B), Color(0xFF05080B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Notifications Admin', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Envoi push, historique et ciblage utilisateur', style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 16),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator(color: Color(AppConstants.primaryColor)))
                      : notifications.isEmpty
                          ? const Center(child: Text('Aucune notification', style: TextStyle(color: Colors.white60)))
                          : ListView.separated(
                              itemCount: notifications.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final n = notifications[index];
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: Colors.white.withOpacity(0.04),
                                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                                  ),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const CircleAvatar(
                                      backgroundColor: Color(AppConstants.primaryColor),
                                      child: Icon(Icons.notifications_active, color: Colors.white),
                                    ),
                                    title: Text(n['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                    subtitle: Text('Message: ${n['message']}', style: const TextStyle(color: Colors.white70)),
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
