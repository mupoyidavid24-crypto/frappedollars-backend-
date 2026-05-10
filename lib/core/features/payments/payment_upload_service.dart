import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentUploadService {
  final supabase = Supabase.instance.client;

  Future<String?> uploadProof(PlatformFile file, String userId) async {
    final Uint8List? bytes = file.bytes;
    if (bytes == null) {
      throw Exception('Impossible de lire le fichier de preuve.');
    }

    final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final fileName = 'proof_${userId}_${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final storagePath = 'payments/$fileName';
    final uploadedPath = await supabase.storage.from('proofs').uploadBinary(storagePath, bytes);

    if (uploadedPath.isNotEmpty) {
      final publicUrl = supabase.storage.from('proofs').getPublicUrl(uploadedPath);
      return publicUrl;
    }
    return null;
  }
}
