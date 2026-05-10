enum UserRole { admin, master, client }

enum KycStatus { notSubmitted, pending, approved, rejected }

class Profile {
  final String id;
  final String email;
  final String? fullName;
  final String? phoneNumber;
  final DateTime? dateOfBirth;
  final KycStatus kycStatus;
  final bool kycBlocked;
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
    this.phoneNumber,
    this.dateOfBirth,
    this.kycStatus = KycStatus.notSubmitted,
    this.kycBlocked = true,
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
      phoneNumber: json['phone_number'],
      dateOfBirth: json['date_of_birth'] != null ? DateTime.tryParse(json['date_of_birth'].toString()) : null,
      kycStatus: _parseKycStatus(json['kyc_status']),
      kycBlocked: json['kyc_blocked'] ?? true,
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

  static KycStatus _parseKycStatus(String? status) {
    switch (status?.toUpperCase()) {
      case 'APPROVED':
        return KycStatus.approved;
      case 'REJECTED':
        return KycStatus.rejected;
      case 'PENDING':
        return KycStatus.pending;
      case 'NOT_SUBMITTED':
      default:
        return KycStatus.notSubmitted;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
      'kyc_status': kycStatus.name.toUpperCase(),
      'kyc_blocked': kycBlocked,
      'role': role.name.toUpperCase(),
      'is_vip': isVip,
      'needs_vps': needsVps,
      'fcm_token': fcmToken,
      'referral_code': referralCode,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
