import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/ticket_model.dart';
import '../services/bourse_service.dart';
import 'bourse_detail_page.dart';

class BoursePage extends StatefulWidget {
  const BoursePage({super.key});

  @override
  State<BoursePage> createState() => _BoursePageState();
}

class _BoursePageState extends State<BoursePage> {
  final BourseService _bourseService = BourseService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  String _selectedCategory = 'Toutes';
  late Stream<List<TicketModel>> _ticketsStream;

  final List<String> _categories = [
    'Toutes', 'Concert', 'Festival', 'Théâtre', 'Danse', 'Sport', 'Autre'
  ];

  @override
  void initState() {
    super.initState();
    _ticketsStream = _bourseService.getFilteredTickets(
      category: _selectedCategory,
    );
  }

  void _updateStream() {
    setState(() {
      _ticketsStream = _bourseService.getFilteredTickets(
        category: _selectedCategory,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        title: const Text(
          'Bourse aux Billets',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // ── FILTRES CATÉGORIES ────────────────────────────────────
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: const Color(0xFFD4AF37),
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    onSelected: (_) {
                      _selectedCategory = cat;
                      _updateStream();
                    },
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                );
              },
            ),
          ),

          // ── LISTE DES BILLETS ─────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<TicketModel>>(
              stream: _ticketsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFD4AF37)),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.confirmation_number_outlined,
                            size: 60, color: Colors.grey[400]),
                        const SizedBox(height: 10),
                        Text(
                          'Aucun billet disponible'
                              '${_selectedCategory != 'Toutes' ? ' en $_selectedCategory' : ''}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final ticket = snapshot.data![index];
                    // Prix affiché : prixVente en priorité, sinon prix d'achat
                    final displayPrice = ticket.salePrice.isNotEmpty
                        ? ticket.salePrice
                        : ticket.price;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 15),
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                BourseDetailPage(ticket: ticket),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // ── ICÔNE CATÉGORIE (pas de photo) ──
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD4AF37)
                                      .withOpacity(0.10),
                                  borderRadius:
                                  BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  _categoryIcon(ticket.category),
                                  color: const Color(0xFFD4AF37),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),

                              // ── INFOS ────────────────────────────
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ticket.eventName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${ticket.date} • ${ticket.city}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    // Prix de vente + badge réservé
                                    Row(
                                      children: [
                                        Text(
                                          '$displayPrice €',
                                          style: const TextStyle(
                                            color: Color(0xFFD4AF37),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        if (ticket.saleStatus == 'reserve') ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'Réservé',
                                              style: TextStyle(
                                                color: Colors.orange,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const Icon(Icons.arrow_forward_ios,
                                  size: 14,
                                  color: Color(0xFFD4AF37)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'concert':
        return Icons.music_note_outlined;
      case 'festival':
        return Icons.festival_outlined;
      case 'théâtre':
      case 'theatre':
        return Icons.theater_comedy_outlined;
      case 'danse':
        return Icons.accessibility_new_outlined;
      case 'sport':
        return Icons.sports_outlined;
      default:
        return Icons.confirmation_number_outlined;
    }
  }
}