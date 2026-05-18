import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAuth {
  static Future<void> logout() async {
    await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
  }

  static Map<String, String> headers({bool jsonContent = false}) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null || session.accessToken.isEmpty) {
      throw Exception('Session Supabase requise pour l\'espace admin.');
    }

    final headers = <String, String>{};
    if (jsonContent) {
      headers['Content-Type'] = 'application/json';
    }
    headers['Authorization'] = 'Bearer ${session.accessToken}';
    return headers;
  }
}