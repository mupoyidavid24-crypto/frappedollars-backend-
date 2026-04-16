import 'package:flutter/material.dart';
import '../../core/features/admin/admin_auth.dart';
import 'admin_dashboard_screen.dart';
import 'admin_login_screen.dart';

class AdminEntryScreen extends StatelessWidget {
  const AdminEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (AdminAuth.adminKey != null) {
      return const AdminDashboardScreen();
    }
    return const AdminLoginScreen();
  }
}