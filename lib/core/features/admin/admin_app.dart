import 'package:flutter/material.dart';
import 'admin_dashboard_screen.dart';
import 'admin_payments_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_vip_screen.dart';
import 'admin_copytrading_screen.dart';
import 'admin_logs_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_KEY',
  );
  runApp(AdminApp());
  setupFCM();
}

class AdminApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Centre de contrôle',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/admin/dashboard',
      routes: {
        '/admin/dashboard': (context) => AdminDashboardScreen(),
        '/admin/payments': (context) => AdminPaymentsScreen(),
        '/admin/notifications': (context) => AdminNotificationsScreen(),
        '/admin/vip': (context) => AdminVIPScreen(),
        '/admin/copytrading': (context) => AdminCopyTradingScreen(),
        '/admin/logs': (context) => AdminLogsScreen(),
      },
    );
  }
}

void setupFCM() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  String? token = await messaging.getToken();
  // Enregistrer le token FCM côté Supabase pour l'utilisateur
  if (token != null) {
    await Supabase.instance.client
      .from('profiles')
      .update({'fcm_token': token})
      .eq('id', 'USER_ID') // Remplacer par l'ID utilisateur
      .execute();
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    // Afficher la notification ou traiter le message
  });
}
