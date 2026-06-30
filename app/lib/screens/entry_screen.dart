import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import '../utils/moon_phase.dart';
import '../widgets/ruled_paper.dart';
import '../widgets/writing_prompt.dart';

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
  late List<String> _tags;
  bool _saving = false;
  bool _dirty  = false;
  bool _showPrompt = false;
  final _tagController = TextEditingController();

  bool get _isEdit => widget.entry != null;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.entry?['title'] ?? '');
    _body  = TextEditingController(text: widget.entry?['body'] ?? '');
    _mood  = widget.entry?['mood'] ?? '';
    final tagsRaw = widget.entry?['tags'] as String? ?? '';
    _tags = tagsRaw.isNotEmpty
        ? tagsRaw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : [];
    _showPrompt = !_isEdit;
    _title.addListener(_mark);
    _body.addListener(_mark);
  }

  void _mark() { if (!_dirty && mounted) setState(() => _dirty = true); }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag(String raw) {
    final parts = raw.split(',').map((s) => s.trim().replaceAll('#', '')).where((s) => s.isNotEmpty);
    setState(() {
      for (final tag in parts) {
        if (!_tags.contains(tag)) _tags.add(tag);
      }
      _dirty = true;
    });
    _tagController.clear();
  }

  void _removeTag(String tag) => setState(() { _tags.remove(tag); _dirty = true; });

  String get _tagsString => _tags.join(',');

  int get _wordCount {
    final t = _body.text.trim();
    return t.isEmpty ? 0 : t.split(RegExp(r'\s+')).length;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await ApiService.updateEntry(
          widget.entry!['id'] as String,
          title: _title.text, body: _body.text, mood: _mood, tags: _tagsString,
        );
      } else {
        await ApiService.createEntry(
          title: _title.text, body: _body.text, mood: _mood, tags: _tagsString,
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: t.muted))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
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
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.appBarBg,
        foregroundColor: t.appBarFg,
        title: Text(
          _isEdit ? 'Edit Entry' : 'New Entry',
          style: GoogleFonts.playfairDisplay(color: t.appBarFg, fontSize: 18, fontWeight: FontWeight.w500),
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
                    child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: t.appBarFg)),
                  )
                : IconButton(
                    icon: Icon(Icons.check_rounded, color: t.appBarFg),
                    onPressed: _save, tooltip: 'Save',
                  ),
        ],
      ),
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          // Wide (desktop/tablet): two-column panel layout
          if (constraints.maxWidth >= 700) {
            return _wideLayout(t);
          }
          // Narrow (mobile): stacked single-column layout
          return _narrowLayout(t);
        },
      ),
    );
  }

  // ── Wide layout: left panel + right paper ──────────────────────────────────

  Widget _wideLayout(dynamic t) {
    final moodColor = _mood.isNotEmpty ? (_moodColors[_mood] ?? t.accent) : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left panel
        Container(
          width: 240,
          decoration: BoxDecoration(
            color: t.card,
            border: Border(right: BorderSide(color: t.border, width: 0.7)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date + moon
                _panelSection(t, null, _dateBlock(t)),
                const SizedBox(height: 16),

                // Mood
                _panelSection(t, 'Mood', _moodGrid(t)),
                const SizedBox(height: 16),

                // Tags
                _panelSection(t, 'Tags', _tagsPanel(t)),
                const SizedBox(height: 16),

                // Writing prompt
                if (_showPrompt)
                  _panelSection(t, 'Writing prompt', _promptPanel(t)),

                // Stats
                if (_wordCount > 0) ...[
                  const SizedBox(height: 16),
                  _panelSection(t, 'Stats', _statsPanel(t, moodColor)),
                ],
              ],
            ),
          ),
        ),

        // Right: paper surface
        Expanded(
          child: Container(
            color: t.paper,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mood colour strip
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 3,
                  color: moodColor?.withValues(alpha: 0.55) ?? t.border,
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                  child: TextField(
                    controller: _title,
                    style: GoogleFonts.playfairDisplay(color: t.heading, fontSize: 26, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: 'Entry title…',
                      hintStyle: GoogleFonts.playfairDisplay(
                        color: t.muted.withValues(alpha: 0.45), fontSize: 26, fontStyle: FontStyle.italic),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Divider(color: t.border, thickness: 0.7, height: 1),
                ),
                const SizedBox(height: 4),
                // Body
                Expanded(
                  child: RuledPaper(
                    lineColor: t.lines,
                    spacing: 32,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 4, 28, 20),
                      child: TextField(
                        controller: _body,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: GoogleFonts.lora(color: t.ink, fontSize: 16, height: 2.0),
                        decoration: InputDecoration(
                          hintText: 'Write your thoughts…',
                          hintStyle: GoogleFonts.lora(
                            color: t.muted.withValues(alpha: 0.38), fontSize: 16, fontStyle: FontStyle.italic),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Narrow layout: stacked ─────────────────────────────────────────────────

  Widget _narrowLayout(dynamic t) {
    final moodColor = _mood.isNotEmpty ? (_moodColors[_mood] ?? t.accent) : null;
    return Container(
      color: t.paper,
      child: Column(
        children: [
          // Mood strip top
          Container(
            color: t.paper,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: SizedBox(
              height: 40,
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
                      duration: const Duration(milliseconds: 140),
                      width: 36, height: 36,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: sel ? mc.withValues(alpha: 0.18) : t.card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: sel ? mc : t.border, width: sel ? 1.5 : 0.6),
                      ),
                      child: Center(
                        child: m.isEmpty
                            ? Icon(Icons.mood_outlined, size: 14, color: sel ? t.accent : t.muted)
                            : Text(m, style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2,
            color: moodColor?.withValues(alpha: 0.5) ?? t.border,
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: TextField(
              controller: _title,
              style: GoogleFonts.playfairDisplay(color: t.heading, fontSize: 20, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'Entry title…',
                hintStyle: GoogleFonts.playfairDisplay(
                  color: t.muted.withValues(alpha: 0.45), fontSize: 20, fontStyle: FontStyle.italic),
                border: InputBorder.none,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Divider(color: t.border, thickness: 0.6, height: 1),
          ),
          const SizedBox(height: 4),
          // Writing prompt
          if (_showPrompt)
            WritingPromptCard(
              paperColor: t.paper,
              accentColor: t.accent,
              inkColor: t.ink,
              mutedColor: t.muted,
              onDismiss: () => setState(() => _showPrompt = false),
              onUse: (p) {
                _body.text = p;
                _dirty = true;
                setState(() => _showPrompt = false);
              },
            ),
          // Body
          Expanded(
            child: RuledPaper(
              lineColor: t.lines,
              spacing: 30,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 2, 18, 0),
                child: TextField(
                  controller: _body,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: GoogleFonts.lora(color: t.ink, fontSize: 15, height: 2.0),
                  decoration: InputDecoration(
                    hintText: 'Write your thoughts…',
                    hintStyle: GoogleFonts.lora(
                      color: t.muted.withValues(alpha: 0.38), fontSize: 15, fontStyle: FontStyle.italic),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
          // Tags bottom bar
          Container(
            color: t.paper,
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(color: t.border, height: 1, thickness: 0.5),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ..._tags.map((tag) => _tagChip(tag, t)),
                      _addTagField(t),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Panel sub-widgets ──────────────────────────────────────────────────────

  Widget _panelSection(dynamic t, String? label, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label.toUpperCase(),
            style: TextStyle(color: t.muted, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
        ],
        content,
      ],
    );
  }

  Widget _dateBlock(dynamic t) {
    final now = _isEdit
        ? (DateTime.tryParse(widget.entry?['created_at'] as String? ?? '') ?? DateTime.now())
        : DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${moonPhaseEmoji(now)}  ${moonPhaseName(now)}',
          style: TextStyle(color: t.muted, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('EEEE, MMMM d').format(now.toLocal()),
          style: GoogleFonts.playfairDisplay(color: t.heading, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        Text(
          DateFormat('yyyy').format(now.toLocal()),
          style: TextStyle(color: t.muted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _moodGrid(dynamic t) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _moods.map((m) {
        final sel = _mood == m;
        final mc = m.isNotEmpty ? (_moodColors[m] ?? t.accent) : t.muted;
        return GestureDetector(
          onTap: () => setState(() { _mood = m; _dirty = true; }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: sel ? mc.withValues(alpha: 0.18) : t.paper,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: sel ? mc : t.border, width: sel ? 1.5 : 0.6),
            ),
            child: Center(
              child: m.isEmpty
                  ? Icon(Icons.mood_outlined, size: 15, color: sel ? t.accent : t.muted)
                  : Text(m, style: const TextStyle(fontSize: 17)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _tagsPanel(dynamic t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_tags.isNotEmpty)
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: _tags.map((tag) => _tagChip(tag, t)).toList(),
          ),
        const SizedBox(height: 6),
        _addTagField(t),
      ],
    );
  }

  Widget _tagChip(String tag, dynamic t) {
    return InputChip(
      label: Text('#$tag', style: TextStyle(color: t.accent, fontSize: 11, fontWeight: FontWeight.w600)),
      onDeleted: () => _removeTag(tag),
      deleteIcon: Icon(Icons.close, size: 11, color: t.muted),
      backgroundColor: t.accent.withValues(alpha: 0.1),
      side: BorderSide(color: t.accent.withValues(alpha: 0.3), width: 0.6),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _addTagField(dynamic t) {
    return SizedBox(
      width: 110,
      height: 30,
      child: TextField(
        controller: _tagController,
        style: TextStyle(color: t.ink, fontSize: 12),
        decoration: InputDecoration(
          hintText: 'add tag',
          hintStyle: TextStyle(color: t.muted, fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          prefixText: '# ',
          prefixStyle: TextStyle(color: t.muted, fontSize: 12),
        ),
        onSubmitted: _addTag,
        textInputAction: TextInputAction.done,
      ),
    );
  }

  Widget _promptPanel(dynamic t) {
    return WritingPromptCard(
      paperColor: t.card,
      accentColor: t.accent,
      inkColor: t.ink,
      mutedColor: t.muted,
      onDismiss: () => setState(() => _showPrompt = false),
      onUse: (p) {
        _body.text = p;
        _dirty = true;
        setState(() => _showPrompt = false);
      },
    );
  }

  Widget _statsPanel(dynamic t, Color? moodColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statRow(t, 'Words', '$_wordCount'),
        const SizedBox(height: 4),
        if (_mood.isNotEmpty)
          _statRow(t, 'Mood', _mood),
      ],
    );
  }

  Widget _statRow(dynamic t, String label, String value) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: t.muted, fontSize: 11)),
        const Spacer(),
        Text(value, style: TextStyle(color: t.heading, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
