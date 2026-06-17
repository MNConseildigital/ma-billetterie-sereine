import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/actu_model.dart';

class ActuDetailPage extends StatelessWidget {
  final ActuModel actu;

  const ActuDetailPage({
    super.key,
    required this.actu,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail de l’actualité'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: actu.imageUrl.isNotEmpty
                ? Image.network(
              actu.imageUrl,
              height: 260,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 260,
                  color: AppTheme.premiumBlack,
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      color: Colors.white54,
                      size: 44,
                    ),
                  ),
                );
              },
            )
                : Container(
              height: 260,
              color: AppTheme.premiumBlack,
              child: const Center(
                child: Icon(
                  Icons.image,
                  color: Colors.white54,
                  size: 44,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            actu.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            actu.city,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryGold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            actu.description,
            style: const TextStyle(
              fontSize: 17,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}