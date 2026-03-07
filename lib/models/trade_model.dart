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
    // Note: This assumes a join between copied_trades and signals
    final signal = json['signals'];
    return Trade(
      id: json['id'],
      symbol: signal['symbol'],
      tradeType: signal['trade_type'],
      volume: (json['volume_executed'] ?? 0.0).toDouble(),
      openPrice: (signal['open_price'] ?? 0.0).toDouble(),
      tp: (signal['tp'] ?? 0.0).toDouble(),
      sl: (signal['sl'] ?? 0.0).toDouble(),
      status: signal['status'],
      executionStatus: json['execution_status'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
