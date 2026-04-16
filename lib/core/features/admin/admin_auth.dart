import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../constants/constants.dart';

class AdminAuth {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _storageKey = 'admin_api_key';
  static const String _usernameStorageKey = 'admin_username';
  static String? _adminKey;
  static String? _adminUsername;

  static String? get adminKey => _adminKey;
  static String? get adminUsername => _adminUsername;
  static bool get hasRegisteredAdmin => _adminUsername != null;

  static Future<void> loadPersistedKey() async {
    _adminKey = await _storage.read(key: _storageKey);
    _adminUsername = await _storage.read(key: _usernameStorageKey);
  }

  static Future<void> setAdminKey(String key) async {
    final trimmedKey = key.trim();
    _adminKey = trimmedKey.isEmpty ? null : trimmedKey;
    if (_adminKey == null) {
      await _storage.delete(key: _storageKey);
    } else {
      await _storage.write(key: _storageKey, value: _adminKey);
    }
  }

  static Future<void> logout() async {
    _adminKey = null;
    _adminUsername = null;
    await _storage.delete(key: _storageKey);
    await _storage.delete(key: _usernameStorageKey);
  }

  static Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse('${AppConstants.backendBaseUrl}$path'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    Map<String, dynamic> decodedBody = <String, dynamic>{};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          decodedBody = decoded;
        }
      } catch (_) {
        decodedBody = <String, dynamic>{};
      }
    }
    if (response.statusCode >= 400) {
      final detail = decodedBody['detail'];
      throw Exception(detail?.toString() ?? 'Erreur serveur (${response.statusCode}).');
    }
    return decodedBody;
  }

  static Future<void> registerAdminAccount({
    required String username,
    required String password,
    required String inviteCode,
  }) async {
    final response = await _postJson('/admin/register', {
      'username': username.trim(),
      'password': password,
      'invite_code': inviteCode,
    });

    _adminUsername = response['username']?.toString() ?? username.trim();
    _adminKey = response['admin_key']?.toString();
    if (_adminKey == null || _adminKey!.isEmpty) {
      throw Exception('La cle admin n\'a pas ete retournee par le serveur.');
    }

    await _storage.write(key: _usernameStorageKey, value: _adminUsername);
    await _storage.write(key: _storageKey, value: _adminKey);
  }

  static Future<void> loginAdminAccount({
    required String username,
    required String password,
  }) async {
    final response = await _postJson('/admin/login', {
      'username': username.trim(),
      'password': password,
    });

    _adminUsername = response['username']?.toString() ?? username.trim();
    _adminKey = response['admin_key']?.toString();
    if (_adminKey == null || _adminKey!.isEmpty) {
      throw Exception('La cle admin n\'a pas ete retournee par le serveur.');
    }

    await _storage.write(key: _usernameStorageKey, value: _adminUsername);
    await _storage.write(key: _storageKey, value: _adminKey);
  }

  static Map<String, String> headers({bool jsonContent = false}) {
    final headers = <String, String>{};
    if (jsonContent) {
      headers['Content-Type'] = 'application/json';
    }
    if (_adminKey != null && _adminKey!.isNotEmpty) {
      headers['x-admin-key'] = _adminKey!;
    }
    return headers;
  }
}