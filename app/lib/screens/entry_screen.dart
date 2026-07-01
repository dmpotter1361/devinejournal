// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import '../theme.dart';
import '../utils/body_utils.dart';
import '../utils/moon_phase.dart';
import '../utils/entry_templates.dart';
import '../utils/web_audio_recorder.dart';
import '../widgets/ruled_paper.dart';
import '../widgets/tiptap_editor.dart';
import '../widgets/writing_prompt.dart';
import '../widgets/voice_memo_player.dart';

const _moods = [
  '', '✨', '🌙', '🌸', '🔥', '💫', '🌿', '🖤', '💜',
  '🌊', '⚡', '🌻', '🦋', '🌹', '💝', '🌺', '🌼', '🌠',
];

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
  '🦋': Color(0xFF80deea),
  '🌹': Color(0xFFef9a9a),
  '💝': Color(0xFFff80ab),
  '🌺': Color(0xFFffab40),
  '🌼': Color(0xFFfff176),
  '🌠': Color(0xFF7986cb),
};

class EntryScreen extends StatefulWidget {
  final Map<String, dynamic>? entry;
  final EntryTemplate? template;
  const EntryScreen({super.key, this.entry, this.template});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  late final TextEditingController _title;
  late String _mood;
  late List<String> _tags;
  DateTime? _lockedUntil;
  String _paperStyle = 'lined';
  bool _isFavorite = false;
  bool _saving = false;
  bool _dirty = false;
  bool _showPrompt = false;
  bool _previewMode = false;
  final _tagController = TextEditingController();
  String? _themeId;
  String? _entryId;

  // TipTap rich-text editor
  final _tiptapCtrl = TipTapController();
  bool _tiptapReady = false;
  String _pendingHtml = '';
  List<String> _pendingPhotoIds = [];
  bool _uploading = false;

  // Voice memos
  List<Map<String, dynamic>> _voiceMemos = [];
  final _recorder = WebAudioRecorder();
  bool _recording = false;
  bool _memoUploading = false;
  Duration _recordElapsed = Duration.zero;
  Timer? _recordTimer;

  bool get _isEdit => _entryId != null;

  PaperTheme get _t =>
      (_themeId != null && _themeId!.isNotEmpty)
          ? paperThemeById(_themeId!)
          : ThemeService.current;

