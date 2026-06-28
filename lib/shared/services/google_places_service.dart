import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/google_maps_config.dart';
import '../models/address_suggestion.dart';
import '../models/resolved_address.dart';

class GooglePlacesException implements Exception {
  const GooglePlacesException(this.message);
  final String message;
  @override
  String toString() => message;
}

class GooglePlacesService {
  GooglePlacesService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  static const _baseUrl = 'https://places.googleapis.com/v1';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'X-Goog-Api-Key': GoogleMapsConfig.apiKey,
  };

  void _requireKey() {
    if (!GoogleMapsConfig.isConfigured) {
      throw const GooglePlacesException(
        'Google Maps is not configured. Start the app with GOOGLE_MAPS_API_KEY.',
      );
    }
  }

  Future<List<AddressSuggestion>> fetchAddressSuggestions(String input) async {
    final query = input.trim();
    if (query.isEmpty) return const [];
    _requireKey();

    final response = await _client.post(
      Uri.parse('$_baseUrl/places:autocomplete'),
      headers: _headers,
      body: jsonEncode({
        'input': query,
        'includedRegionCodes': ['il'],
        'languageCode': 'en',
        'regionCode': 'IL',
        'includeQueryPredictions': false,
      }),
    );
    if (response.statusCode != 200) {
      throw GooglePlacesException(_apiError(response));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final suggestions = body['suggestions'];
    if (suggestions is! List) return const [];
    return suggestions
        .map((raw) {
          final prediction = (raw as Map<String, dynamic>)['placePrediction'];
          if (prediction is! Map<String, dynamic>) return null;
          final text = prediction['text'] as Map<String, dynamic>? ?? const {};
          final structured =
              prediction['structuredFormat'] as Map<String, dynamic>? ??
              const {};
          final main =
              structured['mainText'] as Map<String, dynamic>? ?? const {};
          final secondary =
              structured['secondaryText'] as Map<String, dynamic>? ?? const {};
          final placeId = prediction['placeId']?.toString() ?? '';
          final description = text['text']?.toString() ?? '';
          if (placeId.isEmpty || description.isEmpty) return null;
          return AddressSuggestion(
            description: description,
            placeId: placeId,
            mainText: main['text']?.toString() ?? description,
            secondaryText: secondary['text']?.toString() ?? '',
          );
        })
        .whereType<AddressSuggestion>()
        .toList();
  }

  Future<ResolvedAddress> fetchPlaceDetails(String placeId) async {
    _requireKey();
    final response = await _client.get(
      Uri.parse('$_baseUrl/places/${Uri.encodeComponent(placeId)}'),
      headers: {
        ..._headers,
        'X-Goog-FieldMask': 'id,formattedAddress,location,addressComponents',
      },
    );
    if (response.statusCode != 200) {
      throw GooglePlacesException(_apiError(response));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final location = body['location'] as Map<String, dynamic>?;
    final lat = (location?['latitude'] as num?)?.toDouble();
    final lng = (location?['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      throw const GooglePlacesException('This address has no coordinates.');
    }

    String? city;
    String? country;
    final components = body['addressComponents'];
    if (components is List) {
      for (final raw in components.whereType<Map<String, dynamic>>()) {
        final types =
            (raw['types'] as List?)?.whereType<String>().toSet() ?? {};
        final value = raw['longText']?.toString();
        if (city == null &&
            (types.contains('locality') ||
                types.contains('administrative_area_level_2'))) {
          city = value;
        }
        if (types.contains('country')) country = value;
      }
    }
    return ResolvedAddress(
      formattedAddress: body['formattedAddress']?.toString() ?? '',
      placeId: body['id']?.toString() ?? placeId,
      latitude: lat,
      longitude: lng,
      city: city,
      country: country,
    );
  }

  String _apiError(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final error = body['error'] as Map<String, dynamic>?;
      return error?['message']?.toString() ?? 'Address lookup failed.';
    } catch (_) {
      return 'Address lookup failed. Please try again.';
    }
  }
}
