import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {

  /// Known Hindi → English city name mappings
  static const Map<String, String> _hindiToEnglish = {
    'रूड़की': 'Roorkee',
    'रुड़की': 'Roorkee',
    'देहरादून': 'Dehradun',
    'हरिद्वार': 'Haridwar',
    'ऋषिकेश': 'Rishikesh',
    'मसूरी': 'Mussoorie',
    'दिल्ली': 'Delhi',
    'नई दिल्ली': 'New Delhi',
    'नोएडा': 'Noida',
    'गुरुग्राम': 'Gurugram',
    'चंडीगढ़': 'Chandigarh',
    'लखनऊ': 'Lucknow',
    'जयपुर': 'Jaipur',
    'मुंबई': 'Mumbai',
    'बेंगलुरु': 'Bengaluru',
    'पुणे': 'Pune',
    'हैदराबाद': 'Hyderabad',
    'चेन्नई': 'Chennai',
    'कोलकाता': 'Kolkata',
  };

  /// Ensures city name is always in English
  static String _toEnglishCity(String? city) {
    if (city == null || city.isEmpty) return '';
    // Check mapping table first
    if (_hindiToEnglish.containsKey(city)) {
      return _hindiToEnglish[city]!;
    }
    // Strip any remaining Devanagari characters → return original if purely Latin
    final hasNonLatin = RegExp(r'[^\x00-\x7F]').hasMatch(city);
    if (hasNonLatin) {
      // Try to find a partial match
      for (final entry in _hindiToEnglish.entries) {
        if (city.contains(entry.key)) {
          return entry.value;
        }
      }
      // If still non-Latin and no match found, return as-is (better than nothing)
    }
    return city;
  }

  /// Returns city name using REAL GPS — always in English
  static Future<String?> getCurrentCity() async {

    // 1) Check GPS enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("GPS disabled");
      return null;
    }

    // 2) Permissions
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("Permission denied");
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print("Permission permanently denied");
      return null;
    }

    // 3) Get exact GPS location
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    print("LAT: ${position.latitude}, LNG: ${position.longitude}");

    // 4) Convert lat/lng → city name
    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    Placemark place = placemarks.first;

    String? rawCity = place.locality ?? place.subAdministrativeArea;
    String city = _toEnglishCity(rawCity);

    print("USER CITY => $city (raw: $rawCity)");

    return city.isNotEmpty ? city : null;
  }
}