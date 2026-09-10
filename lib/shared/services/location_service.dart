import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double? lat;
  final double? lng;
  final String? error; // human-readable reason when lat/lng are null
  const LocationResult({this.lat, this.lng, this.error});
  bool get ok => lat != null && lng != null;
}

class LocationService {
  // Get the device's current position, requesting permission if needed.
  // Returns a friendly error string instead of throwing.
  static Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(error: 'Location is turned off on this device.');
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        return const LocationResult(error: 'Location permission denied.');
      }
      if (perm == LocationPermission.deniedForever) {
        return const LocationResult(error: 'Location permission blocked. Enable it in settings.');
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return LocationResult(lat: pos.latitude, lng: pos.longitude);
    } catch (e) {
      return LocationResult(error: 'Could not get location: $e');
    }
  }
}
