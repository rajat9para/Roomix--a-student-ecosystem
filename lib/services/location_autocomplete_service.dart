import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Location prediction result from autocomplete
class LocationPrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
  final double? latitude;
  final double? longitude;

  LocationPrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
    this.latitude,
    this.longitude,
  });

  factory LocationPrediction.fromJson(Map<String, dynamic> json) {
    return LocationPrediction(
      placeId: json['placeId'] ?? json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: json['mainText'] ?? json['structured_formatting']?['main_text'] ?? '',
      secondaryText: json['secondaryText'] ?? json['structured_formatting']?['secondary_text'] ?? '',
      latitude: (json['latitude'] ?? json['lat']) as double?,
      longitude: (json['longitude'] ?? json['lng']) as double?,
    );
  }

  Map<String, dynamic> toJson() => {
    'placeId': placeId,
    'description': description,
    'mainText': mainText,
    'secondaryText': secondaryText,
    'latitude': latitude,
    'longitude': longitude,
  };
}

/// Location details with full information
class LocationDetails {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;

  LocationDetails({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    this.city,
    this.state,
    this.country,
    this.postalCode,
  });

  factory LocationDetails.fromJson(Map<String, dynamic> json) {
    return LocationDetails(
      placeId: json['placeId'] ?? json['place_id'] ?? '',
      name: json['name'] ?? '',
      formattedAddress: json['formattedAddress'] ?? json['formatted_address'] ?? '',
      latitude: (json['latitude'] ?? json['geometry']?['location']?['lat'] ?? 0.0) as double,
      longitude: (json['longitude'] ?? json['geometry']?['location']?['lng'] ?? 0.0) as double,
      city: json['city'] ?? json['address_components']?[0]?['long_name'],
      state: json['state'],
      country: json['country'],
      postalCode: json['postalCode'] ?? json['postal_code'],
    );
  }
}

/// Comprehensive location service with autocomplete support
/// Uses multiple providers: MapMyIndia, OpenStreetMap Nominatim, and device GPS
class LocationAutocompleteService {
  static final LocationAutocompleteService _instance = LocationAutocompleteService._internal();
  factory LocationAutocompleteService() => _instance;
  LocationAutocompleteService._internal();

  // MapMyIndia API Configuration
  static const String _mapMyIndiaBaseUrl = 'https://atlas.mapmyindia.com/api/places/search';
  static const String _mapMyIndiaAutocompleteUrl = 'https://atlas.mapmyindia.com/api/places/search/json';
  
  // OpenStreetMap Nominatim (free fallback)
  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
  
  // MapMyIndia API Key (set from map_service or settings)
  String? _mapMyIndiaKey;
  
  // HTTP client
  final http.Client _httpClient = http.Client();
  
  // Debouncer for search
  Timer? _debounceTimer;
  final Duration _debounceDuration = const Duration(milliseconds: 300);
  
  // Cache for predictions
  final Map<String, List<LocationPrediction>> _cache = {};
  final int _maxCacheSize = 50;

  // Getters
  bool get hasMapMyIndiaKey => _mapMyIndiaKey != null && _mapMyIndiaKey!.isNotEmpty;
  
  /// Set MapMyIndia API key
  set mapMyIndiaKey(String? key) {
    _mapMyIndiaKey = key;
    debugPrint('MapMyIndia API key ${key != null ? "set" : "cleared"}');
  }

  /// Initialize the service with API key
  void initialize({String? apiKey}) {
    if (apiKey != null && apiKey.isNotEmpty) {
      _mapMyIndiaKey = apiKey;
      debugPrint('LocationAutocompleteService initialized with API key');
    }
  }

  // ==================== AUTOCOMPLETE SEARCH ====================

