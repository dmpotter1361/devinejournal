import 'dart:convert';

/// Extracts readable plain text from an entry body that may be either
/// legacy plain text or a block-editor JSON array.
String bodyToPlainText(String body) {
  if (body.isNotEmpty && body.trimLeft().startsWith('[')) {
    try {
      final blocks = jsonDecode(body) as List;
      return blocks
          .where((b) => b is Map && b['type'] == 'text')
          .map((b) => (b['content'] as String? ?? '').trim())
          .where((s) => s.isNotEmpty)
          .join(' ');
    } catch (_) {}
  }
  return body;
}
