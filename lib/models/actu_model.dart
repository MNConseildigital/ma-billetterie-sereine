import 'package:cloud_firestore/cloud_firestore.dart';

class ActuModel {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String city;
  final Timestamp? dateAjout;
  final String partnerId;

  const ActuModel({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.city,
    required this.dateAjout,
    required this.partnerId,
  });

  factory ActuModel.fromMap(String id, Map<String, dynamic> map) {
    return ActuModel(
      id: id,
      title: map['Titre'] ?? '',
      description: map['Description'] ?? '',
      imageUrl: map['Image'] ?? '',
      city: map['ville'] ?? '',
      dateAjout: map['dateAjout'] as Timestamp?,
      partnerId: map['partnerId'] ?? '',
    );
  }
}