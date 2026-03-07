enum UserRole { admin, master, client }

class Profile {
  final String id;
  final String email;
  final String? fullName;
  final UserRole role;
  final bool isVip;
  final bool needsVps;
  final String? fcmToken;
  final String? referralCode;
  final DateTime createdAt;

  Profile({
    required this.id,
    required this.email,
    this.fullName,
    required this.role,
    required this.isVip,
    required this.needsVps,
    this.fcmToken,
    this.referralCode,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'],
      role: _parseRole(json['role']),
      isVip: json['is_vip'] ?? false,
      needsVps: json['needs_vps'] ?? false,
      fcmToken: json['fcm_token'],
      referralCode: json['referral_code'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  static UserRole _parseRole(String? role) {
    switch (role?.toUpperCase()) {
      case 'ADMIN':
        return UserRole.admin;
      case 'MASTER':
        return UserRole.master;
      case 'CLIENT':
      default:
        return UserRole.client;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role.name.toUpperCase(),
      'is_vip': isVip,
      'needs_vps': needsVps,
      'fcm_token': fcmToken,
      'referral_code': referralCode,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
