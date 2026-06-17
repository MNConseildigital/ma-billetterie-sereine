import 'package:cloud_firestore/cloud_firestore.dart';

class TicketCreateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addTicket({
    required String userId,
    required String category,
    required String date,
    required String seat,
    required bool forSale,
    required String time,
    required List<String> images,
    required String pdfUrl,
    required String pdfGroupId,
    required String place,
    required int nbPlaces,
    required String eventName,
    required String price,
    required String qr,
    required bool reminderActive,
    required String city,
  }) async {
    await _firestore.collection('mes_billets').add({
      'categorie': category,
      // Utilisation de FieldValue.serverTimestamp() pour une précision parfaite
      'creeLe': FieldValue.serverTimestamp(),
      'date': date,
      'emplacement': seat,
      'enVente': forSale,
      'saleStatus': forSale ? 'disponible' : 'retire',
      'heure': time,
      'images': images,
      'pdfUrl': pdfUrl,
      'pdfGroupId': pdfGroupId,
      'lieu': place,
      'nbPlaces': nbPlaces,
      'nom': eventName,
      'prix': price,
      'qr': qr,
      'rappelActif': reminderActive,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'userId': userId,
      'ville': city,
    });
  }
}