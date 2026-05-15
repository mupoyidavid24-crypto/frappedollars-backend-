class BusinessRules {
  final String currency;
  final double copyTradingWeeklyPrice;
  final double vpsMonthlyPrice;
  final double weeklyProfitLimit;
  final String weeklyProfitLimitNature;
  final String weeklyProfitLimitDescription;
  final double minimumCapitalRequired;
  final List<int> subscriptionPaymentWindowWeekdays;

  const BusinessRules({
    required this.currency,
    required this.copyTradingWeeklyPrice,
    required this.vpsMonthlyPrice,
    required this.weeklyProfitLimit,
    required this.weeklyProfitLimitNature,
    required this.weeklyProfitLimitDescription,
    required this.minimumCapitalRequired,
    required this.subscriptionPaymentWindowWeekdays,
  });

  factory BusinessRules.fromJson(Map<String, dynamic> json) {
    return BusinessRules(
      currency: json['currency']?.toString() ?? 'USD',
      copyTradingWeeklyPrice: _toDouble(json['copy_trading_weekly_price']),
      vpsMonthlyPrice: _toDouble(json['vps_monthly_price']),
      weeklyProfitLimit: _toDouble(json['weekly_profit_limit']),
      weeklyProfitLimitNature: json['weekly_profit_limit_nature']?.toString() ?? 'technical_limit',
      weeklyProfitLimitDescription:
          json['weekly_profit_limit_description']?.toString() ??
          "Limite technique de protection: la copie s'arrete automatiquement lorsque le profit hebdomadaire atteint 120 USD.",
      minimumCapitalRequired: _toDouble(json['minimum_capital_required']),
      subscriptionPaymentWindowWeekdays: _toIntList(json['subscription_payment_window_weekdays']),
    );
  }

  bool isSubscriptionPaymentWindowOpen(DateTime dateTime) {
    return subscriptionPaymentWindowWeekdays.contains(dateTime.weekday);
  }

  bool get isWeeklyProfitLimitTechnical => weeklyProfitLimitNature.toLowerCase() == 'technical_limit';

  String get weeklyProfitLimitLabel {
    if (isWeeklyProfitLimitTechnical) {
      return weeklyProfitLimitDescription;
    }
    return 'Plafond hebdomadaire de profit: ${weeklyProfitLimit.toStringAsFixed(0)} $currency';
  }

  String get subscriptionPaymentWindowDescription {
    if (subscriptionPaymentWindowWeekdays.isEmpty) {
      return 'la fenêtre de paiement';
    }

    final labels = subscriptionPaymentWindowWeekdays.map(_weekdayName).toList(growable: false);
    if (labels.length == 1) {
      return labels.first;
    }
    if (labels.length == 2) {
      return '${labels[0]} et ${labels[1]}';
    }
    return '${labels.sublist(0, labels.length - 1).join(', ')} et ${labels.last}';
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static List<int> _toIntList(dynamic value) {
    if (value is List) {
      return value.whereType<num>().map((item) => item.toInt()).toList(growable: false);
    }
    return const [5, 6];
  }

  static String _weekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'lundi';
      case DateTime.tuesday:
        return 'mardi';
      case DateTime.wednesday:
        return 'mercredi';
      case DateTime.thursday:
        return 'jeudi';
      case DateTime.friday:
        return 'vendredi';
      case DateTime.saturday:
        return 'samedi';
      case DateTime.sunday:
        return 'dimanche';
      default:
        return 'jour inconnu';
    }
  }
}
