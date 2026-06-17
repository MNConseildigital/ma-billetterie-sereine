import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // ← NOUVEAU
import 'package:provider/provider.dart';
import 'pages/home_page.dart';
import 'providers/auth_provider.dart';
import 'providers/favorites_provider.dart';

class MaBilletterieSereineApp extends StatelessWidget {
  const MaBilletterieSereineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Ma Billetterie Sereine',
        debugShowCheckedModeBanner: false,

        // ═══════════════════════════════════════════════════════════
        // LOCALISATION FRANÇAISE --- NOUVEAU
        // ═══════════════════════════════════════════════════════════
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('fr', 'FR'),
        ],
        locale: const Locale('fr', 'FR'),
        // ═══════════════════════════════════════════════════════════

        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: const Color(0xFFF7FAFC),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(fontSize: 18),
            bodyLarge: TextStyle(fontSize: 20),
          ), // ← corrigé : virgule ici, pas de point-virgule
        ),
        home: const HomePage(),
      ),
    );
  }
}