import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';
import '../../models/profile_model.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  StreamSubscription<AuthState>? _authStateSubscription;
  bool _disposed = false;
  bool _authReady = false;
  
  Profile? _userProfile;
  bool _isLoading = false;
  String? _registerMessage;

  AuthProvider() {
    unawaited(initializeAuth());
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (_disposed) {
        return;
      }

      debugPrint('Supabase auth event: $event session=${data.session != null} fromBroadcast=${data.fromBroadcast}');

      if (event == AuthChangeEvent.signedOut) {
        _userProfile = null;
        _setLoading(false);
        notifyListeners();
        return;
      }

      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed ||
          event == AuthChangeEvent.userUpdated ||
          event == AuthChangeEvent.initialSession) {
        unawaited(_syncAuthState(session: data.session));
      }
    });
  }

  Profile? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get registerMessage => _registerMessage;
  bool get authReady => _authReady;

  /// Initialise l'authentification en vérifiant si une session existe déjà
  Future<void> initializeAuth() async {
    if (_disposed || _authReady) {
      return;
    }

    debugPrint('Supabase auth bootstrap started');
    await _syncAuthState();
    _authReady = true;
    debugPrint('Supabase auth bootstrap finished: session=${Supabase.instance.client.auth.currentSession != null} user=${Supabase.instance.client.auth.currentUser?.id ?? 'none'}');
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> _syncAuthState({Session? session}) async {
    if (_disposed) {
      return;
    }

    final currentSession = session ?? Supabase.instance.client.auth.currentSession;
    final user = currentSession?.user ?? _supabaseService.currentUser;
    if (user == null) {
      _userProfile = null;
      debugPrint('Supabase auth sync: no current user session=${currentSession != null}');
      notifyListeners();
      return;
    }

    debugPrint('Supabase auth sync: loading profile for ${user.id} session=${currentSession != null}');
    _setLoading(true);
    try {
      _userProfile = await _supabaseService.getUserProfile(user.id);
      debugPrint('Supabase auth sync: profile loaded user=${_userProfile?.id ?? 'none'} role=${_userProfile?.role.name.toUpperCase() ?? 'none'}');
    } catch (e) {
      debugPrint("Init Auth Error: $e");
    } finally {
      _setLoading(false);
      if (!_disposed) {
        notifyListeners();
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
      debugPrint('Login auth response: user=${response.user?.id ?? 'none'} session=${response.session != null}');
      if (response.user != null) {
        await _syncAuthState(session: response.session);
        notifyListeners();
        return true;
      } else {
        _loginError = "Identifiants invalides ou connexion échouée.";
        debugPrint("Login Error: $_loginError");
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

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required DateTime dateOfBirth,
  }) async {
    _setLoading(true);
    _registerMessage = null;
    try {
      final response = await _supabaseService.signUp(
        email,
        password,
        metadata: {
          'full_name': fullName,
          'phone_number': phoneNumber,
          'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
        },
      );
      _registerMessage = response.user == null
          ? "Compte créé. Vérifiez votre email pour activer le compte."
          : "Compte créé. Vérifiez votre email pour activer le compte.";
      notifyListeners();
      return true;
    } catch (e) {
      _registerMessage = e.toString();
      debugPrint("Register Error: $e");
    } finally {
      _setLoading(false);
    }
    return false;
  }

  Future<void> refreshProfile() async {
    final user = _supabaseService.currentUser;
    if (user == null) {
      return;
    }

    try {
      _userProfile = await _supabaseService.getUserProfile(user.id);
      notifyListeners();
    } catch (e) {
      debugPrint('Refresh profile error: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _supabaseService.signOut();
    } catch (e) {
      debugPrint('Sign out warning: $e');
    } finally {
      _userProfile = null;
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    if (_disposed) {
      return;
    }
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authStateSubscription?.cancel();
    super.dispose();
  }
}
