import 'package:flutter/material.dart';
import '../dashboard/dashboard_screen.dart';
import '../dashboard/leaderboard_screen.dart';
import '../support/support_screen.dart';
import '../dashboard/profile_screen.dart';
import '../../core/constants/constants.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    DashboardScreen(),
    const LeaderboardScreen(),
    const SupportScreen(),
    const ProfileScreen(),
    // Onglet Admin supprimé
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(AppConstants.primaryColor),
        unselectedItemColor: Colors.white60,
        backgroundColor: const Color(AppConstants.backgroundColor),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard_outlined), label: 'Top 10'),
          BottomNavigationBarItem(icon: Icon(Icons.support_agent_outlined), label: 'Support'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
          // Onglet Admin supprimé
        ],
      ),
    );
  }
}
