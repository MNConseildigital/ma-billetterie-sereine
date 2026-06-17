// lib/services/transaction_service.dart
//
// Service Historique des transactions --- Ma Billetterie Sereine

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ticket_model.dart';

class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Billets vendus par l'utilisateur ──────────────────────────
  Stream<List<Map<String, dynamic>>> getSoldTickets(String userId) {
    return _firestore
        .collection('mes_billets')
        .where('transferredFrom', isEqualTo: userId)
        .orderBy('transferredAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final ticket = TicketModel.fromMap(doc.id, doc.data());
        return {
          'ticket': ticket,
          'date': doc.data()['transferredAt'],
          'type': 'vendu',
        };
      }).toList();
    });
  }

  // ── Billets achetés par l'utilisateur ─────────────────────────
  Stream<List<Map<String, dynamic>>> getBoughtTickets(String userId) {
    return _firestore
        .collection('mes_billets')
        .where('userId', isEqualTo: userId)
        .where('transferredFrom', isNotEqualTo: null)
        .orderBy('transferredAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final ticket = TicketModel.fromMap(doc.id, doc.data());
        return {
          'ticket': ticket,
          'date': doc.data()['transferredAt'],
          'type': 'achete',
        };
      }).toList();
    });
  }

  // ── Demandes d'achat en attente (pour le vendeur) ─────────────
  Stream<List<Map<String, dynamic>>> getPendingRequests(String sellerId) {
    return _firestore
        .collection('demandes_achat')
        .where('sellerUserId', isEqualTo: sellerId)
        .where('status', isEqualTo: 'en_attente')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'eventName': data['eventName'] ?? 'Billet',
          'buyerEmail': data['buyerEmail'] ?? '',
          'buyerUserId': data['buyerUserId'] ?? '',
          'createdAt': data['createdAt'],
          'status': data['status'] ?? 'en_attente',
        };
      }).toList();
    });
  }

  // ── Accepter une demande d'achat ──────────────────────────────
  Future<void> acceptPurchaseRequest({
    required String requestId,
    required String ticketId,
    required String buyerUserId,
  }) async {
    final batch = _firestore.batch();

    // Met à jour la demande
    final requestRef = _firestore.collection('demandes_achat').doc(requestId);
    batch.update(requestRef, {'status': 'accepte'});

    // Transfère le billet
    final ticketRef = _firestore.collection('mes_billets').doc(ticketId);
    batch.update(ticketRef, {
      'userId': buyerUserId,
      'enVente': false,
      'saleStatus': 'vendu',
      'transferredAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ── Refuser une demande d'achat ───────────────────────────────
  Future<void> rejectPurchaseRequest(String requestId) async {
    await _firestore.collection('demandes_achat').doc(requestId).update({
      'status': 'refuse',
    });
  }
}