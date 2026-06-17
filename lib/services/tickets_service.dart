import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ticket_model.dart';

class TicketsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════════
  // LECTURE (GETTERS)
  // ═══════════════════════════════════════════════════════════════

  /// Récupère les billets d'un utilisateur — fonctionne offline grâce au cache.
  /// Firestore retourne d'abord les données du cache local (instantané),
  /// puis met à jour depuis le serveur dès que la connexion est disponible.
  Stream<List<TicketModel>> getUserTickets(String userId) {
    return _firestore
        .collection('mes_billets')
        .where('userId', isEqualTo: userId)
        // includeMetadataChanges: true → on reçoit les données du cache
        // immédiatement, puis la mise à jour serveur quand dispo
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      final tickets = snapshot.docs.map((doc) {
        return TicketModel.fromMap(doc.id, doc.data());
      }).toList();

      tickets.sort(_compareTicketsByUpcomingPriority);
      return tickets;
    });
  }

  /// Récupère les billets en vente (Optimisé pour Firebase)
  Stream<List<TicketModel>> getTicketsForSale() {
    return _firestore
        .collection('mes_billets')
        .where('enVente', isEqualTo: true)
        .where('saleStatus', isNotEqualTo: 'retire') // Filtrage côté serveur
        .snapshots()
        .map((snapshot) {
      final tickets = snapshot.docs.map((doc) {
        return TicketModel.fromMap(doc.id, doc.data());
      }).toList();

      tickets.sort(_compareTicketsByUpcomingPriority);
      return tickets;
    });
  }

  /// Récupère les billets d'une même commande PDF
  Stream<List<TicketModel>> getTicketsByPdfGroupId(String pdfGroupId) {
    return _firestore
        .collection('mes_billets')
        .where('pdfGroupId', isEqualTo: pdfGroupId)
        .snapshots()
        .map((snapshot) {
      final tickets = snapshot.docs.map((doc) {
        return TicketModel.fromMap(doc.id, doc.data());
      }).toList();

      tickets.sort(_compareTicketsByUpcomingPriority);
      return tickets;
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // ÉCRITURE (ADD / UPDATE / DELETE)
  // ═══════════════════════════════════════════════════════════════

  /// Ajoute un nouveau billet (Version synchronisée Mobile/Web)
  Future<void> addTicket(TicketModel ticket) async {
    // On utilise la méthode toMap() du modèle pour garantir la structure
    await _firestore.collection('mes_billets').add(ticket.toMap());
  }

  /// Met à jour uniquement le statut de vente
  Future<void> updateTicketSaleStatus({
    required String ticketId,
    required bool forSale,
  }) async {
    await _firestore.collection('mes_billets').doc(ticketId).update({
      'enVente': forSale,
      'saleStatus': forSale ? 'disponible' : 'retire',
    });
  }

  /// Met à jour l'intégralité d'un billet
  Future<void> updateTicket(TicketModel ticket) async {
    await _firestore.collection('mes_billets').doc(ticket.id).update(ticket.toMap());
  }

  /// Transmet un billet à un autre utilisateur via son email
  Future<void> transferTicketToUser({
    required String ticketId,
    required String targetEmail,
  }) async {
    final usersQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: targetEmail)
        .limit(1)
        .get();

    if (usersQuery.docs.isEmpty) {
      throw Exception('Aucun utilisateur trouvé avec cet email');
    }

    final targetUserId = usersQuery.docs.first.id;

    await _firestore.collection('mes_billets').doc(ticketId).update({
      'userId': targetUserId,
      'enVente': false,
      'saleStatus': 'retire',
    });
  }

  /// Supprime un billet définitivement
  Future<void> deleteTicket(String ticketId) async {
    await _firestore.collection('mes_billets').doc(ticketId).delete();
  }

  // ═══════════════════════════════════════════════════════════════
  // COFFRE-FORT (ACCÈS OFFLINE GARANTI)
  // ═══════════════════════════════════════════════════════════════

  /// Récupère les billets depuis le cache local UNIQUEMENT.
  /// Utilisé pour le mode coffre-fort — fonctionne sans connexion internet.
  /// Retourne les données de la dernière synchronisation avec Firestore.
  Future<List<TicketModel>> getCachedTickets(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('mes_billets')
          .where('userId', isEqualTo: userId)
          .get(const GetOptions(source: Source.cache));

      final tickets = snapshot.docs
          .map((doc) => TicketModel.fromMap(doc.id, doc.data()))
          .toList();

      tickets.sort(_compareTicketsByUpcomingPriority);
      return tickets;
    } catch (_) {
      // Cache vide ou non disponible — retourner liste vide
      return [];
    }
  }

  /// Récupère un billet spécifique depuis le cache (pour afficher le QR offline).
  Future<TicketModel?> getCachedTicket(String ticketId) async {
    try {
      final doc = await _firestore
          .collection('mes_billets')
          .doc(ticketId)
          .get(const GetOptions(source: Source.cache));
      if (!doc.exists) return null;
      return TicketModel.fromMap(doc.id, doc.data()!);
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // LOGIQUE INTERNE (HELPERS)
  // ═══════════════════════════════════════════════════════════════

  int _compareTicketsByUpcomingPriority(TicketModel a, TicketModel b) {
    final aDate = a.parsedDate ?? DateTime(2100);
    final bDate = b.parsedDate ?? DateTime(2100);
    final now = DateTime.now();

    final aIsUpcoming = !aDate.isBefore(now);
    final bIsUpcoming = !bDate.isBefore(now);

    if (aIsUpcoming && !bIsUpcoming) return -1;
    if (!aIsUpcoming && bIsUpcoming) return 1;

    if (aIsUpcoming && bIsUpcoming) {
      return aDate.compareTo(bDate);
    }
    return bDate.compareTo(aDate);
  }
}