import 'package:flutter/material.dart';
import '../models/ticket_model.dart';
import '../services/tickets_service.dart';

class EditTicketPage extends StatefulWidget {
  final TicketModel ticket;

  const EditTicketPage({
    super.key,
    required this.ticket,
  });

  @override
  State<EditTicketPage> createState() => _EditTicketPageState();
}

class _EditTicketPageState extends State<EditTicketPage> {
  late final TextEditingController _eventNameController;
  late final TextEditingController _dateController;
  late final TextEditingController _timeController;
  late final TextEditingController _placeController;
  late final TextEditingController _cityController;
  late final TextEditingController _seatController;
  late final TextEditingController _categoryController;
  late final TextEditingController _priceController;
  late final TextEditingController _nbPlacesController;

  late bool _forSale;
  late bool _reminderActive;

  bool _isSaving = false;

  final TicketsService _ticketsService = TicketsService();

  @override
  void initState() {
    super.initState();

    _eventNameController = TextEditingController(text: widget.ticket.eventName);
    _dateController = TextEditingController(text: widget.ticket.date);
    _timeController = TextEditingController(text: widget.ticket.time);
    _placeController = TextEditingController(text: widget.ticket.place);
    _cityController = TextEditingController(text: widget.ticket.city);
    _seatController = TextEditingController(text: widget.ticket.seat);
    _categoryController = TextEditingController(text: widget.ticket.category);
    _priceController = TextEditingController(text: widget.ticket.price);
    _nbPlacesController =
        TextEditingController(text: widget.ticket.nbPlaces.toString());

    _forSale = widget.ticket.forSale;
    _reminderActive = widget.ticket.reminderActive;
  }

  Future<void> _pickDate() async {
    final parts = _dateController.text.split('/');
    DateTime initialDate = DateTime.now();

    if (parts.length == 3) {
      try {
        initialDate = DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      } catch (_) {}
    }

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (pickedDate != null) {
      final formatted =
          '${pickedDate.day.toString().padLeft(2, '0')}/${pickedDate.month.toString().padLeft(2, '0')}/${pickedDate.year}';

      setState(() {
        _dateController.text = formatted;
      });
    }
  }

  Future<void> _pickTime() async {
    TimeOfDay initialTime = TimeOfDay.now();

    final parts = _timeController.text.split(':');
    if (parts.length == 2) {
      try {
        initialTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      } catch (_) {}
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (pickedTime != null) {
      final formatted =
          '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';

      setState(() {
        _timeController.text = formatted;
      });
    }
  }

  // ✅ FONCTION CORRIGÉE POUR UTILISER LE TicketModel
  Future<void> _saveChanges() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // On crée l'objet mis à jour avec toutes les valeurs des champs de texte
      final updatedTicket = TicketModel(
        id: widget.ticket.id,
        userId: widget.ticket.userId,
        eventName: _eventNameController.text.trim(),
        category: _categoryController.text.trim(),
        date: _dateController.text.trim(),
        time: _timeController.text.trim(),
        place: _placeController.text.trim(),
        city: _cityController.text.trim(),
        price: _priceController.text.trim(),
        seat: _seatController.text.trim(),
        nbPlaces: int.tryParse(_nbPlacesController.text.trim()) ?? 1,
        forSale: _forSale,
        saleStatus: widget.ticket.saleStatus, // On garde le statut actuel
        images: widget.ticket.images,         // On garde les photos actuelles
        pdfUrl: widget.ticket.pdfUrl,
        pdfGroupId: widget.ticket.pdfGroupId,
        qr: widget.ticket.qr,
        reminderActive: _reminderActive,
        createdAt: widget.ticket.createdAt,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      // On appelle le service avec l'objet complet
      await _ticketsService.updateTicket(updatedTicket);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Billet modifié avec succès')),
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
        title: const Text('Modifier le billet'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _eventNameController,
            decoration: const InputDecoration(labelText: 'Nom de l’événement'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _dateController,
            readOnly: true,
            onTap: _pickDate,
            decoration: const InputDecoration(
              labelText: 'Date',
              suffixIcon: Icon(Icons.calendar_today_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _timeController,
            readOnly: true,
            onTap: _pickTime,
            decoration: const InputDecoration(
              labelText: 'Heure',
              suffixIcon: Icon(Icons.access_time),
            ),
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
            decoration: const InputDecoration(labelText: 'Emplacement'),
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
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveChanges,
              child: _isSaving
                  ? const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              )
                  : const Text('Enregistrer les modifications'),
            ),
          ),
        ],
      ),
    );
  }
}