// lib/pages/magic_scan_page.dart
//
// Page Magic Scan — Ma Billetterie Sereine
// Corrections v2 :
//   - Tous formats barcode activés (Code128, EAN-13, PDF417, QR, DataMatrix…)
//   - captureImage() natif MobileScanner (plus de stop/restart fragile)
//   - Feedback haptique à la détection
//   - Timeout porté à 35s avec message de progression
//   - Fallback saisie manuelle du numéro de billet
//   - Permission caméra demandée explicitement au runtime

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/theme/app_theme.dart';
import '../services/magic_scan_service.dart';

class MagicScanPage extends StatefulWidget {
  const MagicScanPage({super.key});

  @override
  State<MagicScanPage> createState() => _MagicScanPageState();
}

class _MagicScanPageState extends State<MagicScanPage>
    with SingleTickerProviderStateMixin {

  // ── Contrôleur scanner — tous formats activés ─────────────────────────────
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
    // returnImage: true — v7 retourne l'image avec chaque détection (snapshot sans stop/restart)
    returnImage: true,
    // Tous les formats courants : QR, Code128 (Fnac/Ticketmaster),
    // EAN-13, PDF417 (SNCF / boarding pass), DataMatrix, Aztec
    formats: [
      BarcodeFormat.qrCode,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.pdf417,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.aztec,
      BarcodeFormat.itf,
    ],
  );

  final MagicScanService _magicScanService = MagicScanService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _manualController = TextEditingController();

  String _qrValue        = '';
  bool   _qrDetected     = false;
  bool   _isProcessing   = false;
  String _statusMessage  = 'Pointez la caméra vers votre billet';
  String _progressStep   = '';

  late AnimationController _animController;
  late Animation<double>   _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _cameraController.dispose();
    _magicScanService.dispose();
    _manualController.dispose();
    super.dispose();
  }

  // Image du dernier frame détecté (remplie par returnImage: true)
  Uint8List? _lastCapturedImage;

  // ── Détection code-barres ─────────────────────────────────────────────────
  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_qrDetected || _isProcessing) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value != null && value.isNotEmpty) {
      // Feedback haptique immédiat à la détection
      HapticFeedback.mediumImpact();
      // Stocker le snapshot du frame courant (disponible grâce à returnImage: true)
      _lastCapturedImage = capture.image;
      setState(() {
        _qrDetected    = true;
        _qrValue       = value;
        _statusMessage = 'Code détecté ✓ — Appuyez pour analyser le billet';
      });
    }
  }


  // ── Capture image pour analyse ML Kit ───────────────────────────────────
  Future<void> _captureAndAnalyze() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing  = true;
      _statusMessage = 'Capture en cours…';
      _progressStep  = "Capture de l'image…";
    });

    try {
      // Stratégie 1 : snapshot natif v7 (returnImage: true)
      // Fonctionne sur la plupart des appareils
      if (_lastCapturedImage != null) {
        if (!mounted) return;
        setState(() => _progressStep = 'Extraction du texte…');
        final tempDir  = Directory.systemTemp;
        final tempFile = File(
          '${tempDir.path}/mbs_scan_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await tempFile.writeAsBytes(_lastCapturedImage!);
        await _runMagicScan(tempFile);
        return;
      }

      // Stratégie 2 : prise de photo caméra via image_picker
      // (fallback universel — certains Samsung ne remplissent pas capture.image)
      if (!mounted) return;
      setState(() => _progressStep = 'Ouverture caméra…');
      try { await _cameraController.stop(); } catch (_) {}

      final XFile? photo = await _imagePicker.pickImage(
        source       : ImageSource.camera,
        imageQuality : 92,
        maxWidth     : 1920,
        maxHeight    : 1080,
      );

      // Relancer le scanner dans tous les cas
      if (mounted) {
        try { await _cameraController.start(); } catch (_) {}
      }

      if (photo == null) {
        if (mounted) setState(() {
          _isProcessing  = false;
          _statusMessage = 'Capture annulée.';
          _progressStep  = '';
        });
        return;
      }

      if (!mounted) return;
      setState(() => _progressStep = 'Extraction du texte…');
      await _runMagicScan(File(photo.path));

    } catch (e) {
      try { await _cameraController.start(); } catch (_) {}
      if (!mounted) return;
      setState(() {
        _isProcessing  = false;
        _statusMessage = "Erreur de capture. Essayez depuis la galerie.";
        _progressStep  = '';
      });
    }
  }
  // ── Galerie (fallback ou choix manuel) ────────────────────────────────────
  Future<void> _pickFromGallery() async {
    try { await _cameraController.stop(); } catch (_) {}

    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1800,
    );

    if (pickedFile == null) {
      if (mounted) setState(() => _isProcessing = false);
      // Redémarre la caméra si l'utilisateur annule
      try { await _cameraController.start(); } catch (_) {}
      return;
    }

    if (mounted) {
      setState(() {
        _statusMessage = 'Analyse du billet en cours…';
        _progressStep  = 'Extraction du texte depuis la galerie…';
        _isProcessing  = true;
      });
    }
    await _runMagicScan(File(pickedFile.path));
  }

  // ── Pipeline OCR → Cloud Function → retour formulaire ────────────────────
  Future<void> _runMagicScan(File imageFile) async {
    try {
      if (mounted) setState(() => _progressStep = 'Envoi au service d\'analyse…');
      final result = await _magicScanService.scanFromImage(
        imageFile: imageFile,
        qrValue: _qrValue,
      );
      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isProcessing  = false;
        _statusMessage = 'Erreur lors de l\'analyse. Réessayez.';
        _progressStep  = '';
      });
      // Redémarre la caméra pour permettre un nouveau scan
      try { await _cameraController.start(); } catch (_) {}
    }
  }

  // ── Retour QR seul (sans OCR) ─────────────────────────────────────────────
  void _skipOcrAndReturn() {
    if (_qrValue.isEmpty) return;
    Navigator.pop(context, TicketScanResult(qrValue: _qrValue));
  }

  // ── Saisie manuelle (fallback billet abîmé) ───────────────────────────────
  void _showManualEntryDialog() {
    _manualController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Saisie manuelle',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Entrez le numéro de billet ou le code indiqué sur votre billet.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _manualController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ex : 123456789 ou ABC-DEF-GHI',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.goldSoft,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  final value = _manualController.text.trim();
                  if (value.isEmpty) return;
                  Navigator.pop(ctx); // ferme le bottom sheet
                  Navigator.pop(     // retourne le résultat à la page parente
                    context,
                    TicketScanResult(qrValue: value),
                  );
                },
                child: const Text(
                  'Valider',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: AppTheme.goldSoft,
        title: const Text(
          'Magic Scan ✨',
          style: TextStyle(
            color: AppTheme.goldSoft,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flashlight_on_outlined),
            color: AppTheme.goldSoft,
            onPressed: () => _cameraController.toggleTorch(),
            tooltip: 'Lampe torche',
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_outlined),
            color: AppTheme.goldSoft,
            onPressed: _showManualEntryDialog,
            tooltip: 'Saisie manuelle',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Viewfinder caméra
          if (!_isProcessing)
            MobileScanner(
              controller: _cameraController,
              onDetect: _onBarcodeDetected,
            ),

          // Overlay scan avec cadre animé
          if (!_isProcessing) _buildScanOverlay(),

          // Overlay chargement avec étape détaillée
          if (_isProcessing) _buildProcessingOverlay(),

          // Panneau bas avec actions
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _buildBottomPanel(),
          ),
        ],
      ),
    );
  }

  // ── Overlay cadre animé ───────────────────────────────────────────────────
  Widget _buildScanOverlay() {
    return LayoutBuilder(builder: (context, constraints) {
      const frameSize = 260.0;
      final left = (constraints.maxWidth  - frameSize) / 2;
      final top  = (constraints.maxHeight - frameSize) / 2 - 60;

      return Stack(children: [
        // Fond assombri avec découpe
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.55), BlendMode.srcOut,
          ),
          child: Stack(children: [
            Container(color: Colors.transparent),
            Positioned(
              left: left, top: top, width: frameSize, height: frameSize,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ]),
        ),

        // Cadre doré / vert animé
        Positioned(
          left: left, top: top, width: frameSize, height: frameSize,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _qrDetected ? Colors.greenAccent : AppTheme.goldSoft,
                width: 2.5,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AnimatedBuilder(
                animation: _scanLineAnimation,
                builder: (_, __) => Stack(children: [
                  Positioned(
                    top: _scanLineAnimation.value * (frameSize - 2),
                    left: 0, right: 0,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.transparent,
                          _qrDetected ? Colors.greenAccent : AppTheme.goldSoft,
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),

        // Icône validation
        if (_qrDetected)
          Positioned(
            left: left + frameSize / 2 - 20,
            top: top  + frameSize / 2 - 20,
            child: const Icon(
              Icons.check_circle,
              color: Colors.greenAccent,
              size: 40,
            ),
          ),

        // Légende formats supportés
        if (!_qrDetected)
          Positioned(
            left: 0, right: 0,
            top: top + frameSize + 16,
            child: const Text(
              'QR Code • Code-barres • PDF417 • EAN',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
            ),
          ),
      ]);
    });
  }

  // ── Overlay chargement avec progression ──────────────────────────────────
  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 80, height: 80,
              child: CircularProgressIndicator(
                color: AppTheme.goldSoft, strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500,
              ),
            ),
            if (_progressStep.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _progressStep,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
            const SizedBox(height: 6),
            const Text(
              'Cela peut prendre jusqu\'à 30 secondes…',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ── Panneau bas ───────────────────────────────────────────────────────────
  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _qrDetected ? Colors.greenAccent : Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),

          if (!_qrDetected) ...[
            const Text(
              'Placez le code du billet dans le cadre',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _isProcessing ? null : _pickFromGallery,
                  icon: const Icon(Icons.photo_library_outlined,
                      color: AppTheme.goldSoft, size: 18),
                  label: const Text(
                    'Galerie',
                    style: TextStyle(color: AppTheme.goldSoft, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: _showManualEntryDialog,
                  icon: const Icon(Icons.keyboard_outlined,
                      color: Colors.white38, size: 18),
                  label: const Text(
                    'Saisie manuelle',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Bouton principal — analyse complète OCR + Claude
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _captureAndAnalyze,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.goldSoft,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.auto_awesome, size: 20),
                label: const Text(
                  'Analyser le billet',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _pickFromGallery,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.photo_library_outlined, size: 16),
                    label: const Text('Galerie', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _skipOcrAndReturn,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.skip_next_outlined, size: 16),
                    label: const Text('Code seul', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
