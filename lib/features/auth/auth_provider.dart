import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';
import '../../models/profile_model.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  
  Profile? _userProfile;
  bool _isLoading = false;

  Profile? get userProfile => _userProfile;
  bool get isLoading => _isLoading;

  /// Initialise l'authentification en vérifiant si une session existe déjà
  Future<void> initializeAuth() async {
    final user = _supabaseService.currentUser;
    if (user != null) {
      _setLoading(true);
      try {
        _userProfile = await _supabaseService.getUserProfile(user.id);
      } catch (e) {
        debugPrint("Init Auth Error: $e");
      } finally {
        _setLoading(false);
      }
    }
  }

  String? _loginError;
  String? get loginError => _loginError;

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _loginError = null;
    try {
      final response = await _supabaseService.signIn(email, password);
      if (response.user != null) {
        _userProfile = await _supabaseService.getUserProfile(response.user!.id);
        notifyListeners();
        return true;
      } else {
        _loginError = "Identifiants invalides ou connexion échouée.";
        debugPrint("Login Error: ${_loginError}");
      }
    } catch (e) {
      _loginError = e.toString();
      debugPrint("Login Error: $e");
    } finally {
      _setLoading(false);
      notifyListeners();
    }
    return false;
  }

  Future<bool> register(String email, String password) async {
    _setLoading(true);
    try {
      final response = await _supabaseService.signUp(email, password);
      if (response.user != null) {
        // Le profil est créé via le trigger SQL dans Supabase
        return true;
      }
    } catch (e) {
      debugPrint("Register Error: $e");
    } finally {
      _setLoading(false);
    }
    return false;
  }

  Future<void> signOut() async {
    await _supabaseService.signOut();
    _userProfile = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
