class AppConstants {
  static const String backendBaseUrl = String.fromEnvironment(
    'FRAPPEDOLLARS_BACKEND_BASE_URL',
    defaultValue: 'https://frappedollars-backend-1.onrender.com',
  );

  static const String appWebUrl = String.fromEnvironment(
    'FRAPPEDOLLARS_APP_WEB_URL',
    defaultValue: 'https://frappe-dollars.web.app',
  );

  static const String adminBaseUrl = '$backendBaseUrl/admin';
  static const String authRedirectUrl = '$appWebUrl/auth/callback';

  // Configuration Supabase du projet FrappedDollars.
  static const String supabaseUrl = 'https://lllkrhivavsujgcfhcls.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_SA2ex7Iy0bUPvowzcHyJNg_e5EPBdiH';
  static const String supabasePublishableKey = 'sb_publishable_SA2ex7Iy0bUPvowzcHyJNg_e5EPBdiH';

  // Couleurs de l'application
  static const int primaryColor = 0xFF00C853; // Vert Trading
  static const int backgroundColor = 0xFF121212; // Noir profond
}
