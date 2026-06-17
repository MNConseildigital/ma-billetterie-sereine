import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'transaction_history_page.dart';
import '../core/theme/app_theme.dart';
import '../models/event_model.dart';
import '../models/ticket_model.dart';
import '../providers/auth_provider.dart';
import '../services/event_service.dart';
import '../services/tickets_service.dart';
import '../widgets/menu_button.dart';
import 'bourse_page.dart';
import 'conversations_list_page.dart'; // ← NOUVEAU
import 'favorites_page.dart';
import 'profile_page.dart';
import 'search_events_page.dart';
import 'tickets_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _currentCity = 'Localisation...';

  @override
  void initState() {
    super.initState();
    _loadCurrentCity();
  }

  Future<void> _loadCurrentCity() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _currentCity = 'Ville inconnue';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _currentCity = 'Ville inconnue';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final city = placemarks.first.locality ?? 'Ville inconnue';
        setState(() {
          _currentCity = city;
        });
      } else {
        setState(() {
          _currentCity = 'Ville inconnue';
        });
      }
    } catch (_) {
      setState(() {
        _currentCity = 'Ville inconnue';
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 18) {
      return 'Bonjour';
    } else {
      return 'Bonsoir';
    }
  }

  String _getDisplayName(String? email) {
    if (email == null || email.isEmpty) {
      return 'à vous';
    }

    final parts = email.split('@');
    if (parts.isNotEmpty && parts.first.isNotEmpty) {
      return parts.first;
    }

    return 'à vous';
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  DateTime? _parseTicketDateTime(TicketModel ticket) {
    try {
      final dateParts = ticket.date.split('/');
      final timeParts = ticket.time.split(':');

      if (dateParts.length != 3) return null;

      final day = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);

      int hour = 0;
      int minute = 0;

      if (timeParts.length == 2) {
        hour = int.tryParse(timeParts[0]) ?? 0;
        minute = int.tryParse(timeParts[1]) ?? 0;
      }

      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  TicketModel? _getNextUpcomingTicket(List<TicketModel> tickets) {
    final now = DateTime.now();

    final upcoming = tickets.where((ticket) {
      final date = _parseTicketDateTime(ticket);
      return date != null && !date.isBefore(now);
    }).toList();

    if (upcoming.isEmpty) return null;

    upcoming.sort((a, b) {
      final aDate = _parseTicketDateTime(a)!;
      final bDate = _parseTicketDateTime(b)!;
      return aDate.compareTo(bDate);
    });

    return upcoming.first;
  }

  @override
  Widget build(BuildContext context) {
    final eventService = EventService();
    final ticketsService = TicketsService();
    final authProvider = Provider.of<AuthProvider>(context);
    final userEmail = authProvider.user?.email;
    final userId = authProvider.user?.uid;
    final greeting = _getGreeting();
    final displayName = _getDisplayName(userEmail);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),

            Row(
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppTheme.premiumBlack,
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: AppTheme.goldSoft,
                            size: 28,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Ma Billetterie Sereine',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.premiumBlack,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting, $displayName',
                    style: const TextStyle(
                      fontSize: 20,
                      color: AppTheme.goldSoft,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Le compagnon serein de vos événements',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Simplifiez vos sorties, retrouvez vos billets et découvrez les événements autour de vous.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 18,
                          color: AppTheme.goldSoft,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currentCity,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            if (userId != null)
              StreamBuilder<List<TicketModel>>(
                stream: ticketsService.getUserTickets(userId),
                builder: (context, snapshot) {
                  final tickets = snapshot.data ?? [];
                  final nextTicket = _getNextUpcomingTicket(tickets);

                  if (nextTicket == null) {
                    return const SizedBox.shrink();
                  }

                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.event_available,
                          color: AppTheme.primaryGold,
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Prêt pour votre prochaine sortie ?',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                nextTicket.eventName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${nextTicket.date} • ${nextTicket.time}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                nextTicket.place,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 22),

            const Text(
              'À la une',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 14),

            StreamBuilder<List<EventModel>>(
              stream: eventService.getFeaturedEvents(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 220,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Container(
                    height: 180,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.cardWhite,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        'Impossible de charger les événements.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  );
                }

                final events = snapshot.data ?? [];

                if (events.isEmpty) {
                  return Container(
                    height: 180,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.cardWhite,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Center(
                      child: Text(
                        'Aucun événement à la une pour le moment.',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  );
                }

                return CarouselSlider.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index, realIndex) {
                    final event = events[index];
                    return _FeaturedEventCard(event: event);
                  },
                  options: CarouselOptions(
                    height: 220,
                    autoPlay: true,
                    autoPlayInterval: const Duration(seconds: 4),
                    autoPlayAnimationDuration: const Duration(milliseconds: 900),
                    enlargeCenterPage: true,
                    viewportFraction: 0.82,
                    enableInfiniteScroll: true,
                  ),
                );
              },
            ),

            const SizedBox(height: 26),

            const Text(
              'Accès rapides',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            MenuButton(
              icon: Icons.search,
              title: 'Trouver des événements',
              subtitle: 'Ville, département, région, autour de moi',
              color: AppTheme.cardWhite,
              iconColor: AppTheme.primaryGold,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SearchEventsPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            MenuButton(
              icon: Icons.confirmation_num_outlined,
              title: 'Mes billets',
              subtitle: 'Retrouvez vos billets enregistrés',
              color: AppTheme.cardWhite,
              iconColor: AppTheme.primaryGold,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TicketsPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            MenuButton(
              icon: Icons.sell_outlined,
              title: 'Bourse aux billets',
              subtitle: 'Retrouvez les billets mis en vente',
              color: AppTheme.cardWhite,
              iconColor: AppTheme.favoritePink,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BoursePage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            // ── NOUVEAU : Messages ──────────────────────────────
            MenuButton(
              icon: Icons.chat_bubble_outline,
              title: 'Messages',
              subtitle: 'Vos conversations avec vendeurs/acheteurs',
              color: AppTheme.cardWhite,
              iconColor: AppTheme.primaryGold,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ConversationsListPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            MenuButton(
              icon: Icons.history,
              title: 'Historique',
              subtitle: 'Vos ventes, achats et demandes',
              color: AppTheme.cardWhite,
              iconColor: AppTheme.primaryGold,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TransactionHistoryPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            MenuButton(
              icon: Icons.favorite,
              title: 'Mes favoris',
              subtitle: 'Retrouvez vos événements favoris',
              color: AppTheme.cardWhite,
              iconColor: AppTheme.favoritePink,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FavoritesPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            MenuButton(
              icon: Icons.person_outline,
              title: 'Mon compte',
              subtitle: 'Connexion, profil et paramètres',
              color: AppTheme.cardWhite,
              iconColor: AppTheme.primaryGold,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfilePage(),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _FeaturedEventCard extends StatelessWidget {
  final EventModel event;

  const _FeaturedEventCard({
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EventDetailPage(event: event),
          ),
        );
      },
      child: Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: event.imageUrl.isNotEmpty
                ? CachedNetworkImage(
              imageUrl: event.imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: AppTheme.premiumBlack,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.goldSoft,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: AppTheme.premiumBlack,
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    color: Colors.white54,
                    size: 40,
                  ),
                ),
              ),
            )
                : Container(
              color: AppTheme.premiumBlack,
              child: const Center(
                child: Icon(
                  Icons.image,
                  color: Colors.white54,
                  size: 40,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.08),
                    Colors.black.withOpacity(0.68),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  event.city,
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppTheme.goldSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ), // GestureDetector
    );
  }
}