import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KycService {
  final SupabaseClient _client = Supabase.instance.client;

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

  Future<PlatformFile?> pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
      withReadStream: true,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    return result.files.first;
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

  Future<void> submitKyc({
    required String userId,
    required String fullName,
    required String phoneNumber,
    required DateTime dateOfBirth,
    required String addressLine,
    required String country,
    required String city,
    required String documentType,
    String? documentNumber,
    required PlatformFile document,
  }) async {
    final Uint8List? bytes = await _resolveBytes(document);
    if (bytes == null) {
      throw Exception('Le fichier KYC est vide.');
    }

    final safeFileName = document.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final storagePath = '$userId/${DateTime.now().millisecondsSinceEpoch}_$safeFileName';

    await _client.storage.from('kyc-documents').uploadBinary(
      storagePath,
      bytes,
      fileOptions: FileOptions(contentType: _contentTypeForFile(document.name)),
    );

    await _client.from('kyc_documents').insert({
      'user_id': userId,
      'document_type': documentType,
      'document_number': documentNumber,
      'address_line': addressLine,
      'country': country,
      'city': city,
      'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
      'file_url': storagePath,
      'status': 'PENDING',
      'submitted_at': DateTime.now().toIso8601String(),
    });

    await _client.from('profiles').update({
      'full_name': fullName,
      'phone_number': phoneNumber,
      'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
      'kyc_status': 'PENDING',
      'kyc_blocked': true,
    }).eq('id', userId);
  }
}