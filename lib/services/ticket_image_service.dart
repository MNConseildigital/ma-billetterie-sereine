import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as p;

class TicketImageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Compresse l'image avant l'envoi pour économiser le quota Firebase
  Future<File?> _compressImage(File file) async {
    try {
      final dir = await path_provider.getTemporaryDirectory();
      final targetPath = p.join(
          dir.absolute.path,
          "temp_${DateTime.now().millisecondsSinceEpoch}.jpg"
      );

      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
        format: CompressFormat.jpeg,
      );

      return result != null ? File(result.path) : null;
    } catch (e) {
      print("Erreur de compression : $e");
      return file;
    }
  }

  Future<String> uploadTicketImage(File file, String userId) async {
    // 1. COMPRESSION AUTOMATIQUE
    File fileToUpload = await _compressImage(file) ?? file;

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child('tickets/$userId/$fileName');

    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
    );

    // 2. ENVOI DU FICHIER COMPRESSÉ
    final uploadTask = ref.putFile(fileToUpload, metadata);

    final snapshot = await uploadTask.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw Exception('Temps dépassé lors de l\'envoi de la photo');
      },
    );

    final downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  }
}