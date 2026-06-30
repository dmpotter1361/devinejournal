import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import '../utils/moon_phase.dart';
import '../widgets/ruled_paper.dart';
import '../widgets/writing_prompt.dart';

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
  const EntryScreen({super.key, this.entry});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late String _mood;
  late List<String> _tags;
  DateTime? _lockedUntil;
  String _paperStyle = 'lined';
  bool _isFavorite = false;
  bool _saving = false;
  bool _dirty  = false;
  bool _showPrompt = false;
  final _tagController = TextEditingController();

  // Entry ID (null until first save for new entries)
  String? _entryId;

  // Photos
  List<Map<String, dynamic>> _photos = [];
  List<TextEditingController> _captionControllers = [];
  bool _uploading = false;

  bool get _isEdit => _entryId != null;

  @override
  void initState() {
    super.initState();
    _entryId = widget.entry?['id'] as String?;
    _title = TextEditingController(text: widget.entry?['title'] ?? '');
    _body  = TextEditingController(text: widget.entry?['body'] ?? '');
    _mood  = widget.entry?['mood'] ?? '';
    final tagsRaw = widget.entry?['tags'] as String? ?? '';
    _tags = tagsRaw.isNotEmpty
        ? tagsRaw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : [];
    final lu = widget.entry?['locked_until'] as String?;
    if (lu != null && lu.isNotEmpty) {
      _lockedUntil = DateTime.tryParse(lu);
    }
    _paperStyle = widget.entry?['paper_style'] as String? ?? 'lined';
    _isFavorite = widget.entry?['is_favorite'] as bool? ?? false;
    _showPrompt = _entryId == null;
    _title.addListener(_mark);
    _body.addListener(_mark);
    if (_entryId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPhotos());
    }
  }

  void _mark() { if (!_dirty && mounted) setState(() => _dirty = true); }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _tagController.dispose();
    for (final c in _captionControllers) c.dispose();
    super.dispose();
  }

  // ── Tag helpers ────────────────────────────────────────────────────────────

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

  PaperStyle _toPaperStyle() => switch (_paperStyle) {
    'dotted' => PaperStyle.dotted,
    'grid'   => PaperStyle.grid,
    'plain'  => PaperStyle.plain,
    _        => PaperStyle.lined,
  };

  // ── Photo helpers ──────────────────────────────────────────────────────────

  Uint8List _base64ToBytes(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    return base64Decode(comma >= 0 ? dataUrl.substring(comma + 1) : dataUrl);
  }

  void _initCaptionControllers() {
    for (final c in _captionControllers) c.dispose();
    _captionControllers = _photos
        .map((p) => TextEditingController(text: p['caption'] as String? ?? ''))
        .toList();
  }

  Future<void> _loadPhotos() async {
    if (_entryId == null) return;
    try {
      final photos = await ApiService.getPhotos(_entryId!);
      if (mounted) {
        setState(() {
          _photos = photos;
          _initCaptionControllers();
        });
      }
    } catch (_) {}
  }

  // Auto-save the entry so we get an ID before uploading a photo
  Future<bool> _ensureSaved() async {
    if (_entryId != null) return true;
    try {
      final created = await ApiService.createEntry(
        title: _title.text,
        body: _body.text,
        mood: _mood,
        tags: _tagsString,
        lockedUntil: _lockedUntil?.toUtc().toIso8601String(),
        paperStyle: _paperStyle,
        isFavorite: _isFavorite,
      );
      if (mounted) setState(() { _entryId = created['id'] as String; _dirty = false; });
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
    if (!await _ensureSaved()) return;

    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    } catch (_) {
      return;
    }
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    if (!mounted) return;
    setState(() => _uploading = true);
    try {
      final photo = await ApiService.uploadPhoto(_entryId!, bytes, file.name);
      if (mounted) {
        setState(() {
          _photos.add(photo);
          _captionControllers.add(
            TextEditingController(text: photo['caption'] as String? ?? ''));
        });
      }
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

  Future<void> _deletePhoto(String photoId, int idx) async {
    try {
      await ApiService.deletePhoto(photoId);
      if (mounted) {
        setState(() {
          _captionControllers[idx].dispose();
          _captionControllers.removeAt(idx);
          _photos.removeAt(idx);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _updatePhotoLayout(String photoId, int idx,
      {String? widthPct, String? align}) async {
    if (widthPct != null) setState(() => _photos[idx]['width_pct'] = widthPct);
    if (align != null)    setState(() => _photos[idx]['align']     = align);
    try {
      await ApiService.updatePhoto(photoId, widthPct: widthPct, align: align);
    } catch (_) {}
  }

  Future<void> _saveCaption(String photoId, int idx) async {
    try {
      final caption = _captionControllers[idx].text;
      await ApiService.updatePhoto(photoId, caption: caption);
      if (mounted) setState(() => _photos[idx]['caption'] = caption);
    } catch (_) {}
  }

  // ── Save / Delete ──────────────────────────────────────────────────────────

  Future<void> _pickSealDate() async {
    final t = ThemeService.current;
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
    if (picked != null) setState(() { _lockedUntil = picked; _dirty = true; });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // Flush pending captions
      for (var i = 0; i < _photos.length; i++) {
        final typed   = _captionControllers[i].text;
        final stored  = _photos[i]['caption'] as String? ?? '';
        if (typed != stored) {
          await ApiService.updatePhoto(_photos[i]['id'] as String, caption: typed);
        }
      }

      final luStr = _lockedUntil?.toUtc().toIso8601String();
      if (_entryId != null) {
        await ApiService.updateEntry(
          _entryId!,
          title: _title.text, body: _body.text, mood: _mood, tags: _tagsString,
          lockedUntil: luStr,
          clearLock: _lockedUntil == null && (widget.entry?['locked_until'] as String?)?.isNotEmpty == true,
          paperStyle: _paperStyle,
          isFavorite: _isFavorite,
        );
      } else {
        final created = await ApiService.createEntry(
          title: _title.text, body: _body.text, mood: _mood, tags: _tagsString,
          lockedUntil: luStr,
          paperStyle: _paperStyle,
          isFavorite: _isFavorite,
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
    final t = ThemeService.current;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.paper,
        title: Text('Delete entry?', style: TextStyle(color: t.heading)),
        content: Text('This cannot be undone.', style: TextStyle(color: t.ink)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: t.muted))),
          TextButton(onPressed: () => Navigator.pop(context, true),
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

  // ── Build ──────────────────────────────────────────────────────────────────

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
          if (constraints.maxWidth >= 700) return _wideLayout(t);
          return _narrowLayout(t);
        },
      ),
    );
  }

  // ── Wide layout ────────────────────────────────────────────────────────────

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
                _panelSection(t, null, _dateBlock(t)),
                const SizedBox(height: 16),
                _panelSection(t, 'Mood', _moodGrid(t)),
                const SizedBox(height: 16),
                _panelSection(t, 'Paper', _paperStylePanel(t)),
                const SizedBox(height: 16),
                _panelSection(t, 'Tags', _tagsPanel(t)),
                const SizedBox(height: 16),
                _panelSection(t, 'Memory Capsule', _capsulePanel(t)),
                const SizedBox(height: 16),
                if (_showPrompt)
                  _panelSection(t, 'Writing prompt', _promptPanel(t)),
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
                        color: t.heading, fontSize: 30, fontWeight: FontWeight.w700),
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
                // Paper body + photos
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
                                TextField(
                                  controller: _body,
                                  maxLines: null,
                                  textAlignVertical: TextAlignVertical.top,
                                  style: GoogleFonts.lora(
                                      color: t.ink, fontSize: 18, height: 1.95),
                                  decoration: InputDecoration(
                                    hintText: 'Write your thoughts…',
                                    hintStyle: GoogleFonts.lora(
                                        color: t.muted.withValues(alpha: 0.38),
                                        fontSize: 18,
                                        fontStyle: FontStyle.italic),
                                    border: InputBorder.none,
                                  ),
                                ),
                                if (_photos.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Divider(color: t.lines, thickness: 0.8),
                                  ..._photos.asMap().entries.map(
                                    (e) => _photoItem(e.value, t, e.key)),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Add photo button
                      Positioned(
                        bottom: 14,
                        right: 16,
                        child: _addPhotoButton(t),
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

  // ── Narrow layout ──────────────────────────────────────────────────────────

  Widget _narrowLayout(dynamic t) {
    final moodColor = _mood.isNotEmpty ? (_moodColors[_mood] ?? t.accent) : null;
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
                      width: 36, height: 36,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: sel ? mc.withValues(alpha: 0.18) : t.card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: sel ? mc : t.border, width: sel ? 1.5 : 0.6),
                      ),
                      child: Center(
                        child: m.isEmpty
                            ? Icon(Icons.mood_outlined, size: 14,
                                color: sel ? t.accent : t.muted)
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
          // Paper body + photos
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
                                _body.text = p;
                                _dirty = true;
                                setState(() => _showPrompt = false);
                              },
                            ),
                          TextField(
                            controller: _body,
                            maxLines: null,
                            textAlignVertical: TextAlignVertical.top,
                            style: GoogleFonts.lora(
                                color: t.ink, fontSize: 17, height: 1.95),
                            decoration: InputDecoration(
                              hintText: 'Write your thoughts…',
                              hintStyle: GoogleFonts.lora(
                                  color: t.muted.withValues(alpha: 0.38),
                                  fontSize: 17,
                                  fontStyle: FontStyle.italic),
                              border: InputBorder.none,
                            ),
                          ),
                          if (_photos.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Divider(color: t.lines, thickness: 0.8),
                            ..._photos.asMap().entries.map(
                              (e) => _photoItem(e.value, t, e.key)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                // Add photo button
                Positioned(
                  bottom: 14,
                  right: 12,
                  child: _addPhotoButton(t),
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

  // ── Photo widgets ──────────────────────────────────────────────────────────

  Widget _addPhotoButton(dynamic t) {
    if (_uploading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: t.accent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: const SizedBox(
          width: 16, height: 16,
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
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.add_photo_alternate_rounded, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          const Text('Add Image',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _photoItem(Map<String, dynamic> photo, dynamic t, int idx) {
    final pct     = int.tryParse(photo['width_pct'] as String? ?? '100') ?? 100;
    final align   = photo['align'] as String? ?? 'center';
    final data    = photo['data'] as String? ?? '';
    final photoId = photo['id'] as String;
    final bytes   = _base64ToBytes(data);

    CrossAxisAlignment crossAlign;
    switch (align) {
      case 'left':  crossAlign = CrossAxisAlignment.start; break;
      case 'right': crossAlign = CrossAxisAlignment.end;   break;
      default:      crossAlign = CrossAxisAlignment.center;
    }

    TextAlign captionAlign;
    switch (align) {
      case 'left':  captionAlign = TextAlign.left;   break;
      case 'right': captionAlign = TextAlign.right;  break;
      default:      captionAlign = TextAlign.center;
    }

    final alignButtons = <(String, IconData)>[
      ('left',   Icons.format_align_left_rounded),
      ('center', Icons.format_align_center_rounded),
      ('right',  Icons.format_align_right_rounded),
    ];

    return LayoutBuilder(builder: (ctx, constraints) {
      final imgW = constraints.maxWidth * pct / 100;

      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Column(
          crossAxisAlignment: crossAlign,
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(bytes, width: imgW, fit: BoxFit.cover),
            ),
            const SizedBox(height: 8),
            // Control bar
            SizedBox(
              width: imgW,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  // Width presets
                  ...['25', '50', '75', '100'].map((p) {
                    final sel = pct == int.parse(p);
                    return GestureDetector(
                      onTap: () => _updatePhotoLayout(photoId, idx, widthPct: p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: sel ? t.accent.withValues(alpha: 0.15) : t.bg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: sel ? t.accent : t.border,
                              width: sel ? 1.2 : 0.6),
                        ),
                        child: Text('$p%',
                            style: TextStyle(
                                color: sel ? t.accent : t.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                    );
                  }),
                  // Separator
                  Container(width: 1, height: 22,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      color: t.border),
                  // Align buttons
                  ...alignButtons.map((a) {
                    final sel = align == a.$1;
                    return GestureDetector(
                      onTap: () => _updatePhotoLayout(photoId, idx, align: a.$1),
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: sel ? t.accent.withValues(alpha: 0.15) : t.bg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: sel ? t.accent : t.border,
                              width: sel ? 1.2 : 0.6),
                        ),
                        child: Icon(a.$2, size: 15,
                            color: sel ? t.accent : t.muted),
                      ),
                    );
                  }),
                  // Separator
                  Container(width: 1, height: 22,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      color: t.border),
                  // Delete
                  GestureDetector(
                    onTap: () => _deletePhoto(photoId, idx),
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.3),
                            width: 0.6),
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          size: 15, color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),
            // Caption
            SizedBox(
              width: imgW,
              child: TextField(
                controller: _captionControllers[idx],
                textAlign: captionAlign,
                style: GoogleFonts.lora(
                    color: t.muted, fontSize: 13, fontStyle: FontStyle.italic),
                decoration: InputDecoration(
                  hintText: 'Add a caption…',
                  hintStyle: TextStyle(
                      color: t.muted.withValues(alpha: 0.4),
                      fontSize: 13,
                      fontStyle: FontStyle.italic),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                ),
                onSubmitted: (_) => _saveCaption(photoId, idx),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    });
  }

  // ── Panel sub-widgets ──────────────────────────────────────────────────────

  Widget _panelSection(dynamic t, String? label, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label.toUpperCase(),
              style: TextStyle(
                  color: t.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
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
              border: Border.all(
                  color: sel ? mc : t.border, width: sel ? 1.5 : 0.6),
            ),
            child: Center(
              child: m.isEmpty
                  ? Icon(Icons.mood_outlined, size: 15,
                      color: sel ? t.accent : t.muted)
                  : Text(m, style: const TextStyle(fontSize: 17)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _paperStylePanel(dynamic t) {
    final styles = <(String, String, IconData)>[
      ('plain',  'Plain',  Icons.view_stream_rounded),
      ('lined',  'Lined',  Icons.reorder_rounded),
      ('dotted', 'Dotted', Icons.apps_rounded),
      ('grid',   'Grid',   Icons.grid_on_rounded),
    ];
    return Wrap(
      spacing: 6, runSpacing: 6,
      children: styles.map((s) {
        final sel = _paperStyle == s.$1;
        return GestureDetector(
          onTap: () => setState(() { _paperStyle = s.$1; _dirty = true; }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: sel ? t.accent.withValues(alpha: 0.15) : t.paper,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: sel ? t.accent : t.border, width: sel ? 1.2 : 0.6),
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

  Widget _tagsPanel(dynamic t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_tags.isNotEmpty)
          Wrap(
            spacing: 5, runSpacing: 5,
            children: _tags.map((tag) => _tagChip(tag, t)).toList(),
          ),
        const SizedBox(height: 6),
        _addTagField(t),
      ],
    );
  }

  Widget _tagChip(String tag, dynamic t) {
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

  Widget _addTagField(dynamic t) {
    return SizedBox(
      width: 110, height: 30,
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

  Widget _capsulePanel(dynamic t) {
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
            style: TextStyle(color: t.muted.withValues(alpha: 0.6), fontSize: 10)),
      ],
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
        if (_photos.isNotEmpty) ...[
          const SizedBox(height: 4),
          _statRow(t, 'Images', '${_photos.length}'),
        ],
      ],
    );
  }

  Widget _statRow(dynamic t, String label, String value) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: t.muted, fontSize: 13)),
        const Spacer(),
        Text(value,
            style: TextStyle(color: t.heading, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
