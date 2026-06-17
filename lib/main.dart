import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── Mode offline Firestore (Coffre-fort) ──────────────────────────────────
  // Les billets sont mis en cache local sur l'appareil.
  // L'utilisateur peut consulter ses billets même sans connexion internet.
  // Taille du cache : 100 Mo (largement suffisant pour des billets)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled    : true,
    cacheSizeBytes        : Settings.CACHE_SIZE_UNLIMITED,
  );

  await NotificationService.init();

  runApp(const MaBilletterieSereineApp());
}