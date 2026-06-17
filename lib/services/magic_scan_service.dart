// lib/services/magic_scan_service.dart
//
// Service Magic Scan — Ma Billetterie Sereine
// Corrections v2 :
//   - Timeout porté à 35s (Cloud Function OCR + Claude peut être lent)
//   - Gestion explicite du TimeoutException (message distinct)
//   - Pas de changement de l'API publique — compatible avec magic_scan_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// Modèle de résultat retourné au formulaire
// ─────────────────────────────────────────────────────────────────────────────
class TicketScanResult {
  final String eventName;
  final String date;      // format JJ/MM/AAAA
  final String time;      // format HH:MM
  final String place;
  final String city;
  final String seat;
  final String category;
  final String price;
  final String qrValue;

  const TicketScanResult({
    this.eventName = '',
    this.date      = '',
    this.time      = '',
    this.place     = '',
    this.city      = '',
    this.seat      = '',
    this.category  = '',
    this.price     = '',
    this.qrValue   = '',
  });

  /// Fusionne avec la valeur QR brute (le QR est toujours conservé).
  TicketScanResult copyWithQr(String rawQr) {
    return TicketScanResult(
      eventName: eventName,
      date:      date,
      time:      time,
      place:     place,
      city:      city,
      seat:      seat,
      category:  category,
      price:     price,
      qrValue:   rawQr,
    );
  }

  factory TicketScanResult.empty() => const TicketScanResult();

  factory TicketScanResult.fromJson(Map<String, dynamic> json) {
    return TicketScanResult(
      eventName: (json['eventName'] as String? ?? '').trim(),
      date:      (json['date']      as String? ?? '').trim(),
      time:      (json['time']      as String? ?? '').trim(),
      place:     (json['place']     as String? ?? '').trim(),
      city:      (json['city']      as String? ?? '').trim(),
      seat:      (json['seat']      as String? ?? '').trim(),
      category:  (json['category']  as String? ?? '').trim(),
      price:     (json['price']     as String? ?? '').trim(),
      qrValue:   (json['qrValue']   as String? ?? '').trim(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Enum des états d'erreur (pour l'UI)
// ─────────────────────────────────────────────────────────────────────────────
enum ScanErrorType { timeout, network, ocr, server, unknown }

class ScanException implements Exception {
  final ScanErrorType type;
  final String message;
  const ScanException(this.type, this.message);

  @override
  String toString() => 'ScanException($type): $message';

  /// Message lisible pour l'utilisateur
  String get userMessage {
    switch (type) {
      case ScanErrorType.timeout:
        return 'Le service met trop de temps à répondre. Vérifiez votre connexion et réessayez.';
      case ScanErrorType.network:
        return 'Impossible de contacter le service d\'analyse. Vérifiez votre connexion.';
      case ScanErrorType.ocr:
        return 'Impossible de lire le texte du billet. Essayez avec la galerie (image plus nette).';
      case ScanErrorType.server:
        return 'Le service d\'analyse est momentanément indisponible.';
      case ScanErrorType.unknown:
        return 'Une erreur inattendue s\'est produite. Réessayez.';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Service principal
// ─────────────────────────────────────────────────────────────────────────────
class MagicScanService {
  /// URL de la Cloud Function Firebase.
  static const String _cloudFunctionUrl =
      'https://parsetickettext-n2jt6xqlkq-ew.a.run.app';

  /// Timeout global pour l'appel Cloud Function (OCR + Claude).
  /// 35s pour couvrir les démarrages à froid (cold start) Firebase.
  static const Duration _timeout = Duration(seconds: 35);

  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  // ── 1. OCR ─────────────────────────────────────────────────────────────────
  Future<String> extractTextFromImage(File imageFile) async {
    try {
      final inputImage     = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      // OCR failed → on retourne vide, la Cloud Function retournera un résultat vide
      // plutôt que de planter toute la pipeline.
      return '';
    }
  }

  // ── 2. Appel Cloud Function avec Claude ───────────────────────────────────
  Future<TicketScanResult> parseWithClaude({
    required String rawText,
    required String qrValue,
  }) async {
    if (rawText.isEmpty && qrValue.isEmpty) {
      return TicketScanResult.empty();
    }

    try {
      final response = await http.post(
        Uri.parse(_cloudFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'rawText': rawText,
          'qrValue': qrValue,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return TicketScanResult.fromJson(json);
      } else {
        throw ScanException(
          ScanErrorType.server,
          'HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } on TimeoutException {
      throw const ScanException(
        ScanErrorType.timeout,
        'La requête a dépassé 35 secondes.',
      );
    } on SocketException {
      throw const ScanException(
        ScanErrorType.network,
        'Pas de connexion réseau.',
      );
    } on ScanException {
      rethrow;
    } catch (e) {
      throw ScanException(ScanErrorType.unknown, e.toString());
    }
  }

  // ── 3. Pipeline complet ───────────────────────────────────────────────────
  Future<TicketScanResult> scanFromImage({
    required File imageFile,
    required String qrValue,
  }) async {
    final rawText = await extractTextFromImage(imageFile);
    final result  = await parseWithClaude(rawText: rawText, qrValue: qrValue);
    return result.copyWithQr(qrValue);
  }

  // ── Libération ressources ML Kit ──────────────────────────────────────────
  void dispose() {
    _textRecognizer.close();
  }
}
