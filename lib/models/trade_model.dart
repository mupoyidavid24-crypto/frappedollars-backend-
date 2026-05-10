class Trade {
  final String id;
  final String symbol;
  final String tradeType;
  final double volume;
  final double? openPrice;
  final double? tp;
  final double? sl;
  final String status; // OPEN, CLOSED
  final String executionStatus; // SUCCESS, FAILED
  final DateTime createdAt;

  Trade({
    required this.id,
    required this.symbol,
    required this.tradeType,
    required this.volume,
    this.openPrice,
    this.tp,
    this.sl,
    required this.status,
    required this.executionStatus,
    required this.createdAt,
  });

  factory Trade.fromJson(Map<String, dynamic> json) {
    final signal = json['signals'];
    final signalMap = signal is Map
        ? Map<String, dynamic>.from(signal)
        : <String, dynamic>{};
    final fallbackSymbol = json['symbol']?.toString() ??
        json['signal_id']?.toString() ??
        'UNKNOWN';
    final fallbackTradeType = json['trade_type']?.toString() ?? 'UNKNOWN';
    final fallbackStatus = json['status']?.toString() ?? 'OPEN';
    return Trade(
      id: json['id'],
      symbol: signalMap['symbol']?.toString() ?? fallbackSymbol,
      tradeType: signalMap['trade_type']?.toString() ?? fallbackTradeType,
      volume: (json['volume_executed'] ?? 0.0).toDouble(),
      openPrice: signalMap['open_price'] != null
          ? (signalMap['open_price'] as num).toDouble()
          : null,
      tp: signalMap['tp'] != null ? (signalMap['tp'] as num).toDouble() : null,
      sl: signalMap['sl'] != null ? (signalMap['sl'] as num).toDouble() : null,
      status: signalMap['status']?.toString() ?? fallbackStatus,
      executionStatus: json['execution_status']?.toString() ?? 'PENDING',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
