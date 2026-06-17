// lib/pages/add_ticket_page.dart

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../models/ticket_model.dart';
import '../services/tickets_service.dart';
import '../services/ticket_image_service.dart';
import '../services/ticket_pdf_service.dart';
import '../services/magic_scan_service.dart';
import 'magic_scan_page.dart';

class AddTicketPage extends StatefulWidget {
  const AddTicketPage({super.key});

  @override
  State<AddTicketPage> createState() => _AddTicketPageState();
}

class _AddTicketPageState extends State<AddTicketPage> {
  final _eventNameController = TextEditingController();
  final _dateController      = TextEditingController();
  final _timeController      = TextEditingController();
  final _placeController     = TextEditingController();
  final _cityController      = TextEditingController();
  final _seatController      = TextEditingController();
  final _categoryController  = TextEditingController();
  final _priceController     = TextEditingController();
  final _qrController        = TextEditingController();
  final _nbPlacesController  = TextEditingController(text: '1');

  bool _forSale          = false;
  bool _reminderActive   = true;
  bool _isSaving         = false;
  bool _magicScanApplied = false;

  final TicketsService      _ticketsService      = TicketsService();
  final TicketImageService  _ticketImageService  = TicketImageService();
  final TicketPdfService    _ticketPdfService    = TicketPdfService();
  final ImagePicker         _imagePicker         = ImagePicker();

  File?   _selectedImage;
  File?   _selectedPdf;
  String? _selectedPdfName;

  Future<void> _launchMagicScan() async {
    final result = await Navigator.push<TicketScanResult>(
      context,
      MaterialPageRoute(builder: (_) => const MagicScanPage()),
    );

    if (result == null) return;

    setState(() {
      if (_eventNameController.text.isEmpty && result.eventName.isNotEmpty) {
        _eventNameController.text = result.eventName;
      }
      if (_dateController.text.isEmpty && result.date.isNotEmpty) {
        _dateController.text = result.date;
      }
      if (_timeController.text.isEmpty && result.time.isNotEmpty) {
        _timeController.text = result.time;
      }
      if (_placeController.text.isEmpty && result.place.isNotEmpty) {
        _placeController.text = result.place;
      }
      if (_cityController.text.isEmpty && result.city.isNotEmpty) {
        _cityController.text = result.city;
      }
      if (_seatController.text.isEmpty && result.seat.isNotEmpty) {
        _seatController.text = result.seat;
      }
      if (_categoryController.text.isEmpty && result.category.isNotEmpty) {
        _categoryController.text = result.category;
      }
      if (_priceController.text.isEmpty && result.price.isNotEmpty) {
        _priceController.text = result.price;
      }
      if (_qrController.text.isEmpty && result.qrValue.isNotEmpty) {
        _qrController.text = result.qrValue;
      }
      _magicScanApplied = true;
    });
  }

  Future<void> _pickImageFromGallery() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 1200,
    );
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<void> _pickImageFromCamera() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
      maxWidth: 1200,
    );
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<void> _pickPdfFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedPdf     = File(result.files.single.path!);
        _selectedPdfName = result.files.single.name;
      });
    }
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (pickedDate != null) {
      final formatted =
          '${pickedDate.day.toString().padLeft(2, '0')}/${pickedDate.month.toString().padLeft(2, '0')}/${pickedDate.year}';
      setState(() => _dateController.text = formatted);
    }
  }

  Future<void> _pickTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime != null) {
      final formatted =
          '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
      setState(() => _timeController.text = formatted);
    }
  }

  Future<void> _saveTicket() async {
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
          content: Text('Veuillez remplir au minimum le nom, la date et le lieu.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      List<String> imageUrls = [];
      String pdfUrl     = '';
      String pdfGroupId = '';

      if (_selectedImage != null) {
        final imageUrl = await _ticketImageService.uploadTicketImage(
          _selectedImage!,
          user.uid,
        );
        imageUrls.add(imageUrl);
      }

      if (_selectedPdf != null) {
        pdfUrl     = await _ticketPdfService.uploadTicketPdf(_selectedPdf!, user.uid);
        pdfGroupId = 'pdf_${DateTime.now().millisecondsSinceEpoch}';
      }

      final newTicket = TicketModel(
        id: '',
        userId: user.uid,
        category: _categoryController.text.trim(),
        date: _dateController.text.trim(),
        seat: _seatController.text.trim(),
        forSale: _forSale,
        saleStatus: _forSale ? 'disponible' : 'retire',
        time: _timeController.text.trim(),
        images: imageUrls,
        pdfUrl: pdfUrl,
        pdfGroupId: pdfGroupId,
        place: _placeController.text.trim(),
        nbPlaces: int.tryParse(_nbPlacesController.text.trim()) ?? 1,
        eventName: _eventNameController.text.trim(),
        price: _priceController.text.trim(),
        qr: _qrController.text.trim(),
        reminderActive: _reminderActive,
        city: _cityController.text.trim(),
        createdAt: DateTime.now().toString(),
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      await _ticketsService.addTicket(newTicket);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Billet enregistré avec succès')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'enregistrement : $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter un billet')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.premiumBlack,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Magic Scan ✨',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.goldSoft,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Scannez votre billet : le QR est lu et les informations sont extraites automatiquement.',
                  style: TextStyle(fontSize: 16, color: Colors.white70, height: 1.5),
                ),
                const SizedBox(height: 18),

                if (_magicScanApplied) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Formulaire pré-rempli — vérifiez et complétez si besoin.',
                            style: TextStyle(color: Colors.greenAccent, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                SizedBox(
                  height: 56,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _launchMagicScan,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(
                      _magicScanApplied ? 'Rescanner le billet' : 'Lancer le Magic Scan',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _pickImageFromGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choisir une photo depuis la galerie'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _pickImageFromCamera,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Prendre une photo avec la caméra'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _pickPdfFile,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Ajouter un PDF du billet'),
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedImage != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(_selectedImage!, height: 180, fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
          ],
          if (_selectedPdfName != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.ivoryBackground,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf, color: AppTheme.primaryGold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedPdfName!,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          TextField(
            controller: _eventNameController,
            decoration: const InputDecoration(labelText: 'Nom de l\'événement'),
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
          const SizedBox(height: 14),
          TextField(
            controller: _qrController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'QR scanné'),
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            value: _forSale,
            onChanged: (value) => setState(() => _forSale = value),
            title: const Text('Mettre en vente'),
          ),
          SwitchListTile(
            value: _reminderActive,
            onChanged: (value) => setState(() => _reminderActive = value),
            title: const Text('Activer le rappel'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveTicket,
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                  : const Text('Enregistrer le billet'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}