import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class PaymentUploadService {
  final supabase = Supabase.instance.client;

  Future<String?> uploadProof(File file, String userId, String paymentMethod) async {
    final fileName = 'proof_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storagePath = 'payments/$fileName';
    final uploadedPath = await supabase.storage.from('proofs').upload(storagePath, file);

    if (uploadedPath.isNotEmpty) {
      final publicUrl = supabase.storage.from('proofs').getPublicUrl(uploadedPath);
      await supabase.from('payments').insert({
        'user_id': userId,
        'proof_url': publicUrl,
        'payment_method': paymentMethod,
        'created_at': DateTime.now().toIso8601String(),
      });
      return publicUrl;
    }
    return null;
  }
}
