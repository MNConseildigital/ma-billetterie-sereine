import 'package:cloud_firestore/cloud_firestore.dart';

class TicketModel {
  final String id;
  final String category;
  final String createdAt;
  final String date;
  final String seat;
  final bool forSale;
  final String saleStatus;
  final String time;
  final List<String> images;
  final String pdfUrl;
  final String pdfGroupId;
  final String place;
  final int nbPlaces;
  final String eventName;
  final String price;
  final String salePrice; // Prix de vente choisi par le vendeur (peut différer de price)
  final String qr;
  final bool reminderActive;
  final int timestamp;
  final String userId;
  final String city;
  final String? pendingBuyerId; // Acheteur en attente de confirmation

  const TicketModel({
    required this.id,
    required this.category,
    required this.createdAt,
    required this.date,
    required this.seat,
    required this.forSale,
    required this.saleStatus,
    required this.time,
    required this.images,
    required this.pdfUrl,
    required this.pdfGroupId,
    required this.place,
    required this.nbPlaces,
    required this.eventName,
    required this.price,
    this.salePrice = '',
    required this.qr,
    required this.reminderActive,
    required this.timestamp,
    required this.userId,
    required this.city,
    this.pendingBuyerId,
  });

  factory TicketModel.fromMap(String id, Map<String, dynamic> map) {
    // 1. Gestion ultra-flexible de la DATE
    String dateStr = '';
    if (map['date'] is Timestamp) {
      DateTime dt = (map['date'] as Timestamp).toDate();
      dateStr = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
    } else {
      dateStr = map['date']?.toString() ?? '';
    }

    // 2. Gestion ultra-flexible du CREATED AT
    String createdStr = '';
    if (map['creeLe'] is Timestamp) {
      createdStr = (map['creeLe'] as Timestamp).toDate().toString();
    } else {
      createdStr = map['creeLe']?.toString() ?? '';
    }

    final rawImages = map['images'];
    List<String> parsedImages = [];
    if (rawImages is List) {
      parsedImages = rawImages.map((e) => e.toString()).toList();
    }

    return TicketModel(
      id: id,
      category: map['categorie'] ?? '',
      createdAt: createdStr,
      date: dateStr,
      seat: map['emplacement'] ?? '',
      forSale: map['enVente'] ?? false,
      saleStatus: map['saleStatus'] ?? 'disponible',
      time: map['heure'] ?? '',
      images: parsedImages,
      pdfUrl: map['pdfUrl'] ?? '',
      pdfGroupId: map['pdfGroupId'] ?? '',
      place: map['lieu'] ?? '',
      nbPlaces: map['nbPlaces'] ?? 0,
      eventName: map['nom'] ?? '',
      price: map['prix']?.toString() ?? '',
      salePrice: map['prixVente']?.toString() ?? '',
      qr: map['qr']?.toString() ?? '',
      reminderActive: map['rappelActif'] ?? false,
      timestamp: map['timestamp'] is int ? map['timestamp'] : 0,
      userId: map['userId'] ?? '',
      city: map['ville'] ?? '',
      pendingBuyerId: map['pendingBuyerId']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'categorie': category,
      'creeLe': createdAt,
      // On sauvegarde en tant que vrai Timestamp pour le Web et les tris
      'date': parsedDate != null ? Timestamp.fromDate(parsedDate!) : date,
      'emplacement': seat,
      'enVente': forSale,
      'saleStatus': saleStatus,
      'heure': time,
      'images': images,
      'pdfUrl': pdfUrl,
      'pdfGroupId': pdfGroupId,
      'lieu': place,
      'nbPlaces': nbPlaces,
      'nom': eventName,
      'prix': price,
      'prixVente': salePrice,
      'qr': qr,
      'rappelActif': reminderActive,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'userId': userId,
      'ville': city,
      if (pendingBuyerId != null) 'pendingBuyerId': pendingBuyerId,
    };
  }

  // Helpers pour les calculs
  DateTime? get parsedDate {
    try {
      if (date.contains('/')) {
        final parts = date.split('/');
        return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
      return DateTime.tryParse(date);
    } catch (_) {
      return null;
    }
  }
}