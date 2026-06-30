import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import '../widgets/ruled_paper.dart';

const _moods = ['', '✨', '🌙', '🌸', '🔥', '💫', '🌿', '🖤', '💜', '🌊', '⚡', '🌻'];

const _moodColors = {
  '✨': Color(0xFFf8df6e),
  '🌙': Color(0xFF9b72cf),
  '🌸': Color(0xFFf48fb1),
  '🔥': Color(0xFFff7043),
  '💫': Color(0xFF81d4fa),
  '🌿': Color(0xFF81c784),
  '🖤': Color(0xFF90a4ae),
  '💜': Color(0xFFce93d8),
  '🌊': Color(0xFF4dd0e1),
  '⚡': Color(0xFFffee58),
  '🌻': Color(0xFFffd54f),
};

class EntryScreen extends StatefulWidget {
  final Map<String, dynamic>? entry;
  const EntryScreen({super.key, this.entry});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late String _mood;
  bool _saving = false;
  bool _dirty  = false;

  bool get _isEdit => widget.entry != null;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.entry?['title'] ?? '');
    _body  = TextEditingController(text: widget.entry?['body'] ?? '');
    _mood  = widget.entry?['mood'] ?? '';
    _title.addListener(_mark);
    _body.addListener(_mark);
  }

  void _mark() { if (!_dirty && mounted) setState(() => _dirty = true); }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await ApiService.updateEntry(
          widget.entry!['id'] as String,
          title: _title.text,
          body: _body.text,
          mood: _mood,
        );
      } else {
        await ApiService.createEntry(
          title: _title.text,
          body: _body.text,
          mood: _mood,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final t = ThemeService.current;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.paper,
        title: Text('Delete entry?', style: TextStyle(color: t.heading)),
        content: Text('This cannot be undone.', style: TextStyle(color: t.ink)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: t.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deleteEntry(widget.entry!['id'] as String);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeService.current;
    final moodColor = _mood.isNotEmpty ? (_moodColors[_mood] ?? t.accent) : t.accent;

    return Scaffold(
      backgroundColor: t.paper,
      appBar: AppBar(
        backgroundColor: t.appBarBg,
        foregroundColor: t.appBarFg,
        title: Text(
          _isEdit ? 'Edit Entry' : 'New Entry',
          style: GoogleFonts.playfairDisplay(
            color: t.appBarFg,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _delete,
            ),
          if (_dirty || !_isEdit)
            _saving
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: t.appBarFg),
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.check_rounded, color: t.appBarFg),
                    onPressed: _save,
                    tooltip: 'Save',
                  ),
        ],
      ),
      body: Container(
        color: t.paper,
        child: Column(
          children: [
            // ── Mood picker ────────────────────────────────────────────────
            Container(
              color: t.paper,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _moods.length,
                  itemBuilder: (_, i) {
                    final m = _moods[i];
                    final sel = _mood == m;
                    final mc = m.isNotEmpty ? (_moodColors[m] ?? t.accent) : t.muted;
                    return GestureDetector(
                      onTap: () => setState(() { _mood = m; _dirty = true; }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: sel ? mc.withValues(alpha: 0.18) : t.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: sel ? mc : t.border,
                            width: sel ? 1.5 : 0.6,
                          ),
                        ),
                        child: Center(
                          child: m.isEmpty
                              ? Icon(Icons.mood_outlined, size: 16, color: sel ? t.accent : t.muted)
                              : Text(m, style: const TextStyle(fontSize: 18)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── Thin mood-colour bar ───────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              color: _mood.isNotEmpty ? moodColor.withValues(alpha: 0.55) : t.border,
            ),

            // ── Title ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: TextField(
                controller: _title,
                style: GoogleFonts.playfairDisplay(
                  color: t.heading,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: 'Entry title…',
                  hintStyle: GoogleFonts.playfairDisplay(
                    color: t.muted.withValues(alpha: 0.5),
                    fontSize: 22,
                    fontStyle: FontStyle.italic,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),

            // ── Divider ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: t.border, thickness: 0.7, height: 1),
            ),

            const SizedBox(height: 4),

            // ── Body on ruled paper ────────────────────────────────────────
            Expanded(
              child: RuledPaper(
                lineColor: t.lines,
                spacing: 30,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: TextField(
                    controller: _body,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: GoogleFonts.lora(
                      color: t.ink,
                      fontSize: 15,
                      height: 2.0,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Write your thoughts…',
                      hintStyle: GoogleFonts.lora(
                        color: t.muted.withValues(alpha: 0.4),
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
