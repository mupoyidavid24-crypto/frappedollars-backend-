
import 'package:flutter/material.dart';
import 'package:frappedollars/firebase_options.dart';
import 'admin_dashboard_screen.dart';
import 'admin_payments_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_vip_screen.dart';
import 'admin_copytrading_screen.dart';
import 'admin_logs_screen.dart';
import '../../../features/admin/admin_login_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/constants.dart';
import 'admin_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );
  await AdminAuth.loadPersistedKey();
  runApp(const AdminApp());
  setupFCM();
}

class AdminApp extends StatelessWidget {
  const AdminApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Centre de contrôle',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Arial',
      ),
      initialRoute: AdminAuth.adminKey != null ? '/admin/dashboard' : '/admin/login',
      routes: {
        '/admin/login': (context) => const AdminLoginScreen(),
        '/admin/dashboard': (context) => AdminDashboardScreen(),
        '/admin/payments': (context) => AdminPaymentsScreen(),
        '/admin/notifications': (context) => const AdminNotificationsScreen(),
        '/admin/vip': (context) => const AdminVIPScreen(),
        '/admin/copytrading': (context) => const AdminCopyTradingScreen(),
        '/admin/logs': (context) => const AdminLogsScreen(),
      },
    );
  }
}

void setupFCM() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  String? token = await messaging.getToken();
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (token != null && userId != null) {
    await Supabase.instance.client
      .from('profiles')
      .update({'fcm_token': token})
      .eq('id', userId);
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    // Afficher la notification ou traiter le message
  });
}
