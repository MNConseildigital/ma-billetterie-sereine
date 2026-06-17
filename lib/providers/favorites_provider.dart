import 'package:flutter/material.dart';
import '../models/event_model.dart';

class FavoritesProvider extends ChangeNotifier {
  final List<EventModel> _favorites = [];

  List<EventModel> get favorites => List.unmodifiable(_favorites);

  bool isFavorite(EventModel event) {
    return _favorites.any((item) => item.id == event.id);
  }

  void toggleFavorite(EventModel event) {
    if (isFavorite(event)) {
      _favorites.removeWhere((item) => item.id == event.id);
    } else {
      _favorites.add(event);
    }
    notifyListeners();
  }
}