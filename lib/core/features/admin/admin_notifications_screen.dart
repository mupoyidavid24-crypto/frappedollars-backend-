import 'package:flutter/material.dart';
import 'notification_admin_service.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({Key? key}) : super(key: key);

  @override
  _AdminNotificationsScreenState createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  List<Map<String, dynamic>> notifications = [];
  bool loading = false;

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications Admin')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.send),
        onPressed: () {
          String userId = '';
          String title = '';
          String message = '';
          String priority = 'NORMAL';
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Envoyer une notification'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(labelText: 'ID utilisateur'),
                      onChanged: (v) => userId = v,
                    ),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Titre'),
                      onChanged: (v) => title = v,
                    ),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Message'),
                      onChanged: (v) => message = v,
                    ),
                    DropdownButton<String>(
                      value: priority,
                      items: ['NORMAL', 'URGENT', 'EA']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
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
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? const Center(child: Text('Aucune notification'))
              : ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final n = notifications[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: ListTile(
                        leading: const Icon(Icons.notifications_active),
                        title: Text(n['title'] ?? ''),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Message: ${n['message']}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