  /// Search for locations with debouncing
  Future<List<LocationPrediction>> searchWithDebounce(
    String query, {
    String? country,
    String? bounds,
    int limit = 5,
  }) async {
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    // Create completer for async result
    final completer = Completer<List<LocationPrediction>>();
    
    // Set new timer
    _debounceTimer = Timer(_debounceDuration, () async {
      try {
        final results = await search(query, country: country, bounds: bounds, limit: limit);
        if (!completer.isCompleted) {
          completer.complete(results);
        }
      } catch (e) {
        if (!completer.isCompleted) {
          completer.complete([]);
        }
      }
    });
    
    return completer.future;
  }

  /// Search for locations (immediate)
  Future<List<LocationPrediction>> search(
    String query, {
    String? country,
    String? bounds,
    int limit = 5,
  }) async {
    if (query.trim().length < 2) return [];

    // Check cache first
    final cacheKey = '$query-$country-$bounds-$limit';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    List<LocationPrediction> predictions = [];

    // Try MapMyIndia first if API key is available
    if (hasMapMyIndiaKey) {
      try {
        predictions = await _searchMapMyIndia(query, country: country, limit: limit);
        if (predictions.isNotEmpty) {
          _addToCache(cacheKey, predictions);
          return predictions;
        }
      } catch (e) {
        debugPrint('MapMyIndia search failed: $e');
      }
    }

    // Fallback to OpenStreetMap Nominatim (free, no API key needed)
    try {
      predictions = await _searchNominatim(query, country: country, limit: limit);
      _addToCache(cacheKey, predictions);
    } catch (e) {
      debugPrint('Nominatim search failed: $e');
    }

    return predictions;
  }

