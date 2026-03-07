import 'package:flutter/material.dart';

class AdminDashboardProvider extends ChangeNotifier {
  // Ajoutez ici la logique de chargement des utilisateurs, tickets, logs, etc.
  // Exemple :
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadAdminData() async {
    _isLoading = true;
    notifyListeners();
    // TODO: Charger les données admin depuis l'API backend
    await Future.delayed(const Duration(seconds: 1));
    _isLoading = false;
    notifyListeners();
  }
}
