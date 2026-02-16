import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:roomix/models/map_marker_model.dart';

/// Map Service for Roomix
/// Uses MapMyIndia Static Maps API and WebView for interactive maps
class MapService {
  static final MapService _instance = MapService._internal();
  factory MapService() => _instance;
  MapService._internal();

  // MapMyIndia Configuration - Loaded from assets
  static const String _confFileName = 'lib/maps_keys/app1770570556072i1926669779.a.conf';

  // API Keys (loaded from config)
  String? _restApiKey;
  bool _isInitialized = false;
  
  // Runtime API key override (set by user in settings)
  static String? _runtimeKey;
  
  // Placeholder asset for when map is unavailable
  static const String placeholderAsset = 'assets/images/map_placeholder.png';

  // Getters
  bool get isInitialized => _isInitialized;
  String? get restApiKey => _restApiKey;
  
  /// Check if API key is available (either from config or runtime)
  static bool get hasApiKey => 
    (_runtimeKey != null && _runtimeKey!.isNotEmpty) || 
    (_instance._restApiKey != null && _instance._restApiKey!.isNotEmpty);
  
  /// Legacy getter for backward compatibility
  static bool get hasValidApiKey => hasApiKey;
  
  /// Runtime key setter (for settings screen)
  static set runtimeKey(String? key) {
    _runtimeKey = key;
    if (key != null && key.isNotEmpty) {
      _instance._restApiKey = key;
      _instance._isInitialized = true;
    }
  }
  
  /// Get the effective API key (runtime key takes precedence)
  String? get _effectiveApiKey => _runtimeKey ?? _restApiKey;

  /// Initialize MapMyIndia from config files
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load configuration file from assets
      final confData = await rootBundle.loadString(_confFileName);

      if (confData.isEmpty) {
        debugPrint('MapMyIndia: Configuration file not found in assets');
        return;
      }

      // Extract REST API key from config
      _restApiKey = _extractRestKey(confData);

