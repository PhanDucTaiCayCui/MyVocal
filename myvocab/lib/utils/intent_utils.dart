class IntentUtils {
  /// Normalizes incoming shared text by trimming and stripping punctuation/symbols
  /// at both ends (e.g. '"ubiquitous,"' -> 'ubiquitous').
  static String cleanSharedText(String text) {
    var cleaned = text.trim();
    // Strip leading punctuation/symbols/quotes
    cleaned = cleaned.replaceFirst(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '');
    // Strip trailing punctuation/symbols/quotes
    cleaned = cleaned.replaceFirst(RegExp(r'[^\p{L}\p{N}]+$', unicode: true), '');
    return cleaned.trim();
  }
}
