/// Converts a 2-letter ISO country code to its flag emoji.
/// Port of ProxyInfoPanel.tsx `countryFlag()`.
String countryFlag(String code) {
  if (code.length != 2) return '';
  try {
    return String.fromCharCodes(
      code.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 65),
    );
  } catch (_) {
    return '';
  }
}
