import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class TicketPdfService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadTicketPdf(File file, String userId) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.pdf';
    final ref = _storage.ref().child('tickets_pdf/$userId/$fileName');

    final metadata = SettableMetadata(
      contentType: 'application/pdf',
    );

    final uploadTask = ref.putFile(file, metadata);

    final snapshot = await uploadTask.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw Exception('Temps dépassé lors de l’envoi du PDF');
      },
    );

    return await snapshot.ref.getDownloadURL();
  }
}