class TradingAccount {
  final String? id;
  final String userId;
  final String mt5Login;
  final String mt5Server;
  final String accountType; // MASTER or CLIENT
  final double balance;
  final double equity;
  final bool isActive;
  final DateTime? lastSync;

  TradingAccount({
    this.id,
    required this.userId,
    required this.mt5Login,
    required this.mt5Server,
    required this.accountType,
    required this.balance,
    required this.equity,
    required this.isActive,
    this.lastSync,
  });

  factory TradingAccount.fromJson(Map<String, dynamic> json) {
    return TradingAccount(
      id: json['id'],
      userId: json['user_id'],
      mt5Login: json['mt5_login'],
      mt5Server: json['mt5_server'],
      accountType: json['account_type'],
      balance: (json['balance'] ?? 0.0).toDouble(),
      equity: (json['equity'] ?? 0.0).toDouble(),
      isActive: json['is_active'] ?? true,
      lastSync: json['last_sync'] != null ? DateTime.parse(json['last_sync']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'mt5_login': mt5Login,
      'mt5_server': mt5Server,
      'account_type': accountType,
      'balance': balance,
      'equity': equity,
      'is_active': isActive,
    };
  }
}
