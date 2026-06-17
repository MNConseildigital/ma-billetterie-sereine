class EventModel {
  final String id;
  final String title;
  final String description;   // ← nouveau
  final String location;
  final String address;       // ← nouveau
  final String city;
  final String date;
  final String dateEnd;       // ← nouveau
  final String time;          // ← nouveau
  final String category;
  final String imageUrl;
  final String ticketUrl;     // ← nouveau (lien billetterie)
  final String price;         // ← nouveau (fourchette de prix Ticketmaster)
  final String partnerName;
  final bool   featured;
  final double latitude;
  final double longitude;
  final String department;
  final String region;
  final String source;
  final String sourceId;
  final bool   isActive;

  const EventModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.location,
    this.address     = '',
    required this.city,
    required this.date,
    this.dateEnd     = '',
    this.time        = '',
    required this.category,
    required this.imageUrl,
    this.ticketUrl   = '',
    this.price       = '',
    required this.partnerName,
    required this.featured,
    required this.latitude,
    required this.longitude,
    required this.department,
    required this.region,
    required this.source,
    required this.sourceId,
    required this.isActive,
  });

  factory EventModel.fromMap(String id, Map<String, dynamic> map) {
    return EventModel(
      id:          id,
      title:       map['title']       ?? '',
      description: map['description'] ?? '',
      location:    map['location']    ?? '',
      address:     map['address']     ?? '',
      city:        map['city']        ?? '',
      date:        map['date']        ?? '',
      dateEnd:     map['dateEnd']     ?? '',
      time:        map['time']        ?? '',
      category:    map['category']    ?? '',
      imageUrl:    map['imageUrl']    ?? '',
      ticketUrl:   map['ticketUrl']   ?? '',
      price:       map['price']       ?? '',
      partnerName: map['partnerName'] ?? '',
      featured:    map['featured']    ?? false,
      latitude:    (map['latitude']   ?? 0).toDouble(),
      longitude:   (map['longitude']  ?? 0).toDouble(),
      department:  map['department']  ?? '',
      region:      map['region']      ?? '',
      source:      map['source']      ?? '',
      sourceId:    map['sourceId']    ?? '',
      isActive:    map['isActive']    ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title':       title,
      'description': description,
      'location':    location,
      'address':     address,
      'city':        city,
      'date':        date,
      'dateEnd':     dateEnd,
      'time':        time,
      'category':    category,
      'imageUrl':    imageUrl,
      'ticketUrl':   ticketUrl,
      'price':       price,
      'partnerName': partnerName,
      'featured':    featured,
      'latitude':    latitude,
      'longitude':   longitude,
      'department':  department,
      'region':      region,
      'source':      source,
      'sourceId':    sourceId,
      'isActive':    isActive,
    };
  }
}