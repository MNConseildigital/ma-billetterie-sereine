import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class PresentTicketPage extends StatefulWidget {
  final String? qrData;
  final List<String>? images;

  const PresentTicketPage({
    super.key,
    this.qrData,
    this.images,
  });

  @override
  State<PresentTicketPage> createState() => _PresentTicketPageState();
}

class _PresentTicketPageState extends State<PresentTicketPage> {
  double? _previousBrightness;

  @override
  void initState() {
    super.initState();
    _setupDisplay();
  }

  Future<void> _setupDisplay() async {
    try {
      // Sauvegarde luminosité actuelle
      _previousBrightness = await ScreenBrightness().current;

      // Luminosité max
      await ScreenBrightness().setScreenBrightness(1.0);
    } catch (_) {}

    // Empêche veille
    WakelockPlus.enable();

    // Force portrait
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  Future<void> _restoreDisplay() async {
    try {
      if (_previousBrightness != null) {
        await ScreenBrightness().setScreenBrightness(_previousBrightness!);
      }
    } catch (_) {}

    WakelockPlus.disable();

    // Réactive rotations normales
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  @override
  void dispose() {
    _restoreDisplay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasQr = widget.qrData != null && widget.qrData!.isNotEmpty;
    final hasImage = widget.images != null && widget.images!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Votre billet"),
        backgroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Center(
          child: hasQr
              ? _buildQrView()
              : hasImage
                  ? _buildImageFallback()
                  : const Text(
                      "Billet indisponible",
                      style: TextStyle(color: Colors.white),
                    ),
        ),
      ),
    );
  }

  Widget _buildQrView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth * 0.9;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: QrImageView(
                data: widget.qrData!,
                version: QrVersions.auto,
                size: size,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Présentez ce code à l'entrée",
              style: TextStyle(color: Colors.white70),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImageFallback() {
    final imagePath = widget.images!.first;

    return InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: Center(
        child: Image.file(
          File(imagePath),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}