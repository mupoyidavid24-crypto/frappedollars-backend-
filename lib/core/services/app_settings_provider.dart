import 'package:flutter/material.dart';

import '../../models/app_settings_model.dart';
import 'app_settings_service.dart';

class AppSettingsProvider extends ChangeNotifier {
  AppSettings _settings = AppSettings.defaults();
  bool _isLoading = false;
  String? _errorMessage;

  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _setLoading(true);
    try {
      _settings = await AppSettingsService.fetchSettings();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refresh() async {
    await load();
  }

  Future<void> update(AppSettings settings) async {
    _setLoading(true);
    try {
      _settings = await AppSettingsService.updateSettings(settings);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
