class GoogleMapsConfig {
  GoogleMapsConfig._();

  // Supply at build/run time with:
  // flutter run --dart-define=GOOGLE_MAPS_API_KEY=your_key
  // Never commit a real key to source control.
  static const apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static bool get isConfigured => apiKey.trim().isNotEmpty;
}
