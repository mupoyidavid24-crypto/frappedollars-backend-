import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KycService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<PlatformFile?> pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    return result.files.single;
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
    final Uint8List? rawBytes = document.bytes;
    if (rawBytes == null || rawBytes.isEmpty) {
      throw Exception('Le fichier KYC est vide ou illisible.');
    }
    final Uint8List bytes = document.bytes!;

    final safeFileName = document.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final storagePath = '$userId/${DateTime.now().millisecondsSinceEpoch}_$safeFileName';
    final contentType = _contentTypeForFile(document.name);

    debugPrint(
      'KYC upload start bucket=kyc-documents path=$storagePath file=${document.name} size=${bytes.length} contentType=$contentType',
    );

    try {
      final uploadedPath = await _client.storage.from('kyc-documents').uploadBinary(
        storagePath,
        bytes,
        fileOptions: FileOptions(
          contentType: contentType,
          upsert: true,
        ),
      );

      debugPrint('KYC upload success bucket=kyc-documents path=$uploadedPath');
    } catch (error, stackTrace) {
      debugPrint('KYC upload failed bucket=kyc-documents path=$storagePath error=$error');
      debugPrint('$stackTrace');
      rethrow;
    }

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