import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/ticket_model.dart';
import '../providers/auth_provider.dart';
import '../services/ticket_create_service.dart';

class DuplicateTicketPage extends StatefulWidget {
  final TicketModel sourceTicket;

  const DuplicateTicketPage({
    super.key,
    required this.sourceTicket,
  });

  @override
  State<DuplicateTicketPage> createState() => _DuplicateTicketPageState();
}

class _DuplicateTicketPageState extends State<DuplicateTicketPage> {
  late final TextEditingController _eventNameController;
  late final TextEditingController _dateController;
  late final TextEditingController _timeController;
  late final TextEditingController _placeController;
  late final TextEditingController _cityController;
  late final TextEditingController _seatController;
  late final TextEditingController _categoryController;
  late final TextEditingController _priceController;
  late final TextEditingController _qrController;
  late final TextEditingController _nbPlacesController;

  late bool _forSale;
  late bool _reminderActive;

  bool _isSaving = false;

  final TicketCreateService _ticketCreateService = TicketCreateService();

  @override
  void initState() {
    super.initState();

    final ticket = widget.sourceTicket;

    _eventNameController = TextEditingController(text: ticket.eventName);
    _dateController = TextEditingController(text: ticket.date);
    _timeController = TextEditingController(text: ticket.time);
    _placeController = TextEditingController(text: ticket.place);
    _cityController = TextEditingController(text: ticket.city);
    _seatController = TextEditingController(text: '');
    _categoryController = TextEditingController(text: ticket.category);
    _priceController = TextEditingController(text: ticket.price);
    _qrController = TextEditingController(text: '');
    _nbPlacesController = TextEditingController(text: ticket.nbPlaces.toString());

    _forSale = false;
    _reminderActive = ticket.reminderActive;
  }

  Future<void> _saveDuplicate() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez être connecté.')),
      );
      return;
    }

    if (_eventNameController.text.trim().isEmpty ||
        _dateController.text.trim().isEmpty ||
        _placeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir les informations obligatoires.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _ticketCreateService.addTicket(
        userId: user.uid,
        category: _categoryController.text.trim(),
        date: _dateController.text.trim(),
        seat: _seatController.text.trim(),
        forSale: _forSale,
        time: _timeController.text.trim(),
        images: widget.sourceTicket.images,
        pdfUrl: widget.sourceTicket.pdfUrl,
        pdfGroupId: widget.sourceTicket.pdfGroupId,
        place: _placeController.text.trim(),
        nbPlaces: int.tryParse(_nbPlacesController.text.trim()) ?? 1,
        eventName: _eventNameController.text.trim(),
        price: _priceController.text.trim(),
        qr: _qrController.text.trim(),
        reminderActive: _reminderActive,
        city: _cityController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Billet dupliqué avec succès'),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dupliquer le billet'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
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
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Commande liée',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.goldSoft,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Créez un autre billet lié à la même commande PDF. Modifiez seulement les informations spécifiques comme l’emplacement ou le QR.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _eventNameController,
            decoration: const InputDecoration(labelText: 'Nom de l’événement'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _dateController,
            readOnly: true,
            decoration: const InputDecoration(labelText: 'Date'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _timeController,
            readOnly: true,
            decoration: const InputDecoration(labelText: 'Heure'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _placeController,
            decoration: const InputDecoration(labelText: 'Lieu'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _cityController,
            decoration: const InputDecoration(labelText: 'Ville'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _seatController,
            decoration: const InputDecoration(
              labelText: 'Emplacement (à personnaliser)',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _categoryController,
            decoration: const InputDecoration(labelText: 'Catégorie'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _priceController,
            decoration: const InputDecoration(labelText: 'Prix'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nbPlacesController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Nombre de places'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _qrController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'QR du billet (à personnaliser)',
            ),
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            value: _forSale,
            onChanged: (value) {
              setState(() {
                _forSale = value;
              });
            },
            title: const Text('Mettre en vente'),
          ),
          SwitchListTile(
            value: _reminderActive,
            onChanged: (value) {
              setState(() {
                _reminderActive = value;
              });
            },
            title: const Text('Activer le rappel'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveDuplicate,
              icon: const Icon(Icons.copy),
              label: _isSaving
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
                  : const Text('Créer le billet lié'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}