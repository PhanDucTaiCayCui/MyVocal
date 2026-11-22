class TagUtils {
  /// Normalizes tags input like "ielts, food, daily" to ",ielts,food,daily,"
  static String? normalize(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    final tags = input
        .split(',')
        .map((t) => t.trim().replaceAll('#', '').toLowerCase())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
    if (tags.isEmpty) return null;
    return ',${tags.join(',')},';
  }

  /// Converts normalized tags ",ielts,food," to "ielts, food" for text field
  static String formatForDisplay(String? tags) {
    if (tags == null || tags.trim().isEmpty) return '';
    return tags
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .join(', ');
  }

  /// Converts normalized tags ",ielts,food," to list ['ielts', 'food']
  static List<String> toList(String? tags) {
    if (tags == null || tags.trim().isEmpty) return [];
    return tags
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }
}
