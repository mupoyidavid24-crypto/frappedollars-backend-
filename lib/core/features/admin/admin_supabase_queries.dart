class AdminSupabaseQueries {
  static const String profilesSelect =
      'id, email, full_name, phone_number, date_of_birth, kyc_status, kyc_blocked, role, is_vip, needs_vps, created_at';

  static const String tradingAccountsSelect =
      'id, user_id, mt5_login, account_type, is_active';

  static const String paymentsSelect =
      'id, client, payment_type, payment_status, amount, recipient_number, proof_url, created_at, reviewer_id, reviewed_at, review_reason';

  static const String notificationsSelect =
      'id, user_id, title, message, priority, created_at';

  static const String errorLogsSelect =
      'id, source, component, severity, message, details, user_id, mt5_login, trade_id, created_at';

  static const String copiedTradesSelect =
      'id, signal_id, client_account_id, volume_executed, execution_status, profit, error_message, created_at, closed_at';

  static const String vpsAssignmentsSelect =
      'id, user_id, status, provider, host_label, notes, last_heartbeat, last_restart_requested_at, created_at, updated_at';

  static const String paymentMethodsSelect =
      'id, provider, label, account_name, account_number, is_active, metadata, created_at, updated_at';
}