import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/business_rules_model.dart';

class AdminBusinessRulesService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<BusinessRules> fetchBusinessRules() async {
    final response = await _client
        .from('business_rules')
        .select('id, currency, copy_trading_weekly_price, vps_monthly_price, weekly_profit_limit, weekly_profit_limit_nature, weekly_profit_limit_description, minimum_capital_required, subscription_payment_window_weekdays, updated_at')
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) {
      return BusinessRules.fromJson(const {});
    }

    return BusinessRules.fromJson(Map<String, dynamic>.from(response as Map));
  }

  static Future<bool> updateBusinessRules(Map<String, dynamic> payload) async {
    final current = await _client.from('business_rules').select('id').order('updated_at', ascending: false).limit(1).maybeSingle();

    if (current != null && current['id'] != null) {
      await _client.from('business_rules').update(payload).eq('id', current['id']);
      return true;
    }

    await _client.from('business_rules').insert(payload);
    return true;
  }
}
