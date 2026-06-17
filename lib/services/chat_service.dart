// lib/services/chat_service.dart
//
// Service de messagerie interne --- Ma Billetterie Sereine

import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart'; // ← NOUVEAU
import '../models/ticket_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Créer ou récupérer une conversation ───────────────────────
  Future<String> getOrCreateConversation({
    required String currentUserId,
    required String otherUserId,
    required TicketModel ticket,
  }) async {
    // Cherche si une conversation existe déjà pour ce billet entre ces 2 users
    final existingQuery = await _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .where('ticketId', isEqualTo: ticket.id)
        .get();

    // Vérifie si l'autre user est aussi dans la conversation
    for (final doc in existingQuery.docs) {
      final participants = List<String>.from(doc.data()['participants'] ?? []);
      if (participants.contains(otherUserId)) {
        return doc.id;
      }
    }

    // Sinon, crée une nouvelle conversation
    final docRef = await _firestore.collection('conversations').add({
      'participants': [currentUserId, otherUserId],
      'ticketId': ticket.id,
      'ticketTitle': ticket.eventName,
      'ticketPrice': ticket.price,
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadBy': otherUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  // ── Envoyer un message ────────────────────────────────────────
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;

    final batch = _firestore.batch();

    // Ajoute le message
    final messageRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc();

    batch.set(messageRef, {
      'senderId': senderId,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });

    // Met à jour la conversation
    final convRef = _firestore.collection('conversations').doc(conversationId);

    // Récupère l'autre participant pour unreadBy
    final convDoc = await convRef.get();
    final participants = List<String>.from(convDoc.data()?['participants'] ?? []);
    final otherUserId = participants.firstWhere(
          (id) => id != senderId,
      orElse: () => '',
    );

    batch.update(convRef, {
      'lastMessage': text.trim(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadBy': otherUserId,
    });

    await batch.commit();

    // NOUVEAU : Notifie le destinataire
    final senderName = await getUserDisplayName(senderId);
    final convData = convDoc.data();
    final ticketTitle = convData?['ticketTitle']?.toString() ?? 'Billet';

    await NotificationService.showNewMessageNotification(
      senderName: senderName,
      ticketTitle: ticketTitle,
    );
  }

  // ── Marquer comme lu ──────────────────────────────────────────
  Future<void> markAsRead({
    required String conversationId,
    required String currentUserId,
  }) async {
    await _firestore.collection('conversations').doc(conversationId).update({
      'unreadBy': '',
    });

    // Marque tous les messages non lus comme lus
    final unreadMessages = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('read', isEqualTo: false)
        .where('senderId', isNotEqualTo: currentUserId)
        .get();

    final batch = _firestore.batch();
    for (final doc in unreadMessages.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // ── Stream des conversations de l'utilisateur ─────────────────
  Stream<List<Map<String, dynamic>>> getUserConversations(String userId) {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    });
  }

  // ── Stream des messages d'une conversation ────────────────────
  Stream<List<Map<String, dynamic>>> getMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    });
  }

  // ── Récupérer le nom d'un utilisateur ─────────────────────────
  Future<String> getUserDisplayName(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return 'Utilisateur';
      final data = doc.data() ?? {};
      return data['displayName']?.toString() ??
          data['nom']?.toString() ??
          data['email']?.toString() ??
          'Utilisateur';
    } catch (_) {
      return 'Utilisateur';
    }
  }
}