  int get _wordCount {
    final text = bodyToPlainText(_tiptapCtrl.currentHtml);
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  int get _imageCount =>
      RegExp(r'<img').allMatches(_tiptapCtrl.currentHtml).length;

  @override
  void initState() {
    super.initState();
    _entryId = widget.entry?['id'] as String?;
    final tpl = widget.entry == null ? widget.template : null;
    _title = TextEditingController(text: widget.entry?['title'] ?? tpl?.title ?? '');
    _mood = widget.entry?['mood'] ?? tpl?.mood ?? '';
    final tagsRaw = widget.entry?['tags'] as String? ?? '';
    _tags = tagsRaw.isNotEmpty
        ? tagsRaw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : [];
    final lu = widget.entry?['locked_until'] as String?;
    if (lu != null && lu.isNotEmpty) _lockedUntil = DateTime.tryParse(lu);
    _paperStyle = widget.entry?['paper_style'] as String? ?? 'lined';
    _isFavorite = widget.entry?['is_favorite'] as bool? ?? false;
    _themeId = widget.entry?['theme_id'] as String?;
    _showPrompt = _entryId == null && tpl == null;
    _previewMode = _isEdit;

    _initContent(widget.entry?['body'] as String? ?? tpl?.body ?? '');

    _tiptapCtrl.onChanged = (_) => _mark();
    _tiptapCtrl.onReady = () {
      if (!mounted) return;
      setState(() => _tiptapReady = true);
      _tiptapCtrl.setContent(_pendingHtml);
      _tiptapCtrl.setEditable(!_previewMode);
      _applyTipTapTheme();
    };

    _title.addListener(_mark);

    if (_entryId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadPhotos();
        _loadVoiceMemos();
      });
    }
  }

  void _initContent(String rawBody) {
    _pendingPhotoIds = [];
    _pendingHtml = bodyToTipTapHtml(rawBody);
    // Extract photo IDs from legacy JSON block format so _loadPhotos can inject them
    if (rawBody.trimLeft().startsWith('[')) {
      try {
        for (final b in jsonDecode(rawBody) as List) {
          if (b is Map && b['type'] == 'image') {
            _pendingPhotoIds.add(b['photo_id'] as String? ?? '');
          }
        }
      } catch (_) {}
    }
  }

  void _applyTipTapTheme([PaperTheme? theme]) {
    final t = theme ?? _t;
    _tiptapCtrl.applyTheme(
      accent: _colorToHex(t.accent),
      ink: _colorToHex(t.ink),
      muted: _colorToHex(t.muted),
      fontSize: 20,
    );
  }

  String _colorToHex(Color c) {
    final r = (c.r * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  String _serializeBody() => _tiptapCtrl.currentHtml;

  void _mark() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _title.dispose();
    _tagController.dispose();
    _recordTimer?.cancel();
    if (_recording) _recorder.cancel();
    super.dispose();
  }

  // ── Tag helpers ───────────────────────────────────────────────────────────

  void _addTag(String raw) {
    final parts = raw
        .split(',')
        .map((s) => s.trim().replaceAll('#', ''))
        .where((s) => s.isNotEmpty);
    setState(() {
      for (final tag in parts) {
        if (!_tags.contains(tag)) _tags.add(tag);
      }
      _dirty = true;
    });
    _tagController.clear();
  }

  void _removeTag(String tag) =>
      setState(() { _tags.remove(tag); _dirty = true; });

  String get _tagsString => _tags.join(',');

  PaperStyle _toPaperStyle() => switch (_paperStyle) {
        'dotted' => PaperStyle.dotted,
        'grid' => PaperStyle.grid,
        'plain' => PaperStyle.plain,
        _ => PaperStyle.lined,
      };

  // ── Photo helpers ─────────────────────────────────────────────────────────

  Future<void> _loadPhotos() async {
    if (_entryId == null) return;
    try {
      final photos = await ApiService.getPhotos(_entryId!);
      if (!mounted || photos.isEmpty) return;

      final photoMap = {for (final p in photos) p['id'] as String: p['data'] as String};
      var html = _pendingHtml;

      // Inject photos from legacy block JSON in order
      final referenced = <String>{};
      for (final id in _pendingPhotoIds) {
        final data = photoMap[id];
        if (data != null) {
          referenced.add(id);
          html += '<img src="$data" />';
        }
      }
      // Append photos not referenced in body JSON (backward compat)
      for (final p in photos) {
        if (!referenced.contains(p['id'] as String)) {
          html += '<img src="${p['data'] as String}" />';
        }
      }

      setState(() => _pendingHtml = html);
      if (_tiptapReady) _tiptapCtrl.setContent(html);
    } catch (_) {}
  }

  Future<bool> _ensureSaved() async {
    if (_entryId != null) return true;
    try {
      final created = await ApiService.createEntry(
        title: _title.text,
        body: _serializeBody(),
        mood: _mood,
        tags: _tagsString,
        lockedUntil: _lockedUntil?.toUtc().toIso8601String(),
        paperStyle: _paperStyle,
        isFavorite: _isFavorite,
        themeId: _themeId ?? '',
      );
      if (mounted) {
        setState(() { _entryId = created['id'] as String; _dirty = false; });
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
      return false;
    }
  }

  Future<void> _pickPhoto() async {
    if (_uploading) return;
    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..click();
    await input.onChange.first;
    if (input.files == null || input.files!.isEmpty) return;

    final htmlFile = input.files!.first;
    final reader = html.FileReader();
    reader.readAsArrayBuffer(htmlFile);
    await reader.onLoadEnd.first;
    final bytes = reader.result as Uint8List;

    if (!await _ensureSaved()) return;
    if (!mounted) return;

    setState(() => _uploading = true);
    try {
      final photo = await ApiService.uploadPhoto(_entryId!, bytes, htmlFile.name);
      if (!mounted) return;
      _tiptapCtrl.insertImage(photo['data'] as String);
      setState(() => _dirty = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── Voice memo helpers ────────────────────────────────────────────────────

  Future<void> _loadVoiceMemos() async {
    if (_entryId == null) return;
    try {
      final memos = await ApiService.getVoiceMemos(_entryId!);
      if (mounted) setState(() => _voiceMemos = memos);
    } catch (_) {}
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      _recordTimer?.cancel();
      setState(() { _recording = false; _memoUploading = true; });
      try {
        final rec = await _recorder.stop();
        if (!await _ensureSaved()) {
          setState(() => _memoUploading = false);
          return;
        }
        final ext = rec.mime.contains('ogg') ? 'ogg' : 'webm';
        final memo = await ApiService.uploadVoiceMemo(
            _entryId!, rec.bytes, 'memo.$ext', rec.durationMs);
        if (mounted) setState(() => _voiceMemos.add(memo));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Recording failed: $e'), backgroundColor: Colors.redAccent),
          );
        }
      } finally {
        if (mounted) setState(() => _memoUploading = false);
      }
    } else {
      try {
        await _recorder.start();
        setState(() { _recording = true; _recordElapsed = Duration.zero; });
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          setState(() => _recordElapsed += const Duration(seconds: 1));
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Microphone unavailable: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  Future<void> _deleteVoiceMemo(String memoId, int idx) async {
    try {
      await ApiService.deleteVoiceMemo(memoId);
      if (mounted) setState(() => _voiceMemos.removeAt(idx));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // ── Save / Delete ─────────────────────────────────────────────────────────

  Future<void> _pickSealDate() async {
    final t = _t;
    final picked = await showDatePicker(
      context: context,
      initialDate: _lockedUntil ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(primary: t.accent, surface: t.paper),
          dialogTheme: DialogThemeData(backgroundColor: t.paper),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() { _lockedUntil = picked; _dirty = true; });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final body = _serializeBody();
      final luStr = _lockedUntil?.toUtc().toIso8601String();
      if (_entryId != null) {
        await ApiService.updateEntry(
          _entryId!,
          title: _title.text,
          body: body,
          mood: _mood,
          tags: _tagsString,
          lockedUntil: luStr,
          clearLock: _lockedUntil == null &&
              (widget.entry?['locked_until'] as String?)?.isNotEmpty == true,
          paperStyle: _paperStyle,
          isFavorite: _isFavorite,
          themeId: _themeId ?? '',
        );
      } else {
        final created = await ApiService.createEntry(
          title: _title.text,
          body: body,
          mood: _mood,
          tags: _tagsString,
          lockedUntil: luStr,
          paperStyle: _paperStyle,
          isFavorite: _isFavorite,
          themeId: _themeId ?? '',
        );
        _entryId = created['id'] as String;
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
    final t = _t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.paper,
        title: Text('Delete entry?', style: TextStyle(color: t.heading)),
        content: Text('This cannot be undone.', style: TextStyle(color: t.ink)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: t.muted))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deleteEntry(_entryId!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.appBarBg,
        foregroundColor: t.appBarFg,
        title: Text(
          _isEdit ? 'Journal Entry' : 'New Entry',
          style: GoogleFonts.cinzelDecorative(
              color: t.appBarFg, fontSize: 18, fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _isFavorite ? const Color(0xFFf48fb1) : t.appBarFg,
              size: 20,
            ),
            onPressed: () => setState(() { _isFavorite = !_isFavorite; _dirty = true; }),
            tooltip: _isFavorite ? 'Unfavorite' : 'Favorite',
          ),
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _delete,
            ),
          if (_previewMode && _isEdit)
            IconButton(
              icon: Icon(Icons.edit_rounded, color: t.appBarFg, size: 20),
              tooltip: 'Edit entry',
              onPressed: () {
                setState(() => _previewMode = false);
                _tiptapCtrl.setEditable(true);
              },
            ),
          if (!_previewMode || !_isEdit)
            if (_dirty || !_isEdit)
              _saving
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: t.appBarFg)),
                    )
                  : IconButton(
                      icon: Icon(Icons.check_rounded, color: t.appBarFg),
                      onPressed: _save,
                      tooltip: 'Save',
                    ),
        ],
      ),
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          if (constraints.maxWidth >= 700) return _wideLayout(t);
          return _narrowLayout(t);
        },
      ),
    );
  }

  // ── Wide layout ───────────────────────────────────────────────────────────

  Widget _wideLayout(PaperTheme t) {
    final moodColor =
        _mood.isNotEmpty ? (_moodColors[_mood] ?? t.accent) : null;
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
                _panelSection(t, null, _dateBlock(t)),
                const SizedBox(height: 16),
                _panelSection(t, 'Mood', _moodGrid(t)),
                const SizedBox(height: 16),
                _panelSection(t, 'Paper', _paperStylePanel(t)),
                const SizedBox(height: 16),
                _panelSection(t, 'Theme', _themePanel(t)),
                const SizedBox(height: 16),
                _panelSection(t, 'Tags', _tagsPanel(t)),
                const SizedBox(height: 16),
                _panelSection(t, 'Memory Capsule', _capsulePanel(t)),
                const SizedBox(height: 16),
                if (_showPrompt)
                  _panelSection(t, 'Writing prompt', _promptPanel(t)),
                if (_wordCount > 0) ...[
                  const SizedBox(height: 16),
                  _panelSection(t, 'Stats', _statsPanel(t)),
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
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 3,
                  color: moodColor?.withValues(alpha: 0.55) ?? t.border,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                  child: TextField(
                    controller: _title,
                    style: GoogleFonts.cormorant(
                        color: t.heading,
                        fontSize: 30,
                        fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: 'Entry title…',
                      hintStyle: GoogleFonts.cormorant(
                          color: t.muted.withValues(alpha: 0.45),
                          fontSize: 30,
                          fontStyle: FontStyle.italic),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Divider(color: t.border, thickness: 0.7, height: 1),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Stack(
                    children: [
                      RuledPaper(
                        style: _toPaperStyle(),
                        lineColor: t.lines,
                        spacing: 32,
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(28, 4, 28, 80),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!_previewMode) _editorToolbar(t),
                                if (!_previewMode) const SizedBox(height: 6),
                                _tipTapBody(),
                                _voiceMemosSection(t),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (!_previewMode)
                        Positioned(
                          bottom: 14,
                          right: 16,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _micButton(t),
                              const SizedBox(width: 10),
                              _addPhotoButton(t),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Narrow layout ─────────────────────────────────────────────────────────

  Widget _narrowLayout(PaperTheme t) {
    final moodColor =
        _mood.isNotEmpty ? (_moodColors[_mood] ?? t.accent) : null;
    return Container(
      color: t.paper,
      child: Column(
        children: [
          // Mood strip
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
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: sel ? mc.withValues(alpha: 0.18) : t.card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: sel ? mc : t.border,
                            width: sel ? 1.5 : 0.6),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: TextField(
              controller: _title,
              style: GoogleFonts.cormorant(
                  color: t.heading, fontSize: 24, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'Entry title…',
                hintStyle: GoogleFonts.cormorant(
                    color: t.muted.withValues(alpha: 0.45),
                    fontSize: 24,
                    fontStyle: FontStyle.italic),
                border: InputBorder.none,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Divider(color: t.border, thickness: 0.6, height: 1),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Stack(
              children: [
                RuledPaper(
                  style: _toPaperStyle(),
                  lineColor: t.lines,
                  spacing: 30,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 2, 18, 80),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_showPrompt)
                            WritingPromptCard(
                              paperColor: t.paper,
                              accentColor: t.accent,
                              inkColor: t.ink,
                              mutedColor: t.muted,
                              onDismiss: () => setState(() => _showPrompt = false),
                              onUse: (p) {
                                _tiptapCtrl.setContent('<p>$p</p>');
                                setState(() { _dirty = true; _showPrompt = false; });
                              },
                            ),
                          if (!_previewMode) _editorToolbar(t),
                          if (!_previewMode) const SizedBox(height: 6),
                          _tipTapBody(),
                          _voiceMemosSection(t),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!_previewMode)
                  Positioned(
                    bottom: 14,
                    right: 12,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _micButton(t),
                        const SizedBox(width: 8),
                        _addPhotoButton(t),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Tags bar
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

  // ── TipTap body ───────────────────────────────────────────────────────────

  Widget _tipTapBody() {
    return TipTapEditor(
      controller: _tiptapCtrl,
      initialHtml: '',
      editable: !_previewMode,
      minHeight: 300,
    );
  }

  // ── Editor toolbar ────────────────────────────────────────────────────────

  Widget _editorToolbar(PaperTheme t) {
    Widget btn(IconData icon, VoidCallback onTap, {String? tooltip}) {
      return Tooltip(
        message: tooltip ?? '',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: t.border, width: 0.6),
            ),
            child: Icon(icon, size: 14, color: t.muted),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          btn(Icons.format_bold_rounded, _tiptapCtrl.bold, tooltip: 'Bold'),
          btn(Icons.format_italic_rounded, _tiptapCtrl.italic, tooltip: 'Italic'),
          btn(Icons.title_rounded, _tiptapCtrl.heading, tooltip: 'Heading'),
          btn(Icons.format_list_bulleted_rounded, _tiptapCtrl.bulletList, tooltip: 'Bullet list'),
        ],
      ),
    );
  }

  // ── Photo / mic FABs ──────────────────────────────────────────────────────

  Widget _addPhotoButton(PaperTheme t) {
    if (_uploading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: t.accent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: t.accent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add_photo_alternate_rounded, size: 16, color: Colors.white),
          SizedBox(width: 6),
          Text('Add Image',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _micButton(PaperTheme t) {
    if (_memoUploading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: t.accent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }
    if (_recording) {
      final m = _recordElapsed.inMinutes;
      final s = _recordElapsed.inSeconds % 60;
      return GestureDetector(
        onTap: _toggleRecording,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.stop_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text('$m:${s.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
    }
    return GestureDetector(
      onTap: _toggleRecording,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: t.accent,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: const Icon(Icons.mic_rounded, size: 16, color: Colors.white),
      ),
    );
  }

  // ── Voice memos section ───────────────────────────────────────────────────

  Widget _voiceMemosSection(PaperTheme t) {
    if (_voiceMemos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('VOICE MEMOS',
            style: TextStyle(
                color: t.muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 8),
        ..._voiceMemos.asMap().entries.map((e) => VoiceMemoPlayer(
              dataUrl: e.value['data'] as String,
              durationMs: int.tryParse('${e.value['duration_ms']}') ?? 0,
              theme: t,
              onDelete: () => _deleteVoiceMemo(e.value['id'] as String, e.key),
            )),
      ],
    );
  }

  // ── Panel sub-widgets ─────────────────────────────────────────────────────

  Widget _panelSection(PaperTheme t, String? label, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label.toUpperCase(),
              style: TextStyle(
                  color: t.heading.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
        ],
        content,
      ],
    );
  }

  Widget _dateBlock(PaperTheme t) {
    final now = _isEdit
        ? (DateTime.tryParse(widget.entry?['created_at'] as String? ?? '') ?? DateTime.now())
        : DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${moonPhaseEmoji(now)}  ${moonPhaseName(now)}',
            style: TextStyle(color: t.muted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(DateFormat('EEEE, MMMM d').format(now.toLocal()),
            style: GoogleFonts.cormorant(
                color: t.heading,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic)),
        Text(DateFormat('yyyy').format(now.toLocal()),
            style: TextStyle(color: t.muted, fontSize: 11)),
      ],
    );
  }

  Widget _moodGrid(PaperTheme t) {
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
            width: 36,
            height: 36,
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

  Widget _paperStylePanel(PaperTheme t) {
    final styles = <(String, String, IconData)>[
      ('plain', 'Plain', Icons.view_stream_rounded),
      ('lined', 'Lined', Icons.reorder_rounded),
      ('dotted', 'Dotted', Icons.apps_rounded),
      ('grid', 'Grid', Icons.grid_on_rounded),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: styles.map((s) {
        final sel = _paperStyle == s.$1;
        return GestureDetector(
          onTap: () => setState(() { _paperStyle = s.$1; _dirty = true; }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: sel ? t.accent.withValues(alpha: 0.15) : t.paper,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: sel ? t.accent : t.border, width: sel ? 1.2 : 0.6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(s.$3, size: 12, color: sel ? t.accent : t.muted),
              const SizedBox(width: 4),
              Text(s.$2,
                  style: TextStyle(
                      color: sel ? t.accent : t.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _themePanel(PaperTheme t) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        GestureDetector(
          onTap: () {
            setState(() { _themeId = ''; _dirty = true; });
            WidgetsBinding.instance.addPostFrameCallback((_) => _applyTipTapTheme());
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: (_themeId == null || _themeId!.isEmpty)
                  ? t.accent.withValues(alpha: 0.15)
                  : t.paper,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: (_themeId == null || _themeId!.isEmpty) ? t.accent : t.border,
                  width: (_themeId == null || _themeId!.isEmpty) ? 1.2 : 0.6),
            ),
            child: Text('Auto',
                style: TextStyle(
                    color: (_themeId == null || _themeId!.isEmpty) ? t.accent : t.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ),
        ...allPaperThemes.map((pt) {
          final sel = _themeId == pt.id;
          return GestureDetector(
            onTap: () {
              setState(() { _themeId = pt.id; _dirty = true; });
              _applyTipTapTheme(pt);
            },
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: pt.dot,
                shape: BoxShape.circle,
                border: Border.all(
                    color: sel ? t.accent : Colors.transparent, width: 2.4),
              ),
              child: sel ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
            ),
          );
        }),
      ],
    );
  }

  Widget _tagsPanel(PaperTheme t) {
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

  Widget _tagChip(String tag, PaperTheme t) {
    return InputChip(
      label: Text('#$tag',
          style: TextStyle(color: t.accent, fontSize: 13, fontWeight: FontWeight.w600)),
      onDeleted: () => _removeTag(tag),
      deleteIcon: Icon(Icons.close, size: 11, color: t.muted),
      backgroundColor: t.accent.withValues(alpha: 0.1),
      side: BorderSide(color: t.accent.withValues(alpha: 0.3), width: 0.6),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _addTagField(PaperTheme t) {
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

  Widget _promptPanel(PaperTheme t) {
    return WritingPromptCard(
      paperColor: t.card,
      accentColor: t.accent,
      inkColor: t.ink,
      mutedColor: t.muted,
      onDismiss: () => setState(() => _showPrompt = false),
      onUse: (p) {
        _tiptapCtrl.setContent('<p>$p</p>');
        setState(() { _dirty = true; _showPrompt = false; });
      },
    );
  }

  Widget _capsulePanel(PaperTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_lockedUntil != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: t.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: t.accent.withValues(alpha: 0.3), width: 0.6),
            ),
            child: Row(children: [
              const Text('🔒', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Seals ${DateFormat('MMM d, yyyy').format(_lockedUntil!)}',
                  style: TextStyle(color: t.accent, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() { _lockedUntil = null; _dirty = true; }),
                child: Icon(Icons.close, size: 13, color: t.muted),
              ),
            ]),
          ),
          const SizedBox(height: 6),
        ],
        GestureDetector(
          onTap: _pickSealDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: t.paper,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: t.border, width: 0.7),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_outline, size: 13, color: t.muted),
              const SizedBox(width: 6),
              Text(
                _lockedUntil == null ? 'Seal until a date…' : 'Change date',
                style: TextStyle(color: t.muted, fontSize: 11),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 4),
        Text('Entry stays sealed until that date.',
            style: TextStyle(color: t.muted, fontSize: 11)),
      ],
    );
  }

  Widget _statsPanel(PaperTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statRow(t, 'Words', '$_wordCount'),
        if (_mood.isNotEmpty) ...[const SizedBox(height: 4), _statRow(t, 'Mood', _mood)],
        if (_imageCount > 0) ...[const SizedBox(height: 4), _statRow(t, 'Images', '$_imageCount')],
        if (_voiceMemos.isNotEmpty) ...[
          const SizedBox(height: 4),
          _statRow(t, 'Voice memos', '${_voiceMemos.length}'),
        ],
      ],
    );
  }

  Widget _statRow(PaperTheme t, String label, String value) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: t.ink.withValues(alpha: 0.65), fontSize: 13)),
        const Spacer(),
        Text(value,
            style: TextStyle(color: t.heading, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
