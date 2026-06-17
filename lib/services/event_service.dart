// lib/services/event_service.dart
//
// Service événements — Ma Billetterie Sereine
// ⚠️  IMPORTANT : toutes les requêtes Firestore ont un .limit()
//     pour éviter le OutOfMemoryError (crash sur gros volumes)

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart';

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Jamais plus de N documents chargés en mémoire à la fois
  static const int _defaultLimit  = 80;
  static const int _featuredLimit = 20;
  static const int _nearMeLimit   = 150; // géo = besoin de plus pour bien filtrer

  // ────────────────────────────────────────────────────────
  // Tous les événements actifs (paginés)
  // ────────────────────────────────────────────────────────
  Stream<List<EventModel>> getEvents() {
    return _firestore
        .collection('events')
        .where('isActive', isEqualTo: true)
        .limit(_defaultLimit)
        .snapshots()
        .map((s) => s.docs
        .map((d) => EventModel.fromMap(d.id, d.data()))
        .toList());
  }

  // ────────────────────────────────────────────────────────
  // Événements mis en avant
  // ────────────────────────────────────────────────────────
  Stream<List<EventModel>> getFeaturedEvents() {
    return _firestore
        .collection('events')
        .where('featured', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .limit(_featuredLimit)
        .snapshots()
        .map((s) => s.docs
        .map((d) => EventModel.fromMap(d.id, d.data()))
        .toList());
  }

  // ────────────────────────────────────────────────────────
  // Recherche — filtre côté client sur un lot limité
  // ────────────────────────────────────────────────────────
  Stream<List<EventModel>> searchEvents({
    String? query,
    String? category,
    String? source,
  }) {
    // Si filtrage par catégorie Firestore → on peut se permettre plus de docs
    // Si recherche texte libre → on limite fort (filtre client)
    final limit = _defaultLimit;

    Query<Map<String, dynamic>> q = _firestore
        .collection('events')
        .where('isActive', isEqualTo: true);

    // Filtre catégorie côté Firestore si possible (réduit les données reçues)
    if (category != null && category.isNotEmpty && category != 'Tous') {
      q = q.where('category', isEqualTo: category);
    }

    // Filtre source côté Firestore
    if (source != null && source.isNotEmpty) {
      q = q.where('source', isEqualTo: source);
    }

    return q.limit(limit).snapshots().map((snapshot) {
      List<EventModel> events = snapshot.docs
          .map((doc) => EventModel.fromMap(doc.id, doc.data()))
          .toList();

      // Filtre texte résiduel côté client
      if (query != null && query.trim().isNotEmpty) {
        final qStr = query.trim().toLowerCase();
        events = events.where((e) {
          return e.title.toLowerCase().contains(qStr)      ||
              e.city.toLowerCase().contains(qStr)       ||
              e.location.toLowerCase().contains(qStr)   ||
              e.department.toLowerCase().contains(qStr) ||
              e.region.toLowerCase().contains(qStr)     ||
              e.description.toLowerCase().contains(qStr);
        }).toList();
      }

      events.sort((a, b) => _compareDates(a.date, b.date));
      return events;
    });
  }

  // ────────────────────────────────────────────────────────
  // Événements à proximité (géolocalisation)
  // ────────────────────────────────────────────────────────
  Stream<List<EventModel>> getEventsNearMe({
    required double latitude,
    required double longitude,
    double radiusKm = 30,
    String? category,
  }) {
    Query<Map<String, dynamic>> q = _firestore
        .collection('events')
        .where('isActive', isEqualTo: true);

    if (category != null && category.isNotEmpty && category != 'Tous') {
      q = q.where('category', isEqualTo: category);
    }

    return q.limit(_nearMeLimit).snapshots().map((snapshot) {
      List<EventModel> events = snapshot.docs
          .map((doc) => EventModel.fromMap(doc.id, doc.data()))
          .where((e) => e.latitude != 0 && e.longitude != 0)
          .where((e) =>
      _haversineKm(latitude, longitude, e.latitude, e.longitude) <=
          radiusKm)
          .toList();

      events.sort((a, b) {
        final dA = _haversineKm(latitude, longitude, a.latitude, a.longitude);
        final dB = _haversineKm(latitude, longitude, b.latitude, b.longitude);
        return dA.compareTo(dB);
      });

      return events;
    });
  }

  // ────────────────────────────────────────────────────────
  // Événements par source
  // ────────────────────────────────────────────────────────
  Stream<List<EventModel>> getEventsBySource(String source) {
    return _firestore
        .collection('events')
        .where('isActive', isEqualTo: true)
        .where('source',   isEqualTo: source)
        .limit(_defaultLimit)
        .snapshots()
        .map((s) => s.docs
        .map((d) => EventModel.fromMap(d.id, d.data()))
        .toList());
  }

  // ────────────────────────────────────────────────────────
  // Statistiques par source
  // ────────────────────────────────────────────────────────
  Future<Map<String, int>> getSourceStats() async {
    final snapshot = await _firestore
        .collection('events')
        .where('isActive', isEqualTo: true)
        .get();

    final Map<String, int> stats = {
      'openagenda':   0,
      'ticketmaster': 0,
      'manual':       0,
      'total':        snapshot.docs.length,
    };

    for (final doc in snapshot.docs) {
      final src = (doc.data()['source'] as String?) ?? 'manual';
      stats[src] = (stats[src] ?? 0) + 1;
    }
    return stats;
  }

  // ────────────────────────────────────────────────────────
  // Utilitaires privés
  // ────────────────────────────────────────────────────────
  double _haversineKm(
      double lat1, double lon1,
      double lat2, double lon2,
      ) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = _sin2(dLat / 2) +
        _cos(_rad(lat1)) * _cos(_rad(lat2)) * _sin2(dLon / 2);
    return r * 2 * _asin(_sqrt(a));
  }

  double _rad(double deg)  => deg * 3.141592653589793 / 180;
  double _sin2(double x)   => _sin(x) * _sin(x);
  double _sin(double x)    => x - x * x * x / 6 + x * x * x * x * x / 120;
  double _cos(double x)    => 1 - x * x / 2 + x * x * x * x / 24;
  double _sqrt(double x)   => x <= 0
      ? 0
      : x < 1
      ? x * (1 + (1 - x) / 2)
      : _sqrtNewton(x, x / 2);
  double _sqrtNewton(double x, double g) {
    final g2 = (g + x / g) / 2;
    return (g2 - g).abs() < 0.0001 ? g2 : _sqrtNewton(x, g2);
  }
  double _asin(double x) =>
      x + x * x * x / 6 + 3 * x * x * x * x * x / 40;

  int _compareDates(String a, String b) {
    try {
      DateTime parse(String d) {
        final p = d.split('/');
        if (p.length != 3) return DateTime(9999);
        return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
      }
      return parse(a).compareTo(parse(b));
    } catch (_) {
      return 0;
    }
  }
}