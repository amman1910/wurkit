String formatAddressForDisplay(String address) {
  return address
      .trim()
      .replaceFirst(
        RegExp(r',\s*(?:Israel|ישראל)\s*$', caseSensitive: false),
        '',
      )
      .trim();
}
