import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';

class VoiceMemoPlayer extends StatefulWidget {
  final String dataUrl;
  final int durationMs;
  final dynamic theme;
  final VoidCallback onDelete;

  const VoiceMemoPlayer({
    super.key,
    required this.dataUrl,
    required this.durationMs,
    required this.theme,
    required this.onDelete,
  });

  @override
  State<VoiceMemoPlayer> createState() => _VoiceMemoPlayerState();
}

class _VoiceMemoPlayerState extends State<VoiceMemoPlayer> {
  html.AudioElement? _audio;
  bool _playing = false;
  Duration _position = Duration.zero;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _audio?.pause();
    super.dispose();
  }

  void _toggle() {
    _audio ??= html.AudioElement()..src = widget.dataUrl;
    if (_playing) {
      _audio!.pause();
      _timer?.cancel();
      setState(() => _playing = false);
    } else {
      _audio!.play();
      _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) return;
        final t = _audio!.currentTime;
        setState(() => _position = Duration(milliseconds: (t * 1000).round()));
        if (_audio!.ended) {
          _timer?.cancel();
          setState(() {
            _playing = false;
            _position = Duration.zero;
          });
        }
      });
      setState(() => _playing = true);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final total = Duration(milliseconds: widget.durationMs);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.border, width: 0.6),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
              child: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total.inMilliseconds > 0
                    ? (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
                    : 0,
                backgroundColor: t.border,
                color: t.accent,
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(_fmt(_playing ? _position : total),
              style: TextStyle(color: t.muted, fontSize: 12)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onDelete,
            child: Icon(Icons.delete_outline_rounded,
                size: 18, color: Colors.redAccent.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}
