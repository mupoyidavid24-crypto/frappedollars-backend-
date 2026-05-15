import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/constants.dart';
import '../../models/business_rules_model.dart';

class BusinessRulesService {
  BusinessRulesService._();

  static final BusinessRulesService instance = BusinessRulesService._();

  BusinessRules? _cachedRules;

  BusinessRules? get cachedRules => _cachedRules;

  Future<BusinessRules?> fetchBusinessRules({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedRules != null) {
      return _cachedRules;
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.backendBaseUrl}/business/rules'),
        headers: const {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        return _cachedRules;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        _cachedRules = BusinessRules.fromJson(decoded);
        return _cachedRules;
      }
    } catch (_) {
      return _cachedRules;
    }

    return _cachedRules;
  }
}
