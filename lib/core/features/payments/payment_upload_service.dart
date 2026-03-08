import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class PaymentUploadService {
  final supabase = Supabase.instance.client;

  Future<String?> uploadProof(File file, String userId) async {
    final fileName = 'proof_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storagePath = 'payments/$fileName';
    final response = await supabase.storage.from('proofs').upload(storagePath, file);

    // Si response est une String (chemin), succès
    if (response is String) {
      return supabase.storage.from('proofs').getPublicUrl(storagePath);
    }
    // Si response est un Map avec une clé 'error', échec
    if (response is Map && response['error'] != null) {
      return null;
    }
    // Si response est un Map sans erreur, succès
    if (response is Map) {
      return supabase.storage.from('proofs').getPublicUrl(storagePath);
    }
    return null;
  }
}
