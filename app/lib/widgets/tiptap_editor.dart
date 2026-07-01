// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class TipTapController {
  html.IFrameElement? _frame;
  String _html = '';
  void Function(String html)? onChanged;
  void Function()? onReady;

  void _post(Map<String, dynamic> msg) {
    _frame?.contentWindow?.postMessage(jsonEncode(msg), '*');
  }

  void setContent(String htmlContent) {
    _html = htmlContent;
    _post({'type': 'setContent', 'data': htmlContent});
  }

  void insertImage(String src) => _post({'type': 'insertImage', 'data': src});
  void setEditable(bool v) => _post({'type': 'setEditable', 'data': v});
  void bold()       => _post({'type': 'command', 'cmd': 'bold'});
  void italic()     => _post({'type': 'command', 'cmd': 'italic'});
  void heading()    => _post({'type': 'command', 'cmd': 'heading'});
  void bulletList() => _post({'type': 'command', 'cmd': 'bulletList'});

  void applyTheme({
    required String accent,
    required String ink,
    required String muted,
    required double fontSize,
  }) =>
      _post({
        'type': 'applyTheme',
        'data': {
          'accent': accent,
          'ink': ink,
          'muted': muted,
          'fontSize': fontSize,
          'font': 'Lora, Georgia, serif',
          'lineHeight': '1.9',
        },
      });

  String get currentHtml => _html;
}

class TipTapEditor extends StatefulWidget {
  final TipTapController controller;
  final String initialHtml;
  final bool editable;
  final double minHeight;

  const TipTapEditor({
    super.key,
    required this.controller,
    this.initialHtml = '',
    this.editable = true,
    this.minHeight = 300,
  });

  @override
  State<TipTapEditor> createState() => _TipTapEditorState();
}

class _TipTapEditorState extends State<TipTapEditor> {
  late final html.IFrameElement _frame;
  late final String _viewId;
  late final html.EventListener _msgListener;
  double _height = 300;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _viewId = 'tiptap-${identityHashCode(this)}';

    _frame = html.IFrameElement()
      ..src = '/tiptap_editor.html'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none'
      ..style.background = 'transparent'
      ..setAttribute('scrolling', 'no')
      ..setAttribute('allow', 'clipboard-read; clipboard-write');

    widget.controller._frame = _frame;

    _msgListener = (html.Event rawEvent) {
      final e = rawEvent as html.MessageEvent;
      final raw = e.data;
      if (raw == null) return;
      try {
        final msg = (raw is String) ? jsonDecode(raw) : raw;
        if (msg is! Map) return;
        final type = msg['type'] as String?;
        switch (type) {
          case 'ready':
            if (!_ready) {
              _ready = true;
              widget.controller.setContent(widget.initialHtml);
              widget.controller.setEditable(widget.editable);
              widget.controller.onReady?.call();
            }
          case 'contentChanged':
            widget.controller._html = msg['html'] as String? ?? '';
            widget.controller.onChanged?.call(widget.controller._html);
          case 'heightChanged':
            final h = (msg['height'] as num?)?.toDouble() ?? _height;
            if (mounted && (h - _height).abs() > 4) {
              setState(() => _height = h.clamp(widget.minHeight, 8000));
            }
        }
      } catch (_) {}
    };

    html.window.addEventListener('message', _msgListener);

    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int id) => _frame,
    );
  }

  @override
  void didUpdateWidget(TipTapEditor old) {
    super.didUpdateWidget(old);
    if (old.editable != widget.editable && _ready) {
      widget.controller.setEditable(widget.editable);
    }
  }

  @override
  void dispose() {
    html.window.removeEventListener('message', _msgListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height.clamp(widget.minHeight, double.infinity),
      child: HtmlElementView(viewType: _viewId),
    );
  }
}

// ── Body format helpers ───────────────────────────────────────────────────────

/// Converts any legacy body format (plain text or JSON blocks) to HTML
/// suitable for TipTap. Pure HTML bodies are returned unchanged.
String bodyToTipTapHtml(String body) {
  if (body.isEmpty) return '';

  // Already HTML
  if (body.trimLeft().startsWith('<')) return body;

  // JSON block format
  if (body.trimLeft().startsWith('[')) {
    try {
      final blocks = jsonDecode(body) as List;
      final buf = StringBuffer();
      for (final b in blocks) {
        if (b is! Map) continue;
        if (b['type'] == 'text') {
          final text = (b['content'] as String? ?? '').trim();
          if (text.isNotEmpty) {
            for (final line in text.split('\n')) {
              buf.write('<p>${_escHtml(line.isEmpty ? ' ' : line)}</p>');
            }
          }
        } else if (b['type'] == 'image') {
          // Pending images can't be converted here — handled at load time
        }
      }
      return buf.toString();
    } catch (_) {}
  }

  // Plain text — wrap each line in a paragraph
  final lines = body.split('\n');
  return lines
      .map((l) => '<p>${_escHtml(l.isEmpty ? ' ' : l)}</p>')
      .join();
}

String _escHtml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
