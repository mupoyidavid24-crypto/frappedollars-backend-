import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import 'core/constants/constants.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/kyc_screen.dart';
import 'features/admin/admin_login_screen.dart';
import 'core/features/admin/admin_api_keys_screen.dart';
import 'core/features/admin/admin_dashboard_screen.dart' as modern_admin;
import 'core/features/admin/admin_branding_screen.dart';
import 'core/features/admin/admin_copytrading_screen.dart';
import 'core/features/admin/admin_kyc_screen.dart';
import 'core/features/admin/admin_logs_screen.dart';
import 'core/features/admin/admin_notifications_screen.dart';
import 'core/features/admin/admin_payment_methods_screen.dart';
import 'core/features/admin/admin_payments_screen.dart';
import 'core/features/admin/admin_users_screen.dart';
import 'core/features/admin/admin_vip_screen.dart';
import 'core/features/admin/admin_vps_screen.dart';
import 'core/services/app_settings_provider.dart';
import 'features/dashboard/dashboard_provider.dart';
import 'features/dashboard/main_navigation_screen.dart';
import 'core/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'models/profile_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  try {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: true,
        detectSessionInUri: true,
      ),
    );
  } catch (e) {
    debugPrint('Supabase Initialization Error: $e');
  }

  // Initialisation notifications (toutes plateformes)
  await NotificationService().init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()..load()),
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
    final branding = context.watch<AppSettingsProvider>().settings;

    return MaterialApp(
      title: branding.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: branding.backgroundColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: branding.primaryColor,
          brightness: Brightness.dark,
          surface: branding.backgroundColor,
        ),
      ),
      initialRoute: _initialRoute(),
      routes: {
        '/': (context) => const AuthWrapper(),
        '/admin': (context) => const modern_admin.AdminDashboardScreen(),
        '/admin/login': (context) => const AdminLoginScreen(),
        '/admin/dashboard': (context) =>
            const modern_admin.AdminDashboardScreen(),
        '/admin/api-keys': (context) => const AdminApiKeysScreen(),
        '/admin/users': (context) => const AdminUsersScreen(),
        '/admin/vps': (context) => const AdminVpsScreen(),
        '/admin/payment-methods': (context) => const AdminPaymentMethodsScreen(),
        '/admin/branding': (context) => const AdminBrandingScreen(),
        '/admin/payments': (context) => const AdminPaymentsScreen(),
        '/admin/notifications': (context) => const AdminNotificationsScreen(),
        '/admin/vip': (context) => const AdminVIPScreen(),
        '/admin/copytrading': (context) => const AdminCopyTradingScreen(),
        '/admin/kyc': (context) => const AdminKycScreen(),
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
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        context.read<AuthProvider>().initializeAuth();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final profile = authProvider.userProfile;

    if (authProvider.isLoading && profile == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color(AppConstants.primaryColor),
          ),
        ),
      );
    }

    if (profile != null) {
      if (profile.role == UserRole.admin) {
        return const modern_admin.AdminDashboardScreen();
      }
      if (AppConstants.kycRequired && profile.kycStatus != KycStatus.approved) {
        return const KycScreen();
      }
      return const MainNavigationScreen();
    } else {
      return const LoginScreen();
    }
  }
}
