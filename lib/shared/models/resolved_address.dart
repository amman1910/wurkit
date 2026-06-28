class ResolvedAddress {
  const ResolvedAddress({
    required this.formattedAddress,
    required this.placeId,
    required this.latitude,
    required this.longitude,
    this.city,
    this.country,
  });

  final String formattedAddress;
  final String placeId;
  final double latitude;
  final double longitude;
  final String? city;
  final String? country;
}
