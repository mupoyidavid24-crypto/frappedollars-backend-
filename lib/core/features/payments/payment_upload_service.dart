import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class PaymentUploadService {
  final supabase = Supabase.instance.client;

  Future<String?> uploadProof(File file, String userId, String paymentMethod) async {
    final fileName = 'proof_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storagePath = 'payments/$fileName';
    final response = await supabase.storage.from('proofs').upload(storagePath, file);

    // Enregistre le moyen de paiement dans Supabase (table payments)
    if (response is String || (response is Map && !response.containsKey('error'))) {
      final publicUrl = supabase.storage.from('proofs').getPublicUrl(storagePath);
      await supabase.from('payments').insert({
        'user_id': userId,
        'proof_url': publicUrl.url ?? publicUrl.toString(),
        'payment_method': paymentMethod,
        'created_at': DateTime.now().toIso8601String(),
      });
      return publicUrl.url ?? publicUrl.toString();
    }
    // Si la réponse est une Map contenant une clé 'error', c'est un échec
    if (response is Map && response.containsKey('error')) {
      return null;
    }
    // Sinon, retourne null
    return null;
  }
}
