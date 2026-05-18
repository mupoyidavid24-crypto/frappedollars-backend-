import 'package:flutter/material.dart';

class AppSettings {
  final String appName;
  final String tagline;
  final String? logoUrl;
  final String primaryColorHex;
  final String backgroundColorHex;
  final String? supportEmail;
  final String? supportPhone;

  const AppSettings({
    required this.appName,
    required this.tagline,
    required this.logoUrl,
    required this.primaryColorHex,
    required this.backgroundColorHex,
    required this.supportEmail,
    required this.supportPhone,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      appName: 'FrappedDollars',
      tagline: 'Copy trading automatique pour comptes MT5.',
      logoUrl: null,
      primaryColorHex: '#00C853',
      backgroundColorHex: '#121212',
      supportEmail: null,
      supportPhone: null,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final defaults = AppSettings.defaults();
    return AppSettings(
      appName: _stringOrDefault(json['app_name'], defaults.appName),
      tagline: _stringOrDefault(json['tagline'], defaults.tagline),
      logoUrl: _nullableString(json['logo_url']),
      primaryColorHex: _normalizeHex(_stringOrDefault(json['primary_color_hex'], defaults.primaryColorHex)),
      backgroundColorHex: _normalizeHex(_stringOrDefault(json['background_color_hex'], defaults.backgroundColorHex)),
      supportEmail: _nullableString(json['support_email']),
      supportPhone: _nullableString(json['support_phone']),
    );
  }

  AppSettings copyWith({
    String? appName,
    String? tagline,
    String? logoUrl,
    String? primaryColorHex,
    String? backgroundColorHex,
    String? supportEmail,
    String? supportPhone,
  }) {
    return AppSettings(
      appName: appName ?? this.appName,
      tagline: tagline ?? this.tagline,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColorHex: primaryColorHex ?? this.primaryColorHex,
      backgroundColorHex: backgroundColorHex ?? this.backgroundColorHex,
      supportEmail: supportEmail ?? this.supportEmail,
      supportPhone: supportPhone ?? this.supportPhone,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'app_name': appName,
      'tagline': tagline,
      'logo_url': logoUrl,
      'primary_color_hex': _normalizeHex(primaryColorHex),
      'background_color_hex': _normalizeHex(backgroundColorHex),
      'support_email': supportEmail,
      'support_phone': supportPhone,
    };
  }

  Color get primaryColor => _colorFromHex(primaryColorHex, fallback: const Color(0xFF00C853));
  Color get backgroundColor => _colorFromHex(backgroundColorHex, fallback: const Color(0xFF121212));

  static String _stringOrDefault(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static String _normalizeHex(String value) {
    final cleaned = value.trim().replaceAll('#', '');
    if (cleaned.length == 6) {
      return '#${cleaned.toUpperCase()}';
    }
    return '#00C853';
  }

  static Color _colorFromHex(String value, {required Color fallback}) {
    final cleaned = value.trim().replaceAll('#', '');
    if (cleaned.length != 6) {
      return fallback;
    }
    try {
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return fallback;
    }
  }
}
