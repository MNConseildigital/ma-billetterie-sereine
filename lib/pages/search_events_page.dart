// lib/pages/search_events_page.dart
//
// Page Agenda géolocalisé — Ma Billetterie Sereine
// Fonctionnalités :
//   • Recherche textuelle (ville, département, région, titre)
//   • Filtres par catégorie (chips horizontaux)
//   • Géolocalisation "Autour de moi" (rayon 30 km)
//   • Liste des événements avec cards
//   • Page de détail d'un événement

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_theme.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constantes
// ─────────────────────────────────────────────────────────────────────────────

const _categories = [
  'Tous', 'Concert', 'Opéra', 'Théâtre', 'Danse', 'Festival',
  'Exposition', 'Cinéma', 'Sport', 'Spectacle', 'Humour',
  'Événement culturel', 'Autre',
];

// ─────────────────────────────────────────────────────────────────────────────
// Page principale
// ─────────────────────────────────────────────────────────────────────────────

class SearchEventsPage extends StatefulWidget {
  const SearchEventsPage({super.key});

  @override
  State<SearchEventsPage> createState() => _SearchEventsPageState();
}

class _SearchEventsPageState extends State<SearchEventsPage> {
  final EventService _eventService = EventService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'Tous';
  bool _nearMeMode = false;
  bool _loadingLocation = false;
  double? _userLat;
  double? _userLng;
  String _userCity = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Géolocalisation ────────────────────────────────────────────────────────

