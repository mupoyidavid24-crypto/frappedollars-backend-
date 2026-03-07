import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class PaymentUploadService {
  final supabase = Supabase.instance.client;

  Future<String?> uploadProof(File file, String userId) async {
    final fileName = 'proof_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storagePath = 'payments/$fileName';
    final response = await supabase.storage.from('proofs').upload(storagePath, file);
    // response est une String ou un objet, donc on vérifie le succès par la présence du chemin ou d'une erreur
    if (response is String && !response.contains('error')) {
      return supabase.storage.from('proofs').getPublicUrl(storagePath);
    }
    // Si response est un objet avec error
    if (response is Map && response['error'] == null) {
      return supabase.storage.from('proofs').getPublicUrl(storagePath);
    }
    return null;
  }
}
