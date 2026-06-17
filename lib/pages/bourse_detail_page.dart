import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ticket_model.dart';
import '../providers/auth_provider.dart';
import '../services/bourse_service.dart';
import 'chat_page.dart';

class BourseDetailPage extends StatefulWidget {
  final TicketModel ticket;
  const BourseDetailPage({super.key, required this.ticket});

  @override
  State<BourseDetailPage> createState() => _BourseDetailPageState();
}

class _BourseDetailPageState extends State<BourseDetailPage> {
  final BourseService _bourseService = BourseService();
  Map<String, String> _sellerContact = {};
  bool _isLoading = true;

  static const _gold = Color(0xFFD4AF37);
  static const _ivory = Color(0xFFF5F5F0);

  @override
  void initState() {
    super.initState();
    _loadSellerData();
  }

  Future<void> _loadSellerData() async {
    final contact = await _bourseService.getSellerContact(widget.ticket.userId);
    if (mounted) setState(() { _sellerContact = contact; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final bool isMyTicket = widget.ticket.userId == authProvider.user?.uid;
    final ticket = widget.ticket;

    return Scaffold(
      backgroundColor: _ivory,
      appBar: AppBar(
        title: const Text(
          'Détail de l\'offre',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            child: Column(
              children: [

                // ── PHOTO DU BILLET (sans QR code — sécurité) ───────
                if (ticket.images.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      imageUrl: ticket.images.first,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFD4AF37),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: Color(0xFFD4AF37),
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── CARTE INFOS BILLET ──────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Catégorie badge
                        if (ticket.category.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: _gold.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              ticket.category.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _gold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        // Nom événement
                        Text(
                          ticket.eventName.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Infos
                        _buildRow(Icons.calendar_today_outlined,
                            '${ticket.date} à ${ticket.time}'),
                        _buildRow(
                            Icons.place_outlined,
                            ticket.place.isNotEmpty
                                ? '${ticket.place}, ${ticket.city}'
                                : ticket.city),
                        _buildRow(Icons.event_seat_outlined,
                            'Place : ${ticket.seat}'),

                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 16),

                        // Prix de vente
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Prix de vente',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: _gold,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${ticket.salePrice.isNotEmpty ? ticket.salePrice : ticket.price} €',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Prix d'achat si différent
                        if (ticket.salePrice.isNotEmpty &&
                            ticket.salePrice != ticket.price &&
                            ticket.price.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Prix d\'achat : ${ticket.price} €',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black38,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Note sécurité
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.blue.withOpacity(0.15)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.security_outlined,
                                  color: Colors.blueGrey, size: 18),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Le QR code et les photos du billet ne sont visibles qu\'après finalisation de la transaction.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blueGrey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── MENTION LÉGALE ──────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.amber.withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.gavel, color: Colors.amber, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Le prix est fixé par le vendeur. La plateforme n\'est pas responsable de la transaction.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── CARTE VENDEUR ───────────────────────────────────
                _buildSellerCard(),
                const SizedBox(height: 24),

                // ── BOUTON ACTION ───────────────────────────────────
                if (isMyTicket)
                  _buildActionButton(
                    'RETIRER DE LA VENTE',
                    Colors.redAccent,
                    Icons.remove_circle_outline,
                        () => _handleWithdraw(),
                  )
                else
                  _buildActionButton(
                    'CONTACTER LE VENDEUR',
                    _gold,
                    Icons.message_outlined,
                        () => _startChat(authProvider.user!.uid),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _gold),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: SizedBox(
          width: 40,
          height: 40,
          child: CircleAvatar(
            backgroundColor: _gold.withOpacity(0.1),
            child: const Icon(Icons.person, color: _gold),
          ),
        ),
        title: Text(
          _isLoading ? 'Chargement...' : (_sellerContact['name'] ?? 'Vendeur'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Vendeur vérifié', style: TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.verified, color: Colors.blue, size: 20),
      ),
    );
  }

  Widget _buildActionButton(
      String label, Color color, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 0,
        ),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  void _startChat(String currentUserId) async {
    final convId = await _bourseService.createConversation(
        currentUserId, widget.ticket.userId, widget.ticket.id);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationId: convId,
          otherUserId: widget.ticket.userId,
          ticketTitle: widget.ticket.eventName,
        ),
      ),
    );
  }

  void _handleWithdraw() async {
    await _bourseService.withdrawFromSale(widget.ticket.id);
    if (mounted) Navigator.pop(context);
  }
}