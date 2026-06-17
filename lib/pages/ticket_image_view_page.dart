import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class TicketImageViewPage extends StatelessWidget {
  final String imageUrl;

  const TicketImageViewPage({
    super.key,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Photo du billet'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(
                color: AppTheme.goldSoft,
              ),
            ),
            errorWidget: (context, url, error) => const Icon(
              Icons.image_not_supported,
              color: Colors.white54,
              size: 50,
            ),
          ),
        ),
      ),
    );
  }
}