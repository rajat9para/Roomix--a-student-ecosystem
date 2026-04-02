import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:roomix/constants/app_colors.dart';

/// Maps Navigation Service for Roomix
/// Handles Google Maps directions, location opening, and map-related functionality
class MapsNavigationService {
  static final MapsNavigationService _instance = MapsNavigationService._internal();
  factory MapsNavigationService() => _instance;
  MapsNavigationService._internal();

  /// Google Maps app scheme
  static const String _googleMapsScheme = 'google.navigation:';
  
  /// Google Maps web URL
  static const String _googleMapsWebUrl = 'https://www.google.com/maps';
  
  /// Google Maps Play Store URL
  static const String _googleMapsPlayStore = 'https://play.google.com/store/apps/details?id=com.google.android.apps.maps';
  
  /// Google Maps App Store URL
  static const String _googleMapsAppStore = 'https://apps.apple.com/app/google-maps/id585027354';

  /// Current position cache
  static Position? _currentPosition;

  /// Get current device location
  static Future<Position?> getCurrentPosition() async {
    try {
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('MapsNavigationService: Location service is disabled');
        return null;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('MapsNavigationService: Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('MapsNavigationService: Location permission permanently denied');
        return null;
      }

      // Get current position
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      
      return _currentPosition;
    } catch (e) {
      debugPrint('MapsNavigationService: Error getting current position: $e');
      return _currentPosition; // Return cached position if available
    }
  }

  /// Open Google Maps with directions to a destination
  /// Uses current location as starting point if available
  static Future<bool> openDirectionsWithCurrentLocation({
    required BuildContext context,
    required double destinationLat,
    required double destinationLng,
    String? destinationName,
  }) async {
    debugPrint('MapsNavigationService: Opening directions to ($destinationLat, $destinationLng)');

    // Get current position
    final currentPos = await getCurrentPosition();
    
    if (currentPos != null) {
      return openDirections(
        context: context,
        originLat: currentPos.latitude,
        originLng: currentPos.longitude,
        destinationLat: destinationLat,
        destinationLng: destinationLng,
        destinationName: destinationName,
      );
    } else {
      // Open without origin (user's current location will be used by Maps)
      return openLocation(
        context: context,
        latitude: destinationLat,
        longitude: destinationLng,
        label: destinationName,
        showDirections: true,
      );
    }
  }

