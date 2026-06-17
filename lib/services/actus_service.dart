import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/actu_model.dart';

class ActusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<ActuModel>> getActus() {
    return _firestore
        .collection('actus')
        .orderBy('dateAjout', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ActuModel.fromMap(doc.id, doc.data());
      }).toList();
    });
  }
}