import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentUploadService {
  final supabase = Supabase.instance.client;

  Future<Uint8List?> _resolveBytes(PlatformFile file) async {
    final directBytes = file.bytes;
    if (directBytes != null) {
      return directBytes;
    }

    final stream = file.readStream;
    if (stream == null) {
      return null;
    }

    final builder = BytesBuilder();
    await for (final chunk in stream) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  String _contentTypeForFile(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.pdf')) {
      return 'application/pdf';
    }
    return 'application/octet-stream';
  }

  Future<String?> uploadProof(PlatformFile file, String userId) async {
    final Uint8List? bytes = await _resolveBytes(file);
    if (bytes == null) {
      throw Exception('Impossible de lire le fichier de preuve.');
    }

    final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final fileName = 'proof_${userId}_${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final storagePath = 'payments/$fileName';
    final uploadedPath = await supabase.storage.from('proofs').uploadBinary(
      storagePath,
      bytes,
      fileOptions: FileOptions(contentType: _contentTypeForFile(file.name)),
    );

    if (uploadedPath.isNotEmpty) {
      final publicUrl = supabase.storage.from('proofs').getPublicUrl(uploadedPath);
      return publicUrl;
    }
    return null;
  }
}
