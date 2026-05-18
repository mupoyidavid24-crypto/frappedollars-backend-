import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/app_settings_model.dart';
import '../constants/constants.dart';
import '../features/admin/admin_auth.dart';

class AppSettingsService {
  static Future<AppSettings> fetchSettings() async {
    try {
      final response = await http.get(Uri.parse('${AppConstants.backendBaseUrl}/app/settings'));
      if (response.statusCode != 200) {
        return AppSettings.defaults();
      }

      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        return AppSettings.fromJson(decoded);
      }
      return AppSettings.defaults();
    } catch (_) {
      return AppSettings.defaults();
    }
  }

  static Future<AppSettings> updateSettings(AppSettings settings) async {
    final response = await http.put(
      Uri.parse('${AppConstants.adminBaseUrl}/app-settings'),
      headers: AdminAuth.headers(jsonContent: true),
      body: json.encode(settings.toJson()),
    );

    if (response.statusCode != 200) {
      final detail = response.body.isNotEmpty ? response.body : 'Erreur mise à jour configuration';
      throw Exception(detail);
    }

    final decoded = json.decode(response.body);
    if (decoded is Map<String, dynamic>) {
      return AppSettings.fromJson(decoded);
    }
    return settings;
  }
}