  Future<void> _toggleNearMe() async {
    if (_nearMeMode) {
      setState(() {
        _nearMeMode    = false;
        _userLat       = null;
        _userLng       = null;
        _userCity      = '';
      });
      return;
    }

    setState(() => _loadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Activez la localisation dans les paramètres.');
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _showSnack('Permission de localisation refusée.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _nearMeMode = true;
        _userLat    = pos.latitude;
        _userLng    = pos.longitude;
        _searchController.clear();
      });
    } catch (e) {
      _showSnack('Impossible de récupérer votre position.');
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  // ── Stream selon le mode actif ─────────────────────────────────────────────

  Stream<List<EventModel>> get _stream {
    if (_nearMeMode && _userLat != null && _userLng != null) {
      return _eventService.getEventsNearMe(
        latitude:  _userLat!,
        longitude: _userLng!,
        radiusKm:  30,
        category:  _selectedCategory == 'Tous' ? null : _selectedCategory,
      );
    }
    return _eventService.searchEvents(
      query:    _searchController.text,
      category: _selectedCategory == 'Tous' ? null : _selectedCategory,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: AppTheme.premiumBlack,
        foregroundColor: AppTheme.goldSoft,
        title: const Text(
          'Trouver des événements',
          style: TextStyle(
            color: AppTheme.goldSoft,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryChips(),
          Expanded(child: _buildEventList()),
        ],
      ),
    );
  }

  // ── Barre de recherche ─────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      color: AppTheme.premiumBlack,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          // Champ de recherche
          TextField(
            controller: _searchController,
            enabled: !_nearMeMode,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: _nearMeMode
                  ? 'Mode "Autour de moi" actif'
                  : 'Ville, département, région…',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 15),
              prefixIcon: const Icon(Icons.search, color: AppTheme.goldSoft),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.white38),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
              )
                  : null,
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 10),

          // Bouton "Autour de moi"
          SizedBox(
            width: double.infinity,
            child: _loadingLocation
                ? const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(
                  color: AppTheme.goldSoft, strokeWidth: 2,
                ),
              ),
            )
                : OutlinedButton.icon(
              onPressed: _toggleNearMe,
              style: OutlinedButton.styleFrom(
                foregroundColor: _nearMeMode
                    ? Colors.greenAccent
                    : AppTheme.goldSoft,
                side: BorderSide(
                  color: _nearMeMode
                      ? Colors.greenAccent
                      : AppTheme.goldSoft,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: Icon(
                _nearMeMode
                    ? Icons.location_on
                    : Icons.my_location_outlined,
                size: 18,
              ),
              label: Text(
                _nearMeMode
                    ? 'Autour de moi — actif (30 km)  ✕'
                    : 'Autour de moi',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Chips catégories ───────────────────────────────────────────────────────

  Widget _buildCategoryChips() {
    return Container(
      height: 48,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat      = _categories[i];
          final selected = cat == _selectedCategory;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? AppTheme.primaryGold : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppTheme.primaryGold : Colors.grey.shade300,
                ),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Liste des événements ───────────────────────────────────────────────────

  Widget _buildEventList() {
    return StreamBuilder<List<EventModel>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryGold),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Erreur : ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          );
        }

        final events = snapshot.data ?? [];

        if (events.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.event_busy_outlined,
                  size: 56,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  _nearMeMode
                      ? 'Aucun événement dans un rayon de 30 km.'
                      : 'Aucun événement trouvé.',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (!_nearMeMode) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Essayez une autre ville ou région.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _EventCard(
            event: events[i],
            userLat: _userLat,
            userLng: _userLng,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card événement
// ─────────────────────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final EventModel event;
  final double? userLat;
  final double? userLng;

  const _EventCard({
    required this.event,
    this.userLat,
    this.userLng,
  });

  String? _distanceLabel() {
    if (userLat == null || userLng == null) return null;
    if (event.latitude == 0 && event.longitude == 0) return null;
    final d = _haversineKm(userLat!, userLng!, event.latitude, event.longitude);
    return d < 1 ? '< 1 km' : '${d.toStringAsFixed(0)} km';
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * 3.141592653589793 / 180;
    final dLon = (lon2 - lon1) * 3.141592653589793 / 180;
    final a = _sin2(dLat / 2) +
        _cos(lat1 * 3.141592653589793 / 180) *
            _cos(lat2 * 3.141592653589793 / 180) *
            _sin2(dLon / 2);
    return r * 2 * _asin(_sqrt(a));
  }

  double _sin2(double x) { final s = x - x*x*x/6; return s * s; }
  double _cos(double x)  => 1 - x*x/2 + x*x*x*x/24;
  double _sqrt(double x) {
    if (x <= 0) return 0;
    double g = x < 1 ? x : x / 2;
    for (int i = 0; i < 20; i++) g = (g + x / g) / 2;
    return g;
  }
  double _asin(double x) => x + x*x*x/6 + 3*x*x*x*x*x/40;

  @override
  Widget build(BuildContext context) {
    final dist = _distanceLabel();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventDetailPage(event: event)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(20),
              ),
              child: SizedBox(
                width: 100,
                height: 110,
                child: event.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl: event.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: AppTheme.premiumBlack,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.goldSoft,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => _placeholder(),
                )
                    : _placeholder(),
              ),
            ),

            // Infos
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Catégorie + distance
                    Row(
                      children: [
                        _CategoryBadge(category: event.category),
                        const Spacer(),
                        if (dist != null)
                          Text(
                            dist,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Titre
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Ville
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.city.isNotEmpty
                                ? event.city
                                : event.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Date
                    if (event.date.isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 13,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            event.date,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: AppTheme.premiumBlack,
    child: const Center(
      child: Icon(Icons.event, color: Colors.white24, size: 32),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge catégorie
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  final String category;
  const _CategoryBadge({required this.category});

  Color get _color {
    switch (category) {
      case 'Concert':    return Colors.purple.shade100;
      case 'Opéra':      return Colors.indigo.shade100;
      case 'Théâtre':    return Colors.orange.shade100;
      case 'Danse':      return Colors.pink.shade100;
      case 'Festival':   return Colors.green.shade100;
      case 'Exposition': return Colors.teal.shade100;
      case 'Cinéma':     return Colors.blue.shade100;
      case 'Sport':      return Colors.red.shade100;
      default:           return Colors.grey.shade200;
    }
  }

  Color get _textColor {
    switch (category) {
      case 'Concert':    return Colors.purple.shade800;
      case 'Opéra':      return Colors.indigo.shade800;
      case 'Théâtre':    return Colors.orange.shade800;
      case 'Danse':      return Colors.pink.shade800;
      case 'Festival':   return Colors.green.shade800;
      case 'Exposition': return Colors.teal.shade800;
      case 'Cinéma':     return Colors.blue.shade800;
      case 'Sport':      return Colors.red.shade800;
      default:           return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        category,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: _textColor,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page de détail d'un événement
// ─────────────────────────────────────────────────────────────────────────────

class EventDetailPage extends StatelessWidget {
  final EventModel event;
  const EventDetailPage({super.key, required this.event});

  Future<void> _openUrl(String url, BuildContext context) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le lien.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      body: CustomScrollView(
        slivers: [
          // Image en-tête
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppTheme.premiumBlack,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: event.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                imageUrl: event.imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: AppTheme.premiumBlack,
                  child: const Center(
                    child: Icon(Icons.event, color: Colors.white24, size: 56),
                  ),
                ),
              )
                  : Container(
                color: AppTheme.premiumBlack,
                child: const Center(
                  child: Icon(Icons.event, color: Colors.white24, size: 56),
                ),
              ),
            ),
          ),

          // Contenu
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Catégorie
                  _CategoryBadge(category: event.category),
                  const SizedBox(height: 12),

                  // Titre
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Infos clés
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    text: event.date.isNotEmpty ? event.date : 'Date non précisée',
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.place_outlined,
                    text: event.location.isNotEmpty
                        ? event.location
                        : event.city,
                  ),
                  if (event.department.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _InfoRow(
                      icon: Icons.map_outlined,
                      text: '${event.department} — ${event.region}',
                    ),
                  ],

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Source
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Source : ${event.source == "openagenda" ? "OpenAgenda" : event.source == "datatourisme" ? "DATAtourisme" : "Partenaire"}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Bouton billetterie
                  if (event.source == 'manual' || event.partnerName.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGold,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.confirmation_num_outlined),
                        label: const Text(
                          'Voir les billets',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryGold),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              color: AppTheme.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}