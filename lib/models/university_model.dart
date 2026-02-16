class UniversityModel {
  final String id;
  final String name;
  final Location location;
  final CampusBounds campusBounds;
  final String address;
  final String description;
  final String city;
  final String state;
  final String? zipCode;
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  UniversityModel({
    required this.id,
    required this.name,
    required this.location,
    required this.campusBounds,
    required this.address,
    required this.description,
    required this.city,
    required this.state,
    this.zipCode,
    this.imageUrl,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });


  factory UniversityModel.fromJson(Map<String, dynamic> json) {
    return UniversityModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      location: Location.fromJson(json['location'] ?? {}),
      campusBounds: CampusBounds.fromJson(json['campusBounds'] ?? {}),
      address: json['address'] ?? '',
      description: json['description'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      zipCode: json['zipCode'],
      imageUrl: json['imageUrl'],
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  factory UniversityModel.fromFirestore(String id, Map<String, dynamic> map) {
    return UniversityModel(
      id: id,
      name: map['name'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      address: map['address'] ?? '',
      description: map['description'] ?? '',
      zipCode: map['zipCode'],
      imageUrl: map['imageUrl'],
      isActive: map['isActive'] ?? true,

      // Firestore doesn't store these → give defaults
      location: Location(latitude: 0, longitude: 0),
      campusBounds: CampusBounds(
        northEast: LatLng(latitude: 0, longitude: 0),
        southWest: LatLng(latitude: 0, longitude: 0),
      ),

      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  factory UniversityModel.fromMap(String id, Map<String, dynamic> map) {
    return UniversityModel(
      id: id,
      name: map['name'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      location: Location(latitude: 0, longitude: 0),
      campusBounds: CampusBounds(
        northEast: LatLng(latitude: 0, longitude: 0),
        southWest: LatLng(latitude: 0, longitude: 0),
      ),
      address: map['address'] ?? '',
      description: map['description'] ?? '',
      zipCode: map['zipCode'],
      imageUrl: map['imageUrl'],
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'location': location.toJson(),
      'campusBounds': campusBounds.toJson(),
      'address': address,
      'description': description,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class Location {
  final double latitude;
  final double longitude;

  Location({
    required this.latitude,
    required this.longitude,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class CampusBounds {
  final LatLng northEast;
  final LatLng southWest;

  CampusBounds({
    required this.northEast,
    required this.southWest,
  });

  factory CampusBounds.fromJson(Map<String, dynamic> json) {
    return CampusBounds(
      northEast: LatLng.fromJson(json['northEast'] ?? {}),
      southWest: LatLng.fromJson(json['southWest'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'northEast': northEast.toJson(),
      'southWest': southWest.toJson(),
    };
  }
}

class LatLng {
  final double latitude;
  final double longitude;

  LatLng({
    required this.latitude,
    required this.longitude,
  });

  factory LatLng.fromJson(Map<String, dynamic> json) {
    return LatLng(
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
