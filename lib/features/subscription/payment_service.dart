import 'package:flutter/material.dart';
// import 'package:flutterwave_standard/flutterwave.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class PaymentService {
  // final String _publicKey = "VOTRE_FLUTTERWAVE_PUBLIC_KEY";

  Future<void> handlePayment({
    required BuildContext context,
    required double amount,
    required String type, // "COPY_TRADING_WEEKLY" or "VPS_MONTHLY"
  }) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    final String txRef = "FRAPP-TX-${const Uuid().v4()}";

    // final Customer customer = Customer(
    //   name: user.email!.split('@')[0],
    //   email: user.email!,
    //   phoneNumber: "000000000",
    // );

    // final Flutterwave flutterwave = Flutterwave(
    //   context: context,
    //   publicKey: _publicKey,
    //   currency: "USD",
    //   redirectUrl: "https://frappeddollars.com",
    //   txRef: txRef,
    //   amount: amount.toString(),
    //   customer: customer,
    //   paymentOptions: "card, account, ussd",
    //   customization: Customization(title: "Abonnement FrappedDollars"),
    //   isTestMode: true,
    // );

    await _activateSubscription(user.id, type, txRef);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Paiement réussi ! Abonnement activé.")),
      );
    }
  }

  Future<void> _activateSubscription(String userId, String type, String ref) async {
    final now = DateTime.now();
    final endDate = type == "COPY_TRADING_WEEKLY" 
        ? now.add(const Duration(days: 7)) 
        : now.add(const Duration(days: 30));

    await Supabase.instance.client.from('subscriptions').insert({
      'user_id': userId,
      'type': type,
      'status': 'ACTIVE',
      'start_date': now.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'transaction_ref': ref,
    });
  }
}
