// lib/core/utils/date_utils.dart
//
// UTILITAIRES DE DATE CENTRALISÉS
// Toute l'app utilise CE fichier pour parser/formater les dates.
// NE JAMAIS parser de date ailleurs que ici.

import 'package:intl/intl.dart';

class DateUtils {
  // ─── Formateurs ─────────────────────────────────────────────
  static final _frenchDate = DateFormat('dd/MM/yyyy');
  static final _frenchDateTime = DateFormat('dd/MM/yyyy HH:mm');
  static final _isoDate = DateFormat('yyyy-MM-dd');
  static final _timeOnly = DateFormat('HH:mm');

  // ─── PARSING ────────────────────────────────────────────────

  /// Parse une date française "19/04/2026" → DateTime
  /// Retourne null si le format est invalide
  static DateTime? parseFrenchDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      return _frenchDate.parseStrict(value.trim());
    } catch (_) {
      return null;
    }
  }

  /// Parse une date+heure "19/04/2026" + "20:00" → DateTime
  static DateTime? parseFrenchDateTime(String? date, String? time) {
    final d = parseFrenchDate(date);
    if (d == null) return null;

    if (time != null && time.trim().isNotEmpty) {
      final parts = time.trim().split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        return DateTime(d.year, d.month, d.day, hour, minute);
      }
    }
    return d;
  }

  // ─── FORMATAGE ────────────────────────────────────────────

  /// DateTime → "19/04/2026"
  static String toFrenchDate(DateTime date) => _frenchDate.format(date);

  /// DateTime → "20:00"
  static String toFrenchTime(DateTime date) => _timeOnly.format(date);

  /// DateTime → "19/04/2026 à 20:00"
  static String toFrenchDateTime(DateTime date) => _frenchDateTime.format(date);

  // ─── COMPARAISONS ─────────────────────────────────────────

  /// Vérifie si une date est à venir (inclut aujourd'hui)
  static bool isUpcoming(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(date.year, date.month, date.day);
    return !eventDay.isBefore(today);
  }

  /// Vérifie si une date est passée
  static bool isPast(DateTime? date) {
    if (date == null) return true;
    return !isUpcoming(date);
  }

  /// Vérifie si c'est aujourd'hui
  static bool isToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  // ─── TRI ──────────────────────────────────────────────────

  /// Compare deux dates pour tri (à venir d'abord, puis par date)
  static int compareByUpcoming(DateTime? a, DateTime? b) {
    final aUpcoming = isUpcoming(a);
    final bUpcoming = isUpcoming(b);

    if (aUpcoming && !bUpcoming) return -1;
    if (!aUpcoming && bUpcoming) return 1;

    if (aUpcoming && bUpcoming) {
      return (a ?? DateTime(2100)).compareTo(b ?? DateTime(2100));
    }
    // Les deux passés : plus récent d'abord
    return (b ?? DateTime(1900)).compareTo(a ?? DateTime(1900));
  }

  // ─── TEXTE HUMAIN ─────────────────────────────────────────

  /// "Aujourd'hui", "Demain", "Dans 3 jours", "Il y a 2 jours"...
  static String humanReadable(DateTime? date) {
    if (date == null) return 'Date inconnue';
    final now = DateTime.now();
    final diff = date.difference(now).inDays;

    if (isToday(date)) return "Aujourd'hui";
    if (diff == 1) return "Demain";
    if (diff == -1) return "Hier";
    if (diff > 1 && diff < 7) return "Dans $diff jours";
    if (diff < -1 && diff > -7) return "Il y a ${-diff} jours";
    if (diff >= 7 && diff < 30) return "Dans ${diff ~/ 7} semaines";
    if (diff <= -7 && diff > -30) return "Il y a ${-diff ~/ 7} semaines";
    return toFrenchDate(date);
  }

  /// Pour les notifications : "Votre concert est dans 2 jours"
  static String timeUntil(DateTime? date) {
    if (date == null) return '';
    final diff = date.difference(DateTime.now());

    if (diff.inDays > 1) return 'dans ${diff.inDays} jours';
    if (diff.inDays == 1) return 'demain';
    if (diff.inDays == 0 && diff.inHours > 1) return 'dans ${diff.inHours} heures';
    if (diff.inDays == 0 && diff.inHours == 1) return 'dans 1 heure';
    if (diff.inDays == 0 && diff.inHours == 0) return "maintenant";
    return '';
  }
}