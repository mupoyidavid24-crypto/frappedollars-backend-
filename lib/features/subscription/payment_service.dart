import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/constants.dart';

class PaymentService {
  // final String _publicKey = "VOTRE_FLUTTERWAVE_PUBLIC_KEY";

  bool _isSubscriptionPaymentWindowOpen() {
    final currentDay = DateTime.now().weekday;
    return currentDay == DateTime.saturday || currentDay == DateTime.sunday;
  }

  Future<void> handlePayment({
    required BuildContext context,
    required double amount,
    required String type, // "COPY_TRADING_WEEKLY" or "VPS_MONTHLY"
    String? transactionId,
  }) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    if (!_isSubscriptionPaymentWindowOpen()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Les depots d\'abonnement sont disponibles uniquement le samedi et le dimanche.',
            ),
          ),
        );
      }
      return;
    }

    final String txRef = "FRAPP-TX-${const Uuid().v4()}";

    if (transactionId == null || transactionId.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Paiement initié (référence: $txRef). Validation backend en attente du transaction_id Flutterwave.',
            ),
          ),
        );
      }
      return;
    }

    final verified = await _verifyPaymentOnBackend(
      userId: user.id,
      transactionId: transactionId.trim(),
      type: type,
      amount: amount,
    );

    if (!verified) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paiement non vérifié côté backend.'),
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Paiement vérifié. Abonnement activé côté backend.")),
      );
    }
  }

  Future<bool> _verifyPaymentOnBackend({
    required String userId,
    required String transactionId,
    required String type,
    required double amount,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConstants.backendBaseUrl}/payments/verify'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'transaction_id': transactionId,
        'payment_type': type,
        'amount': amount,
        'currency': 'USD',
      }),
    );

    return response.statusCode == 200;
  }
}