  /// Open Google Maps with directions from origin to destination
  static Future<bool> openDirections({
    required BuildContext context,
    double? originLat,
    double? originLng,
    required double destinationLat,
    required double destinationLng,
    String? originName,
    String? destinationName,
  }) async {
    try {
      // Build Google Maps URL with directions
      // Format: https://www.google.com/maps/dir/?api=1&origin=lat,lng&destination=lat,lng
      final buffer = StringBuffer('$_googleMapsWebUrl/dir/?api=1');
      
      // Add origin if available
      if (originLat != null && originLng != null) {
        buffer.write('&origin=${originLat.toStringAsFixed(6)},${originLng.toStringAsFixed(6)}');
        if (originName != null) {
          buffer.write('&origin_place_id=${Uri.encodeComponent(originName)}');
        }
      }
      
      // Add destination
      buffer.write('&destination=${destinationLat.toStringAsFixed(6)},${destinationLng.toStringAsFixed(6)}');
      if (destinationName != null) {
        buffer.write('&destination_place_id=${Uri.encodeComponent(destinationName)}');
      }
      
      // Set travel mode to driving
      buffer.write('&travelmode=driving');

      final uri = Uri.parse(buffer.toString());
      debugPrint('MapsNavigationService: Opening URL: $uri');

      // Try to launch Google Maps app first
      final appLaunched = await _tryLaunchGoogleMapsApp(
        destinationLat: destinationLat,
        destinationLng: destinationLng,
      );

      if (appLaunched) return true;

      // Fallback to web version
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        _showInstallPromptDialog(context, destinationName: destinationName);
      }

      return launched;
    } catch (e) {
      debugPrint('MapsNavigationService: Error opening directions: $e');
      return false;
    }
  }

  /// Open Google Maps at a specific location
  static Future<bool> openLocation({
    required BuildContext context,
    required double latitude,
    required double longitude,
    String? label,
    bool showDirections = false,
  }) async {
    try {
      // Build Google Maps URL
      // Format: https://www.google.com/maps/search/?api=1&query=lat,lng
      final buffer = StringBuffer('$_googleMapsWebUrl/');
      
      if (showDirections) {
        buffer.write('dir/?api=1&destination=${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}');
      } else {
        buffer.write('search/?api=1&query=${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}');
      }
      
      if (label != null) {
        buffer.write('&query_place=${Uri.encodeComponent(label)}');
      }

      final uri = Uri.parse(buffer.toString());
      debugPrint('MapsNavigationService: Opening location: $uri');

      // Try to launch Google Maps app first
      final appLaunched = await _tryLaunchGoogleMapsApp(
        destinationLat: latitude,
        destinationLng: longitude,
        label: label,
      );

      if (appLaunched) return true;

      // Fallback to web version
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        _showInstallPromptDialog(context, destinationName: label);
      }

      return launched;
    } catch (e) {
      debugPrint('MapsNavigationService: Error opening location: $e');
      return false;
    }
  }

  /// Try to launch Google Maps app directly
  static Future<bool> _tryLaunchGoogleMapsApp({
    required double destinationLat,
    required double destinationLng,
    String? label,
    double? originLat,
    double? originLng,
  }) async {
    try {
      // Try geo: URI scheme (Android)
      if (defaultTargetPlatform == TargetPlatform.android) {
        final geoUri = Uri.parse(
          'geo:$destinationLat,$destinationLng?q=$destinationLat,$destinationLng${label != null ? '(${Uri.encodeComponent(label)})' : ''}',
        );
        
        if (await canLaunchUrl(geoUri)) {
          final launched = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
          if (launched) return true;
        }
      }

      // Try comgooglemaps:// URL scheme (iOS)
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosUri = Uri.parse(
          'comgooglemaps://?daddr=$destinationLat,$destinationLng${label != null ? '&q=${Uri.encodeComponent(label)}' : ''}',
        );
        
        if (await canLaunchUrl(iosUri)) {
          final launched = await launchUrl(iosUri, mode: LaunchMode.externalApplication);
          if (launched) return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('MapsNavigationService: Could not launch Google Maps app: $e');
      return false;
    }
  }

  /// Open Google Maps install page
  static Future<bool> openGoogleMapsInstallPage() async {
    try {
      final uri = defaultTargetPlatform == TargetPlatform.iOS
          ? Uri.parse(_googleMapsAppStore)
          : Uri.parse(_googleMapsPlayStore);
      
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('MapsNavigationService: Error opening install page: $e');
      return false;
    }
  }

  /// Show dialog prompting user to install Google Maps
  static void _showInstallPromptDialog(BuildContext context, {String? destinationName}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.map_outlined,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Install Google Maps',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              destinationName != null
                  ? 'Google Maps is required to navigate to "$destinationName".'
                  : 'Google Maps is required for navigation features.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              'With Google Maps you can:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const _MapsFeatureItem(text: 'Get turn-by-turn directions'),
            const _MapsFeatureItem(text: 'See real-time traffic'),
            const _MapsFeatureItem(text: 'Find nearby places'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              openGoogleMapsInstallPage();
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Install Google Maps'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Calculate distance between two coordinates in kilometers
  static double calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  /// Format distance for display
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).toStringAsFixed(0)} m';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)} km';
    } else {
      return '${distanceKm.toStringAsFixed(0)} km';
    }
  }
}

/// Feature item widget for Google Maps install dialog
class _MapsFeatureItem extends StatelessWidget {
  final String text;
  
  const _MapsFeatureItem({required this.text});
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Get Directions Button Widget
/// A reusable button for opening Google Maps directions
class GetDirectionsButton extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String? locationName;
  final bool isOutlined;
  final double? width;
  
  const GetDirectionsButton({
    super.key,
    required this.latitude,
    required this.longitude,
    this.locationName,
    this.isOutlined = false,
    this.width,
  });
  
  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return SizedBox(
        width: width,
        child: OutlinedButton.icon(
          onPressed: () => MapsNavigationService.openDirectionsWithCurrentLocation(
            context: context,
            destinationLat: latitude,
            destinationLng: longitude,
            destinationName: locationName,
          ),
          icon: const Icon(Icons.directions_outlined, size: 18),
          label: const Text(
            'Get Directions',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      child: ElevatedButton.icon(
        onPressed: () => MapsNavigationService.openDirectionsWithCurrentLocation(
          context: context,
          destinationLat: latitude,
          destinationLng: longitude,
          destinationName: locationName,
        ),
        icon: const Icon(Icons.directions_outlined, size: 18),
        label: const Text(
          'Get Directions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}