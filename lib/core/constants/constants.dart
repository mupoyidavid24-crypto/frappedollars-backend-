class AppConstants {
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'https://frappedollars-backend-1.onrender.com',
  );

  static const String adminBaseUrl = '$backendBaseUrl/admin';

  // Vos vraies clés Supabase
  static const String supabaseUrl = 'https://lllkrhivavsujgcfhcls.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxsbGtyaGl2YXZzdWpnY2ZoY2xzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIxMjkzNDcsImV4cCI6MjA4NzcwNTM0N30.31rAqX7VU1g5AgOpC-9XzPMq1b6tcawg4JgU9NkGa2Y';
  static const String supabasePublishableKey = 'sb_publishable_SA2ex7Iy0bUPvowzcHyJNg_e5EPBdiH';

  // Couleurs de l'application
  static const int primaryColor = 0xFF00C853; // Vert Trading
  static const int backgroundColor = 0xFF121212; // Noir profond
}
