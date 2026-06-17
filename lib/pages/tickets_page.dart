import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/ticket_model.dart';
import '../providers/auth_provider.dart';
import '../services/tickets_service.dart';
import 'add_ticket_page.dart';
import 'ticket_detail_page.dart';

class TicketsPage extends StatelessWidget {
  const TicketsPage({super.key});

  Map<String, List<TicketModel>> _groupTickets(List<TicketModel> tickets) {
    final Map<String, List<TicketModel>> grouped = {};
    for (final ticket in tickets) {
      final key = '${ticket.date}___${ticket.eventName}';
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(ticket);
    }
    return grouped;
  }

  int _countTotalPlaces(List<TicketModel> tickets) =>
      tickets.fold(0, (sum, ticket) => sum + ticket.nbPlaces);

  int _countTicketsForSale(List<TicketModel> tickets) =>
      tickets.where((ticket) => ticket.forSale).length;

  DateTime? _parseTicketDateTime(TicketModel ticket) {
    try {
      final dateParts = ticket.date.split('/');
      final timeParts = ticket.time.split(':');
      if (dateParts.length != 3) return null;
      return DateTime(
        int.parse(dateParts[2]),
        int.parse(dateParts[1]),
        int.parse(dateParts[0]),
        timeParts.length == 2 ? (int.tryParse(timeParts[0]) ?? 0) : 0,
        timeParts.length == 2 ? (int.tryParse(timeParts[1]) ?? 0) : 0,
      );
    } catch (_) {
      return null;
    }
  }

  bool _isUpcoming(TicketModel ticket) {
    final ticketDate = _parseTicketDateTime(ticket);
    if (ticketDate == null) return false;
    return !ticketDate.isBefore(DateTime.now());
  }

  List<TicketModel> _sortUpcoming(List<TicketModel> tickets) {
    final sorted = [...tickets];
    sorted.sort((a, b) {
      final aDate = _parseTicketDateTime(a) ?? DateTime(2100);
      final bDate = _parseTicketDateTime(b) ?? DateTime(2100);
      return aDate.compareTo(bDate);
    });
    return sorted;
  }

