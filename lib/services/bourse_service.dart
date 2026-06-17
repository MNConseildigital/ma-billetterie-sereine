import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ticket_model.dart';

class BourseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth     _auth      = FirebaseAuth.instance;

  /// Met un billet en vente avec un prix de vente personnalisable.
  /// [salePrice] : prix choisi par le vendeur (peut différer du prix d'achat).
  Future<void> putTicketForSale(
      TicketModel ticket, {
        required String salePrice,
      }) async {
    try {
      await _firestore.collection('mes_billets').doc(ticket.id).update({
        'enVente': true,
        'saleStatus': 'disponible',
        'prixVente': salePrice,          // prix de vente choisi par le vendeur
        'dateMiseEnVente': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Erreur lors de la mise en vente: $e');
      throw Exception('Impossible de mettre le billet en vente');
    }
  }

  /// Retire un billet de la vente.
  Future<void> withdrawFromSale(String ticketId) async {
    try {
      await _firestore.collection('mes_billets').doc(ticketId).update({
        'enVente': false,
        'saleStatus': 'retire',
      });
    } catch (e) {
      print('Erreur lors du retrait de la vente: $e');
      throw Exception('Impossible de retirer le billet de la vente');
    }
  }

  /// Récupère les billets en vente avec filtres.
  Stream<List<TicketModel>> getFilteredTickets({
    String? category,
    String? city,
  }) {
    // On récupère l'uid du user connecté pour l'exclure des résultats
    // (un vendeur ne doit pas voir ses propres billets dans la Bourse)
    final currentUserId = _auth.currentUser?.uid;

    Query query = _firestore
        .collection('mes_billets')
        .where('enVente', isEqualTo: true)
        .where('saleStatus', whereIn: ['disponible', 'reserve']);

    if (category != null && category.isNotEmpty && category != 'Toutes') {
      query = query.where('categorie', isEqualTo: category);
    }
    if (city != null && city.isNotEmpty && city != 'Toutes') {
      query = query.where('ville', isEqualTo: city);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) =>
              TicketModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          // Exclure les billets appartenant à l'utilisateur connecté
          .where((ticket) => ticket.userId != currentUserId)
          .toList();
    });
  }

  /// Récupère les infos du vendeur.
  Future<Map<String, String>> getSellerContact(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        return {
          'name': data['displayName']?.toString() ?? 'Vendeur anonyme',
          'email': data['email']?.toString() ?? '',
          'phone': data['phone']?.toString() ?? 'Non renseigné',
          'photoUrl': data['photoUrl']?.toString() ?? '',
        };
      }
    } catch (e) {
      print('Erreur contact vendeur: $e');
    }
    return {'name': 'Utilisateur inconnu'};
  }

  /// Crée ou récupère une conversation de chat entre acheteur et vendeur.
  Future<String> createConversation(
      String currentUserId, String sellerId, String ticketId) async {
    final chatQuery = await _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .get();

    for (var doc in chatQuery.docs) {
      List participants = doc['participants'];
      if (participants.contains(sellerId)) {
        return doc.id;
      }
    }

    final newChat = await _firestore.collection('chats').add({
      'participants': [currentUserId, sellerId],
      'lastMessage': 'Demande pour un billet',
      'lastUpdate': FieldValue.serverTimestamp(),
      'ticketId': ticketId,
    });

    return newChat.id;
  }

  /// Étape 1 — Acheteur réserve le billet (état intermédiaire).
  /// Le billet passe en "réservé" : plus visible dans la liste,
  /// mais le transfert n'est pas encore effectué.
  Future<void> reserveTicket({
    required String ticketId,
    required String buyerId,
  }) async {
    await _firestore.collection('mes_billets').doc(ticketId).update({
      'saleStatus': 'reserve',
      'pendingBuyerId': buyerId,
      'reservedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Étape 2 — Vendeur confirme et transfère le billet à l'acheteur.
  /// À appeler uniquement après confirmation explicite du vendeur.
  Future<void> confirmTransfer({
    required String ticketId,
    required String sellerId,
    required String buyerId,
  }) async {
    // Vérification : seul le vendeur (userId actuel) peut confirmer
    final doc = await _firestore.collection('mes_billets').doc(ticketId).get();
    if (!doc.exists) throw Exception('Billet introuvable');

    final data = doc.data()!;
    if (data['userId'] != sellerId) {
      throw Exception('Seul le vendeur peut confirmer le transfert');
    }
    if (data['pendingBuyerId'] != buyerId) {
      throw Exception('Acheteur non autorisé pour ce transfert');
    }

    await _firestore.collection('mes_billets').doc(ticketId).update({
      'userId'          : buyerId,
      'enVente'         : false,
      'saleStatus'      : 'vendu',
      'transferredAt'   : FieldValue.serverTimestamp(),
      'transferredFrom' : sellerId,
      'pendingBuyerId'  : FieldValue.delete(),
    });
  }

  /// Annuler une réservation (vendeur ou acheteur peuvent annuler).
  Future<void> cancelReservation({required String ticketId}) async {
    await _firestore.collection('mes_billets').doc(ticketId).update({
      'saleStatus'     : 'disponible',
      'pendingBuyerId' : FieldValue.delete(),
      'reservedAt'     : FieldValue.delete(),
    });
  }

  /// [Déprécié] — utiliser reserveTicket() + confirmTransfer() à la place.
  /// Conservé pour compatibilité, redirige vers confirmTransfer.
  Future<void> transferTicket({
    required String ticketId,
    required String sellerId,
    required String buyerId,
  }) async {
    await confirmTransfer(
      ticketId: ticketId,
      sellerId: sellerId,
      buyerId: buyerId,
    );
  }
}