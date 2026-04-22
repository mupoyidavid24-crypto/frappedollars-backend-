import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import 'core/constants/constants.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/admin/admin_entry_screen.dart';
import 'features/admin/admin_login_screen.dart';
import 'features/admin/admin_register_screen.dart';
import 'core/features/admin/admin_api_keys_screen.dart';
import 'core/features/admin/admin_dashboard_screen.dart' as modern_admin;
import 'core/features/admin/admin_copytrading_screen.dart';
import 'core/features/admin/admin_logs_screen.dart';
import 'core/features/admin/admin_notifications_screen.dart';
import 'core/features/admin/admin_payments_screen.dart';
import 'core/features/admin/admin_vip_screen.dart';
import 'features/dashboard/dashboard_provider.dart';
import 'features/dashboard/main_navigation_screen.dart';
import 'core/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/features/admin/admin_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  try {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase Initialization Error: $e');
  }

  await AdminAuth.loadPersistedKey();

  // Initialisation notifications (toutes plateformes)
  await NotificationService().init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  String _initialRoute() {
    final path = Uri.base.path;
    if (path.startsWith('/admin')) {
      return path == '/admin/' ? '/admin' : path;
    }
    return '/';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FrappedDollars',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: const Color(AppConstants.backgroundColor),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(AppConstants.primaryColor),
          brightness: Brightness.dark,
          surface: const Color(AppConstants.backgroundColor),
        ),
      ),
      initialRoute: _initialRoute(),
      routes: {
        '/': (context) => const AuthWrapper(),
        '/admin': (context) => const AdminEntryScreen(),
        '/admin/login': (context) => const AdminLoginScreen(),
        '/admin/register': (context) => const AdminRegisterScreen(),
        '/admin/dashboard': (context) =>
            const modern_admin.AdminDashboardScreen(),
        '/admin/api-keys': (context) => const AdminApiKeysScreen(),
        '/admin/payments': (context) => const AdminPaymentsScreen(),
        '/admin/notifications': (context) => const AdminNotificationsScreen(),
        '/admin/vip': (context) => const AdminVIPScreen(),
        '/admin/copytrading': (context) => const AdminCopyTradingScreen(),
        '/admin/logs': (context) => const AdminLogsScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _checkAuth();
      _initialized = true;
    }
  }

  Future<void> _checkAuth() async {
    // Utiliser microtask pour éviter les erreurs de build pendant l'initialisation
    Future.microtask(() => context.read<AuthProvider>().initializeAuth());
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.isLoading && authProvider.userProfile == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color(AppConstants.primaryColor),
          ),
        ),
      );
    }

    if (authProvider.userProfile != null) {
      return const MainNavigationScreen();
    } else {
      return const LoginScreen();
    }
  }
}
