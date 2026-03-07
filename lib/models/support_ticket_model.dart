class SupportTicket {
  final String? id;
  final String userId;
  final String subject;
  final String message;
  final String status; // OPEN, IN_PROGRESS, CLOSED
  final String? adminResponse;
  final DateTime createdAt;

  SupportTicket({
    this.id,
    required this.userId,
    required this.subject,
    required this.message,
    required this.status,
    this.adminResponse,
    required this.createdAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'],
      userId: json['user_id'],
      subject: json['subject'],
      message: json['message'],
      status: json['status'],
      adminResponse: json['admin_response'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'subject': subject,
      'message': message,
      'status': status,
    };
  }
}