  List<TicketModel> _sortPast(List<TicketModel> tickets) {
    final sorted = [...tickets];
    sorted.sort((a, b) {
      final aDate = _parseTicketDateTime(a) ?? DateTime(1900);
      final bDate = _parseTicketDateTime(b) ?? DateTime(1900);
      return bDate.compareTo(aDate);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final ticketsService = TicketsService();

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mes billets')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Connectez-vous pour accéder à votre coffre-fort billets.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: AppTheme.textSecondary),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mes billets')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddTicketPage()),
        ),
        backgroundColor: AppTheme.premiumBlack,
        foregroundColor: AppTheme.primaryGold,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: StreamBuilder<List<TicketModel>>(
        stream: ticketsService.getUserTickets(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erreur lors du chargement des billets.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                ),
              ),
            );
          }

          final tickets = snapshot.data ?? [];

          if (tickets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.cardWhite,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 70, color: AppTheme.primaryGold),
                      const SizedBox(height: 18),
                      const Text(
                        'Votre coffre-fort est vide.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Ajoutez ou scannez vos billets pour les retrouver ici en toute sérénité.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: AppTheme.textSecondary, height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AddTicketPage()),
                          ),
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Ajouter un billet'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final upcomingTickets = _sortUpcoming(tickets.where(_isUpcoming).toList());
          final pastTickets = _sortPast(tickets.where((t) => !_isUpcoming(t)).toList());
          final groupedUpcoming = _groupTickets(upcomingTickets);
          final groupedPast = _groupTickets(pastTickets);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── HEADER COFFRE-FORT ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppTheme.premiumBlack,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGold.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.lock_outline, color: AppTheme.primaryGold, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Votre coffre-fort billets',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${tickets.length} billet(s) enregistré(s)',
                            style: const TextStyle(fontSize: 15, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── BILLETS À VENIR ─────────────────────────────────────
              if (groupedUpcoming.isNotEmpty) ...[
                _SectionBadge(
                  title: 'Billets à venir',
                  subtitle: 'Vos prochaines sorties',
                  icon: Icons.upcoming_outlined,
                  highlight: true,
                  count: upcomingTickets.length,
                ),
                const SizedBox(height: 14),
                ...groupedUpcoming.entries.map((entry) {
                  final parts = entry.key.split('___');
                  final date = parts[0];
                  final eventName = parts.length > 1 ? parts[1] : '';
                  final groupTickets = entry.value;
                  final firstTicket = groupTickets.first;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TicketGroupHeader(
                        eventName: eventName,
                        date: date,
                        time: firstTicket.time,
                        place: firstTicket.place,
                        city: firstTicket.city,
                        groupTickets: groupTickets,
                        totalPlaces: _countTotalPlaces(groupTickets),
                        ticketsForSale: _countTicketsForSale(groupTickets),
                      ),
                      const SizedBox(height: 12),
                      ...groupTickets.map(
                            (ticket) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TicketCard(ticket: ticket),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  );
                }),
                const SizedBox(height: 10),
              ],

              // ── BILLETS PASSÉS ──────────────────────────────────────
              if (groupedPast.isNotEmpty) ...[
                _SectionBadge(
                  title: 'Billets passés',
                  subtitle: 'Votre historique récent',
                  icon: Icons.history,
                  highlight: false,
                  count: pastTickets.length,
                ),
                const SizedBox(height: 14),
                ...groupedPast.entries.map((entry) {
                  final parts = entry.key.split('___');
                  final date = parts[0];
                  final eventName = parts.length > 1 ? parts[1] : '';
                  final groupTickets = entry.value;
                  final firstTicket = groupTickets.first;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TicketGroupHeader(
                        eventName: eventName,
                        date: date,
                        time: firstTicket.time,
                        place: firstTicket.place,
                        city: firstTicket.city,
                        groupTickets: groupTickets,
                        totalPlaces: _countTotalPlaces(groupTickets),
                        ticketsForSale: _countTicketsForSale(groupTickets),
                      ),
                      const SizedBox(height: 12),
                      ...groupTickets.map(
                            (ticket) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TicketCard(ticket: ticket, isPast: true),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  );
                }),
              ],

              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION BADGE
// ─────────────────────────────────────────────────────────────────────────────
class _SectionBadge extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool highlight;
  final int count;

  const _SectionBadge({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.highlight,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.primaryGold.withOpacity(0.14)
            : AppTheme.ivoryBackground,
        borderRadius: BorderRadius.circular(20),
        border: highlight
            ? Border.all(color: AppTheme.primaryGold.withOpacity(0.3), width: 1)
            : null,
      ),
      child: Row(
        children: [
          Icon(icon, size: 26, color: highlight ? AppTheme.primaryGold : AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title ($count)',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GROUP HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _TicketGroupHeader extends StatelessWidget {
  final String eventName;
  final String date;
  final String time;
  final String place;
  final String city;
  final List<TicketModel> groupTickets;
  final int totalPlaces;
  final int ticketsForSale;

  const _TicketGroupHeader({
    required this.eventName,
    required this.date,
    required this.time,
    required this.place,
    required this.city,
    required this.groupTickets,
    required this.totalPlaces,
    required this.ticketsForSale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.ivoryBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryGold.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.event_outlined, color: AppTheme.primaryGold, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eventName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$date • $time — $place, $city',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 3),
                Text(
                  '${groupTickets.length} billet(s) • $totalPlaces place(s)',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                if (ticketsForSale > 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Text(
                      'Des billets de ce lot sont en vente',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.favoritePink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TICKET CARD  ✦ VERSION AMÉLIORÉE avec image
// ─────────────────────────────────────────────────────────────────────────────
class _TicketCard extends StatelessWidget {
  final TicketModel ticket;
  final bool isPast;

  const _TicketCard({required this.ticket, this.isPast = false});

  @override
  Widget build(BuildContext context) {
    final hasImage = ticket.images.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TicketDetailPage(ticket: ticket)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isPast ? 0.03 : 0.07),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
          // Bordure subtile dorée pour les billets à venir
          border: isPast
              ? null
              : Border.all(color: AppTheme.primaryGold.withOpacity(0.18), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── IMAGE EN HAUT (si disponible) ──────────────────────
            if (hasImage)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(
                  children: [
                    Image.network(
                      ticket.images.first,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      color: isPast ? Colors.black.withOpacity(0.35) : null,
                      colorBlendMode: isPast ? BlendMode.darken : null,
                      errorBuilder: (_, __, ___) => _ImagePlaceholder(isPast: isPast),
                    ),
                    // Gradient bas de l'image pour lisibilité
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.55),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Catégorie en badge sur l'image
                    if (ticket.category.isNotEmpty)
                      Positioned(
                        top: 10,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.premiumBlack.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            ticket.category,
                            style: const TextStyle(
                              color: AppTheme.primaryGold,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    // Nom de l'événement en bas de l'image
                    Positioned(
                      bottom: 10,
                      left: 12,
                      right: 48,
                      child: Text(
                        ticket.eventName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                        ),
                      ),
                    ),
                    // Flèche
                    Positioned(
                      bottom: 8,
                      right: 12,
                      child: Icon(
                        Icons.arrow_forward_ios,
                        size: 15,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              )
            else
            // Pas d'image : placeholder avec icône
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: _ImagePlaceholder(isPast: isPast, eventName: ticket.eventName),
              ),

            // ── INFOS EN DESSOUS DE L'IMAGE ────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom seulement si pas d'image (déjà affiché dessus sinon)
                  if (!hasImage) ...[
                    Text(
                      ticket.eventName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Date + heure
                  Row(
                    children: [
                      const Icon(Icons.access_time_outlined, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 5),
                      Text(
                        '${ticket.date} à ${ticket.time}',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Lieu + ville
                  Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${ticket.place}, ${ticket.city}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Emplacement (siège)
                  Row(
                    children: [
                      const Icon(Icons.event_seat_outlined, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 5),
                      Text(
                        ticket.seat,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Badges statut
                  Row(
                    children: [
                      _StatusChip(
                        label: ticket.forSale ? 'En vente' : 'Conservé',
                        color: ticket.forSale ? AppTheme.favoritePink : AppTheme.textSecondary,
                        filled: ticket.forSale,
                      ),
                      if (ticket.reminderActive) ...[
                        const SizedBox(width: 8),
                        _StatusChip(
                          label: '🔔 Rappel',
                          color: AppTheme.successGreen,
                          filled: true,
                        ),
                      ],
                      const Spacer(),
                      // Prix — on nettoie EUR/€ pour éviter les doublons
                      if (ticket.price.isNotEmpty)
                        Flexible(
                          child: Text(
                            '${_cleanPrice(ticket.price)} €',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────
class _ImagePlaceholder extends StatelessWidget {
  final bool isPast;
  final String? eventName;
  const _ImagePlaceholder({this.isPast = false, this.eventName});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      width: double.infinity,
      color: isPast
          ? AppTheme.textSecondary.withOpacity(0.08)
          : AppTheme.primaryGold.withOpacity(0.08),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.confirmation_num_outlined,
            size: 40,
            color: isPast
                ? AppTheme.textSecondary.withOpacity(0.3)
                : AppTheme.primaryGold.withOpacity(0.4),
          ),
          if (eventName != null)
            Positioned(
              bottom: 10,
              left: 14,
              right: 48,
              child: Text(
                eventName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isPast ? AppTheme.textSecondary : AppTheme.textPrimary,
                ),
              ),
            ),
          const Positioned(
            bottom: 8,
            right: 12,
            child: Icon(Icons.arrow_forward_ios, size: 15, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

// Nettoie le prix stocké (supprime EUR, €, espaces superflus)
String _cleanPrice(String raw) {
  return raw
      .replaceAll('EUR', '')
      .replaceAll('€', '')
      .trim();
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  const _StatusChip({required this.label, required this.color, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? color.withOpacity(0.12) : AppTheme.ivoryBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: filled ? color : AppTheme.textSecondary,
        ),
      ),
    );
  }
}