import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/theme/app_theme.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final EventService eventService = EventService();

  final LatLng _defaultPosition = const LatLng(43.8367, 4.3601);

  Set<Marker> _buildMarkers(List<EventModel> events) {
    return events
        .where((event) => event.latitude != 0 && event.longitude != 0)
        .map((event) {
      return Marker(
        markerId: MarkerId(event.id),
        position: LatLng(event.latitude, event.longitude),
        infoWindow: InfoWindow(
          title: event.title,
          snippet: '${event.city} • ${event.date}',
        ),
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carte des événements'),
      ),
      body: StreamBuilder<List<EventModel>>(
        stream: eventService.getEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Erreur lors du chargement de la carte.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            );
          }

          final events = snapshot.data ?? [];
          final markers = _buildMarkers(events);

          if (markers.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Aucun événement localisable pour le moment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            );
          }

          return GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _defaultPosition,
              zoom: 7.2,
            ),
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
          );
        },
      ),
    );
  }
}