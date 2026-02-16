import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {

  /// Returns city name using REAL GPS
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

    String? city = place.locality ?? place.subAdministrativeArea;

    print("USER CITY => $city");

    return city;
  }
}