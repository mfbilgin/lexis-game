/// Turkish-aware uppercase conversion.
/// Dart's `String.toUpperCase()` uses Unicode default rules where i → I.
/// In Turkish: i → İ, ı → I. This function handles it correctly.
String turkishUpperCase(String input) {
  final buffer = StringBuffer();
  for (final char in input.characters) {
    switch (char) {
      case 'i':
        buffer.write('İ');
        break;
      case 'ı':
        buffer.write('I');
        break;
      default:
        buffer.write(char.toUpperCase());
    }
  }
  return buffer.toString();
}

/// Turkish-aware character iteration via characters package
extension on String {
  Iterable<String> get characters => runes.map((r) => String.fromCharCode(r));
}