  /// Search using MapMyIndia Places API
  Future<List<LocationPrediction>> _searchMapMyIndia(
    String query, {
    String? country,
    int limit = 5,
  }) async {
    if (_mapMyIndiaKey == null) return [];

    try {
      final uri = Uri.parse(_mapMyIndiaAutocompleteUrl).replace(
        queryParameters: {
          'query': query,
          'limit': limit.toString(),
          if (country != null) 'region': country,
        },
      );

      final response = await _httpClient.get(
        uri,
        headers: {
          'Authorization': 'bearer $_mapMyIndiaKey',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['suggestedLocations'] ?? data['results'] ?? [];
        
        return results.map((item) => LocationPrediction(
          placeId: item['placeId'] ?? item['place_id'] ?? item['eLoc'] ?? '',
          description: item['placeAddress'] ?? item['display_name'] ?? '',
          mainText: item['placeName'] ?? item['name'] ?? '',
          secondaryText: item['placeAddress'] ?? '',
          latitude: double.tryParse(item['latitude']?.toString() ?? ''),
          longitude: double.tryParse(item['longitude']?.toString() ?? ''),
        )).toList();
      }
    } catch (e) {
      debugPrint('MapMyIndia API error: $e');
    }

    return [];
  }

  /// Search using OpenStreetMap Nominatim (free, no API key required)
  Future<List<LocationPrediction>> _searchNominatim(
    String query, {
    String? country,
    int limit = 5,
  }) async {
    try {
      // Add India bias for better results
      final viewbox = '68.0,8.0,97.0,35.0'; // India bounds
      final uri = Uri.parse('$_nominatimBaseUrl/search').replace(
        queryParameters: {
          'q': query,
          'format': 'json',
          'addressdetails': '1',
          'limit': limit.toString(),
          'bounded': '0',
          'viewbox': viewbox,
          if (country != null) 'countrycodes': country,
        },
      );

      final response = await _httpClient.get(
        uri,
        headers: {
          'User-Agent': 'RoomixApp/2.4.0 (PG Finder Application)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        
        return results.map((item) {
          final address = item['address'] as Map<String, dynamic>? ?? {};
          final displayName = item['display_name'] as String? ?? '';
          
          // Build a shorter description
          final parts = <String>[];
          if (address['name'] != null) parts.add(address['name']);
          if (address['road'] != null) parts.add(address['road']);
          if (address['suburb'] != null) parts.add(address['suburb']);
          if (address['city'] != null) parts.add(address['city']);
          if (address['state'] != null) parts.add(address['state']);
          
          return LocationPrediction(
            placeId: item['place_id']?.toString() ?? '',
            description: displayName,
            mainText: parts.isNotEmpty ? parts.first : displayName.split(',').first,
            secondaryText: parts.length > 1 ? parts.skip(1).take(2).join(', ') : '',
            latitude: double.tryParse(item['lat']?.toString() ?? ''),
            longitude: double.tryParse(item['lon']?.toString() ?? ''),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Nominatim API error: $e');
    }

    return [];
  }

  // ==================== UNIVERSITY SEARCH ====================

  /// Search for universities using Nominatim
  /// Results are biased towards India and optionally towards user's location
  Future<List<LocationPrediction>> searchUniversities(
    String query, {
    double? userLat,
    double? userLng,
    int limit = 10,
  }) async {
    if (query.trim().length < 2) return [];

    // Check cache
    final cacheKey = 'uni_$query';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      // Use Nominatim with university/college type filter
      final queryParams = <String, String>{
        'q': '$query university OR college',
        'format': 'json',
        'addressdetails': '1',
        'limit': limit.toString(),
        'countrycodes': 'in', // India bias
      };

      // Add location bias if available
      if (userLat != null && userLng != null) {
        // Viewbox around user location (~200km radius)
        final latDelta = 1.8; // ~200km
        final lngDelta = 1.8;
        queryParams['viewbox'] = '${userLng - lngDelta},${userLat - latDelta},${userLng + lngDelta},${userLat + latDelta}';
        queryParams['bounded'] = '0'; // prefer but don't restrict
      } else {
        // Default India viewbox
        queryParams['viewbox'] = '68.0,8.0,97.0,35.0';
        queryParams['bounded'] = '0';
      }

      final uri = Uri.parse('$_nominatimBaseUrl/search').replace(
        queryParameters: queryParams,
      );

      final response = await _httpClient.get(
        uri,
        headers: {
          'User-Agent': 'RoomixApp/2.4.0 (PG Finder Application)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);

        // Filter to only university/college results
        final universities = results.where((item) {
          final type = item['type']?.toString().toLowerCase() ?? '';
          final category = item['class']?.toString().toLowerCase() ?? '';
          final name = item['display_name']?.toString().toLowerCase() ?? '';
          return type == 'university' ||
              type == 'college' ||
              category == 'amenity' && (name.contains('university') || name.contains('college') || name.contains('institute'));
        }).toList();

        // Use all results if no university-specific ones found
        final effectiveResults = universities.isNotEmpty ? universities : results;

        final predictions = effectiveResults.map((item) {
          final address = item['address'] as Map<String, dynamic>? ?? {};
          final displayName = item['display_name'] as String? ?? '';
          final name = item['name'] as String? ?? displayName.split(',').first;
          
          // Build city/state info
          final city = address['city'] ?? address['town'] ?? address['village'] ?? address['county'] ?? '';
          final state = address['state'] ?? '';
          final secondary = [if (city.isNotEmpty) city, if (state.isNotEmpty) state].join(', ');

          return LocationPrediction(
            placeId: item['place_id']?.toString() ?? '',
            description: displayName,
            mainText: name,
            secondaryText: secondary,
            latitude: double.tryParse(item['lat']?.toString() ?? ''),
            longitude: double.tryParse(item['lon']?.toString() ?? ''),
          );
        }).toList();

        _addToCache(cacheKey, predictions);
        return predictions;
      }
    } catch (e) {
      debugPrint('University search error: $e');
    }

    return [];
  }

  // ==================== PLACE DETAILS ====================

  /// Get detailed information for a place
  Future<LocationDetails?> getPlaceDetails(String placeId, {double? lat, double? lng}) async {
    // If we already have coordinates, use reverse geocoding
    if (lat != null && lng != null) {
      return _getDetailsFromCoordinates(lat, lng);
    }

    // Try MapMyIndia first
    if (hasMapMyIndiaKey) {
      try {
        final details = await _getMapMyIndiaPlaceDetails(placeId);
        if (details != null) return details;
      } catch (e) {
        debugPrint('MapMyIndia place details failed: $e');
      }
    }

    // Fallback to Nominatim
    try {
      return await _getNominatimPlaceDetails(placeId);
    } catch (e) {
      debugPrint('Nominatim place details failed: $e');
    }

    return null;
  }

  /// Get place details from MapMyIndia
  Future<LocationDetails?> _getMapMyIndiaPlaceDetails(String placeId) async {
    if (_mapMyIndiaKey == null) return null;

    try {
      final uri = Uri.parse('https://atlas.mapmyindia.com/api/places/detail/json').replace(
        queryParameters: {'placeId': placeId},
      );

      final response = await _httpClient.get(
        uri,
        headers: {
          'Authorization': 'bearer $_mapMyIndiaKey',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return LocationDetails.fromJson({
          'placeId': placeId,
          'name': data['placeName'],
          'formattedAddress': data['placeAddress'],
          'latitude': double.tryParse(data['latitude']?.toString() ?? ''),
          'longitude': double.tryParse(data['longitude']?.toString() ?? ''),
          'city': data['city'],
          'state': data['state'],
        });
      }
    } catch (e) {
      debugPrint('MapMyIndia place details error: $e');
    }

    return null;
  }

  /// Get place details from Nominatim
  Future<LocationDetails?> _getNominatimPlaceDetails(String placeId) async {
    try {
      final uri = Uri.parse('$_nominatimBaseUrl/details').replace(
        queryParameters: {
          'place_id': placeId,
          'format': 'json',
        },
      );

      final response = await _httpClient.get(
        uri,
        headers: {
          'User-Agent': 'RoomixApp/2.4.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return LocationDetails.fromJson({
          'placeId': placeId,
          'name': data['name'],
          'formattedAddress': data['localname'],
          'latitude': double.tryParse(data['centroid']?['coordinates']?[1]?.toString() ?? ''),
          'longitude': double.tryParse(data['centroid']?['coordinates']?[0]?.toString() ?? ''),
        });
      }
    } catch (e) {
      debugPrint('Nominatim place details error: $e');
    }

    return null;
  }

  /// Get details from coordinates using reverse geocoding
  Future<LocationDetails?> _getDetailsFromCoordinates(double lat, double lng) async {
    try {
      // Use geocoding package
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return LocationDetails(
          placeId: '${lat}_$lng',
          name: place.name ?? '',
          formattedAddress: '${place.street ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}',
          latitude: lat,
          longitude: lng,
          city: place.locality,
          state: place.administrativeArea,
          country: place.country,
          postalCode: place.postalCode,
        );
      }
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
    }

    // Return basic coordinates as fallback
    return LocationDetails(
      placeId: '${lat}_$lng',
      name: 'Selected Location',
      formattedAddress: 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}',
      latitude: lat,
      longitude: lng,
    );
  }

  // ==================== CURRENT LOCATION ====================

  /// Get current device location
  Future<LocationDetails?> getCurrentLocation() async {
    try {
      // Check permission
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location service is disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }

      // Get position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      // Get address from coordinates
      return await _getDetailsFromCoordinates(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return null;
    }
  }

  /// Get current city name
  Future<String?> getCurrentCity() async {
    try {
      final location = await getCurrentLocation();
      return location?.city ?? location?.state;
    } catch (e) {
      debugPrint('Error getting current city: $e');
      return null;
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Add to cache with size limit
  void _addToCache(String key, List<LocationPrediction> value) {
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  /// Clear cache
  void clearCache() {
    _cache.clear();
  }

  /// Dispose resources
  void dispose() {
    _debounceTimer?.cancel();
    _httpClient.close();
    _cache.clear();
  }
}