      if (_restApiKey != null && _restApiKey!.isNotEmpty) {
        _isInitialized = true;
        debugPrint('MapMyIndia SDK initialized successfully');
      } else {
        debugPrint('MapMyIndia: Could not extract API key from config');
      }
    } catch (e) {
      debugPrint('MapMyIndia initialization error: $e');
    }
  }

  /// Extract REST API key from config file
  String? _extractRestKey(String config) {
    try {
      // Try to find REST API key in various formats
      final lines = config.split('\n');
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('#')) continue;

        // Look for rest_key, rest_api_key, or api_key patterns
        if (line.toLowerCase().contains('rest') &&
            line.toLowerCase().contains('key')) {
          final parts = line.split(RegExp(r'[=\s]+'));
          if (parts.length > 1) {
            return parts.last.trim();
          }
        }
      }

      // Alternative: look for any line that might contain the key
      for (var line in lines) {
        line = line.trim();
        if (line.length > 20 && !line.contains(' ')) {
          // Could be the key itself
          return line;
        }
      }
    } catch (e) {
      debugPrint('Error extracting API key: $e');
    }
    return null;
  }

  // ==================== STATIC MAP URL ====================

  /// Generate static map image URL using MapMyIndia Static Image API
  /// Returns empty string if API key is not available
  static String generateStaticMapUrl({
    required double centerLat,
    required double centerLng,
    int zoomLevel = 14,
    int width = 600,
    int height = 300,
    List<MapMarkerModel>? markers,
    String? apiKey,
  }) {
    final effectiveApiKey = apiKey ?? _instance._restApiKey;
    
    if (effectiveApiKey == null || effectiveApiKey.isEmpty) {
      debugPrint('MapMyIndia: API key not available, cannot generate map URL');
      return '';
    }

    try {
      const String baseUrl = 'https://apis.mapmyindia.com/advancedmaps/v1';

      final buffer = StringBuffer('$baseUrl/$effectiveApiKey/staticimage?');
      buffer.write(
          'center=${centerLng.toStringAsFixed(6)},${centerLat.toStringAsFixed(6)}');
      buffer.write('&zoom=$zoomLevel');
      buffer.write('&size=${width}x$height');

      // Add markers if provided (MapMyIndia format: lng,lat)
      if (markers != null && markers.isNotEmpty) {
        final markerParts = markers
            .map((m) =>
                '${m.longitude.toStringAsFixed(6)},${m.latitude.toStringAsFixed(6)}')
            .toList();
        final markerParam = markerParts.join(';');
        buffer.write('&markers=$markerParam');
      }

      return buffer.toString();
    } catch (e) {
      debugPrint('Error generating map URL: $e');
      return '';
    }
  }

  /// Instance method for generating static map URL
  String generateStaticMapUrlInstance({
    required double centerLat,
    required double centerLng,
    int zoomLevel = 14,
    int width = 600,
    int height = 300,
    List<MapMarkerModel>? markers,
  }) {
    return generateStaticMapUrl(
      centerLat: centerLat,
      centerLng: centerLng,
      zoomLevel: zoomLevel,
      width: width,
      height: height,
      markers: markers,
      apiKey: _restApiKey,
    );
  }

  /// Generate a preview URL for a location (simpler version)
  static String generatePreviewUrl({
    required double centerLat,
    required double centerLng,
    int zoomLevel = 14,
    int width = 600,
    int height = 300,
    String? apiKey,
  }) {
    return generateStaticMapUrl(
      centerLat: centerLat,
      centerLng: centerLng,
      zoomLevel: zoomLevel,
      width: width,
      height: height,
      apiKey: apiKey,
    );
  }

  /// Instance method for generating preview URL
  String generatePreviewUrlInstance({
    required double centerLat,
    required double centerLng,
    int zoomLevel = 14,
    int width = 600,
    int height = 300,
  }) {
    return generatePreviewUrl(
      centerLat: centerLat,
      centerLng: centerLng,
      zoomLevel: zoomLevel,
      width: width,
      height: height,
      apiKey: _restApiKey,
    );
  }

  // ==================== UTILITY METHODS ====================

  /// Calculate distance between two coordinates in kilometers using Haversine formula
  static double calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// Simple clustering based on proximity
  static List<MapCluster> clusterMarkers(
    List<MapMarkerModel> markers, {
    double clusterRadiusKm = 1.0,
  }) {
    if (markers.isEmpty) return [];

    final clusters = <MapCluster>[];
    final processed = <String>{};

    for (final marker in markers) {
      if (processed.contains(marker.id)) continue;

      final clusterMarkers = [marker];

      // Find nearby markers
      for (final other in markers) {
        if (other.id == marker.id || processed.contains(other.id)) continue;

        final distance = calculateDistanceKm(
          marker.latitude,
          marker.longitude,
          other.latitude,
          other.longitude,
        );

        if (distance <= clusterRadiusKm) {
          clusterMarkers.add(other);
          processed.add(other.id);
        }
      }

      // Calculate cluster center
      final avgLat = clusterMarkers.fold<double>(
            0,
            (sum, m) => sum + m.latitude,
          ) /
          clusterMarkers.length;
      final avgLng = clusterMarkers.fold<double>(
            0,
            (sum, m) => sum + m.longitude,
          ) /
          clusterMarkers.length;

      clusters.add(
        MapCluster(
          latitude: avgLat,
          longitude: avgLng,
          markerCount: clusterMarkers.length,
          markers: clusterMarkers,
        ),
      );

      processed.add(marker.id);
    }

    return clusters;
  }

  /// Get address from coordinates using geocoding
  /// This is a placeholder - implement with your preferred geocoding service
  static Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    // You can implement this using:
    // 1. MapMyIndia Geocoding API
    // 2. Google Geocoding API
    // 3. OpenStreetMap Nominatim
    // For now, return coordinates as string
    return 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}';
  }

  /// Get coordinates from address using geocoding
  static Future<Map<String, double>?> getCoordinatesFromAddress(
    String address,
  ) async {
    // Implement with your preferred geocoding service
    return null;
  }
}
