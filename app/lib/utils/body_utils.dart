import 'dart:convert';

String bodyToPlainText(String body) {
  if (body.isNotEmpty && body.trimLeft().startsWith('[')) {
    try {
      final blocks = jsonDecode(body) as List;
      final parts = <String>[];
      for (final b in blocks) {
        if (b is! Map) continue;
        if (b['type'] == 'text') {
          final s = (b['content'] as String? ?? '').trim();
          if (s.isNotEmpty) parts.add(s);
        } else if (b['type'] == 'image') {
          // Include side text (float mode) and caption in plain-text extraction
          final side = (b['side_text'] as String? ?? '').trim();
          if (side.isNotEmpty) parts.add(side);
          final cap = (b['caption'] as String? ?? '').trim();
          if (cap.isNotEmpty) parts.add(cap);
        }
      }
      return parts.join(' ');
    } catch (_) {}
  }
  return body;
}
