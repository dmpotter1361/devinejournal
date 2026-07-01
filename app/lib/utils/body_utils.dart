import 'dart:convert';

String bodyToPlainText(String body) {
  if (body.isEmpty) return '';

  // HTML body (TipTap format): strip tags
  if (body.trimLeft().startsWith('<')) {
    return _stripHtml(body);
  }

  // JSON block format (legacy)
  if (body.trimLeft().startsWith('[')) {
    try {
      final blocks = jsonDecode(body) as List;
      final parts = <String>[];
      for (final b in blocks) {
        if (b is! Map) continue;
        if (b['type'] == 'text') {
          final s = (b['content'] as String? ?? '').trim();
          if (s.isNotEmpty) parts.add(s);
        } else if (b['type'] == 'image') {
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

String _stripHtml(String html) {
  // Replace block-level closers with spaces so words don't run together
  var s = html.replaceAll(RegExp(r'</p>|</div>|</li>|</h[1-6]>|<br\s*/?>'), ' ');
  // Remove remaining tags
  s = s.replaceAll(RegExp(r'<[^>]*>'), '');
  // Decode common HTML entities
  s = s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ');
  // Collapse whitespace
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}
