import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/theme/app_theme.dart';
import '../models/ticket_model.dart';
import '../services/tickets_service.dart';
import '../services/bourse_service.dart';
import 'edit_ticket_page.dart';

class TicketDetailPage extends StatefulWidget {
  final TicketModel ticket;
  const TicketDetailPage({super.key, required this.ticket});

  @override
  State<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends State<TicketDetailPage> {
  final TicketsService _ticketsService = TicketsService();
  final BourseService _bourseService = BourseService();
  bool _isProcessing = false;
  bool _qrExpanded = false;

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final hasImage = ticket.images.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.ivoryBackground,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── APP BAR avec image hero ───────────────────────────
              SliverAppBar(
                expandedHeight: hasImage ? 280 : 120,
                pinned: true,
                backgroundColor: AppTheme.premiumBlack,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  background: hasImage
                      ? Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        onTap: () => _showImageZoom(context, ticket.images, 0),
                        child: Image.network(
                          ticket.images.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildImageFallback(),
                        ),
                      ),
                      // Gradient sombre en bas
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.center,
                            colors: [Color(0xDD111111), Colors.transparent],
                          ),
                        ),
                      ),
                      // Nom de l'événement en bas du hero
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (ticket.category.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGold,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  ticket.category.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppTheme.premiumBlack,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            Text(
                              ticket.eventName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                                shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${ticket.city} • ${ticket.place}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Miniatures supplémentaires (si plusieurs images)
                      if (ticket.images.length > 1)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '+${ticket.images.length - 1} photo(s)',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                    ],
                  )
                      : _buildImageFallback(),
                ),
              ),

              // ── CONTENU ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre si pas d'image (déjà dans le hero sinon)
                      if (!hasImage) ...[
                        Text(
                          ticket.eventName,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ── CARTE INFOS PRINCIPALES ─────────────────
                      _InfoCard(
                        children: [
                          _InfoRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'Date',
                            value: ticket.date,
                          ),
                          const _Divider(),
                          _InfoRow(
                            icon: Icons.access_time_outlined,
                            label: 'Heure',
                            value: ticket.time,
                          ),
                          const _Divider(),
                          _InfoRow(
                            icon: Icons.place_outlined,
                            label: 'Lieu',
                            value: ticket.place,
                          ),
                          const _Divider(),
                          _InfoRow(
                            icon: Icons.location_city_outlined,
                            label: 'Ville',
                            value: ticket.city,
                          ),
                          const _Divider(),
                          _InfoRow(
                            icon: Icons.event_seat_outlined,
                            label: 'Emplacement',
                            value: ticket.seat,
                          ),
                          const _Divider(),
                          _InfoRow(
                            icon: Icons.sell_outlined,
                            label: 'Prix',
                            value: '${ticket.price.replaceAll("EUR", "").replaceAll("€", "").trim()} €',
                            highlight: true,
                          ),
                          if (ticket.category.isNotEmpty) ...[
                            const _Divider(),
                            _InfoRow(
                              icon: Icons.category_outlined,
                              label: 'Catégorie',
                              value: ticket.category,
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── STATUT ──────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _StatusTile(
                              icon: ticket.forSale
                                  ? Icons.storefront_outlined
                                  : Icons.lock_outline,
                              label: ticket.forSale ? 'En vente' : 'Conservé',
                              color: ticket.forSale
                                  ? AppTheme.favoritePink
                                  : AppTheme.successGreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatusTile(
                              icon: ticket.reminderActive
                                  ? Icons.notifications_active_outlined
                                  : Icons.notifications_off_outlined,
                              label: ticket.reminderActive ? 'Rappel actif' : 'Sans rappel',
                              color: ticket.reminderActive
                                  ? AppTheme.successGreen
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ── QR CODE ─────────────────────────────────
                      GestureDetector(
                        onTap: () => setState(() => _qrExpanded = !_qrExpanded),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.cardWhite,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppTheme.primaryGold.withOpacity(0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryGold.withOpacity(0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.qr_code_2, color: AppTheme.primaryGold, size: 22),
                                      SizedBox(width: 8),
                                      Text(
                                        'QR Code du billet',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Icon(
                                    _qrExpanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    color: AppTheme.textSecondary,
                                  ),
                                ],
                              ),
                              if (_qrExpanded) ...[
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: QrImageView(
                                    data: ticket.qr.isNotEmpty ? ticket.qr : 'N/A',
                                    version: QrVersions.auto,
                                    size: 220.0,
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Présentez ce QR code à l\'entrée',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Appuyez pour afficher le QR code',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── GALERIE PHOTOS SUPPLÉMENTAIRES ──────────
                      if (ticket.images.length > 1) ...[
                        const Text(
                          'Photos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 90,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: ticket.images.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (context, index) => GestureDetector(
                              onTap: () => _showImageZoom(context, ticket.images, index),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(
                                  ticket.images[index],
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 90,
                                    height: 90,
                                    color: AppTheme.ivoryBackground,
                                    child: const Icon(Icons.image_not_supported_outlined,
                                        color: AppTheme.textSecondary),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── BOUTONS D'ACTION ─────────────────────────
                      _buildButtons(context),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Overlay de chargement
          if (_isProcessing)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryGold),
              ),
            ),
        ],
      ),
    );
  }

  void _showImageZoom(BuildContext context, List<String> images, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _ImageZoomDialog(images: images, initialIndex: initialIndex),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      color: AppTheme.premiumBlack,
      child: Center(
        child: Icon(
          Icons.confirmation_num_outlined,
          size: 60,
          color: AppTheme.primaryGold.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Column(
      children: [
        // Bouton principal : Mettre en vente / Retirer de la vente
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.ticket.forSale
                  ? AppTheme.textSecondary
                  : AppTheme.primaryGold,
              foregroundColor: widget.ticket.forSale
                  ? Colors.white
                  : AppTheme.premiumBlack,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            onPressed: _handlePutForSale,
            icon: Icon(widget.ticket.forSale
                ? Icons.storefront_outlined
                : Icons.sell_outlined),
            label: Text(
              widget.ticket.forSale ? 'RETIRER DE LA VENTE' : 'METTRE EN VENTE',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _OutlineButton(
                icon: Icons.edit_outlined,
                label: 'MODIFIER',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditTicketPage(ticket: widget.ticket),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OutlineButton(
                icon: Icons.send_outlined,
                label: 'TRANSMETTRE',
                color: AppTheme.locationBlue,
                onPressed: () => print('Transmettre cliqué'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.redAccent, width: 1),
              ),
            ),
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_outline, size: 20),
            label: const Text('SUPPRIMER', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Future<void> _handlePutForSale() async {
    // Si déjà en vente → retirer directement
    if (widget.ticket.forSale) {
      setState(() => _isProcessing = true);
      try {
        await _bourseService.withdrawFromSale(widget.ticket.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Billet retiré de la vente.')),
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
      return;
    }

    // Sinon → dialog pour choisir le prix de vente
    final priceController = TextEditingController(
      text: widget.ticket.price.replaceAll('EUR', '').replaceAll('€', '').trim(),
    );
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.sell_outlined, color: Color(0xFFD4AF37)),
            SizedBox(width: 10),
            Text('Mettre en vente', style: TextStyle(fontSize: 20)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.ticket.eventName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.ticket.date} • ${widget.ticket.place}',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              const Text(
                'Prix de vente souhaité (€)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  prefixText: '€  ',
                  hintText: 'ex : 25',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: Color(0xFFD4AF37), width: 1.5),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Veuillez saisir un prix';
                  }
                  final val = double.tryParse(v.trim().replaceAll(',', '.'));
                  if (val == null || val <= 0) {
                    return 'Prix invalide';
                  }
                  return null;
                },
              ),
              if (widget.ticket.price.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Prix d\'achat original : ${widget.ticket.price.replaceAll("EUR", "").replaceAll("€", "").trim()} €',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black38,
                      fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border:
                  Border.all(color: Colors.amber.withOpacity(0.25)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.amber, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Le QR code et les photos resteront masqués pour les acheteurs potentiels.',
                        style: TextStyle(
                            fontSize: 11, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ANNULER',
                style: TextStyle(color: Colors.black45)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('METTRE EN VENTE',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      final salePrice =
      priceController.text.trim().replaceAll(',', '.');
      await _bourseService.putTicketForSale(
        widget.ticket,
        salePrice: salePrice,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Billet mis en vente à $salePrice € !'),
            backgroundColor: const Color(0xFFD4AF37),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer ce billet ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ANNULER'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              await _ticketsService.deleteTicket(widget.ticket.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('SUPPRIMER'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS HELPER
// ─────────────────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryGold),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: TextStyle(
                fontSize: highlight ? 18 : 15,
                fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
                color: highlight ? AppTheme.primaryGold : AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 18,
      endIndent: 18,
      color: AppTheme.ivoryBackground,
    );
  }
}

class _StatusTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatusTile({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ZOOM DIALOG — pinch-to-zoom + swipe entre photos
// ─────────────────────────────────────────────────────────────────────────────
class _ImageZoomDialog extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _ImageZoomDialog({required this.images, required this.initialIndex});

  @override
  State<_ImageZoomDialog> createState() => _ImageZoomDialogState();
}

class _ImageZoomDialogState extends State<_ImageZoomDialog> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) => InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Center(
                child: Image.network(
                  widget.images[index],
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.white54,
                    size: 60,
                  ),
                ),
              ),
            ),
          ),
          // Bouton fermer
          Positioned(
            top: 40,
            right: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 22),
              ),
            ),
          ),
          // Indicateur page si plusieurs images
          if (widget.images.length > 1)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.images.length, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _currentIndex ? 18 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _currentIndex ? AppTheme.primaryGold : Colors.white38,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
              ),
            ),
        ],
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onPressed;
  const _OutlineButton({
    required this.icon,
    required this.label,
    this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textPrimary;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: c,
        side: BorderSide(color: c.withOpacity(0.4), width: 1),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }
}