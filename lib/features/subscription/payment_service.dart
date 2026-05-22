import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/constants.dart';
import '../../core/features/payments/payment_form.dart';

class PaymentService {
  Future<void> handlePayment({
    required BuildContext context,
    required double amount,
    required String type, // "COPY_TRADING_WEEKLY" or "VPS_MONTHLY"
  }) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    final profileResponse = await client
        .from('profiles')
        .select('full_name, phone_number')
        .eq('id', user.id)
        .maybeSingle();
    final profile = profileResponse;
    if (!context.mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentForm(
          paymentType: type,
          expectedAmount: amount,
          fullName: profile?['full_name']?.toString(),
          phoneNumber: profile?['phone_number']?.toString(),
        ),
      ),
    );
  }
}
