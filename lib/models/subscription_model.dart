enum SubscriptionStatus { active, expired, suspended, manualActive }

class Subscription {
  final String? id;
  final String userId;
  final SubscriptionStatus status;
  final DateTime startDate;
  final DateTime? endDate;
  final String? transactionRef;

  Subscription({
    this.id,
    required this.userId,
    required this.status,
    required this.startDate,
    this.endDate,
    this.transactionRef,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'],
      userId: json['user_id'],
      status: _parseStatus(json['status']),
      startDate: DateTime.parse(json['start_date']),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      transactionRef: json['transaction_ref'],
    );
  }

  static SubscriptionStatus _parseStatus(String? status) {
    switch (status?.toUpperCase()) {
      case 'ACTIVE':
        return SubscriptionStatus.active;
      case 'SUSPENDED':
        return SubscriptionStatus.suspended;
      case 'MANUAL_ACTIVE':
        return SubscriptionStatus.manualActive;
      case 'EXPIRED':
      default:
        return SubscriptionStatus.expired;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'status': status.name.toUpperCase(),
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'transaction_ref': transactionRef,
    };
  }
}
