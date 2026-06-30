import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../theme.dart';
import '../widgets/star_field.dart';
import 'entry_screen.dart';

// Mood → accent colour
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

class TimelineScreen extends StatefulWidget {
  final VoidCallback onSignOut;
  final VoidCallback onThemeChange;
  const TimelineScreen({
    super.key,
    required this.onSignOut,
    required this.onThemeChange,
  });

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  String? _error;

  PaperTheme get _theme => ThemeService.current;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final entries = await ApiService.getEntries();
      setState(() { _entries = entries; });
    } catch (e) {
      setState(() { _error = '$e'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _newEntry() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const EntryScreen()),
    );
    if (created == true) _load();
  }

  Future<void> _openEntry(Map<String, dynamic> entry) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EntryScreen(entry: entry)),
    );
    if (changed == true) _load();
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    widget.onSignOut();
  }

  Future<void> _pickTheme() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: _theme.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ThemePicker(
        current: _theme,
        onSelect: (t) async {
          await ThemeService.set(t);
          widget.onThemeChange();
          if (mounted) setState(() {});
        },
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    final isMidnight = t.id == 'midnight';

    Widget body;
    if (_loading) {
      body = Center(child: CircularProgressIndicator(color: t.accent, strokeWidth: 2));
    } else if (_error != null) {
      body = Center(child: Text(_error!, style: TextStyle(color: Colors.redAccent, fontSize: 13)));
    } else if (_entries.isEmpty) {
      body = _emptyState(t);
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        color: t.accent,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: _entries.length,
          itemBuilder: (_, i) => _entryCard(_entries[i], t),
        ),
      );
    }

    if (isMidnight) {
      body = StarField(
        starColor: Colors.white,
        count: 80,
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.appBarBg,
        title: Text(
          'DevineJournal',
          style: GoogleFonts.playfairDisplay(
            color: t.appBarFg,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          // Theme picker dots
          InkWell(
            onTap: _pickTheme,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Row(
                children: allPaperThemes.map((pt) => Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: pt.dot,
                    shape: BoxShape.circle,
                    border: pt.id == t.id
                        ? Border.all(color: Colors.white, width: 1.5)
                        : null,
                  ),
                )).toList(),
              ),
            ),
          ),
          const SizedBox(width: 4),
          if (AuthService.userPic != null && AuthService.userPic!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: GestureDetector(
                onTap: _signOut,
                child: Tooltip(
                  message: 'Sign out',
                  child: CircleAvatar(
                    radius: 15,
                    backgroundImage: NetworkImage(AuthService.userPic!),
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.logout, color: t.muted, size: 18),
              tooltip: 'Sign out',
              onPressed: _signOut,
            ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _newEntry,
        tooltip: 'New entry',
        backgroundColor: t.accent,
        foregroundColor: t.brightness == Brightness.dark ? t.bg : Colors.white,
        child: const Icon(Icons.edit_rounded),
      ),
      body: body,
    );
  }

  Widget _emptyState(PaperTheme t) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🌙', style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 20),
          Text(
            'Your journal awaits',
            style: GoogleFonts.playfairDisplay(
              color: t.heading,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap ✏ below to write your first entry',
            style: TextStyle(color: t.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _entryCard(Map<String, dynamic> entry, PaperTheme t) {
    final date = DateTime.tryParse(entry['created_at'] ?? '');
    final month = date != null ? DateFormat('MMM').format(date.toLocal()) : '';
    final day   = date != null ? DateFormat('d').format(date.toLocal())   : '';
    final year  = date != null ? DateFormat('yyyy').format(date.toLocal()) : '';
    final mood  = entry['mood'] as String? ?? '';
    final title = entry['title'] as String? ?? '';
    final body  = entry['body'] as String? ?? '';
    final preview = body.length > 140 ? '${body.substring(0, 140)}…' : body;
    final moodColor = _moodColors[mood] ?? t.accent;

    return GestureDetector(
      onTap: () => _openEntry(entry),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.border, width: 0.7),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Date column ───────────────────────────────────────────────
            Container(
              width: 58,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: moodColor.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
                border: Border(right: BorderSide(color: t.border, width: 0.5)),
              ),
              child: Column(
                children: [
                  Text(
                    month.toUpperCase(),
                    style: TextStyle(
                      color: moodColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    day,
                    style: GoogleFonts.playfairDisplay(
                      color: t.heading,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    year,
                    style: TextStyle(color: t.muted, fontSize: 10),
                  ),
                ],
              ),
            ),

            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title.isNotEmpty ? title : 'Untitled',
                            style: GoogleFonts.playfairDisplay(
                              color: title.isNotEmpty ? t.heading : t.muted,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontStyle: title.isEmpty ? FontStyle.italic : FontStyle.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (mood.isNotEmpty)
                          Container(
                            width: 28,
                            height: 28,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              color: moodColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: moodColor.withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Center(
                              child: Text(mood, style: const TextStyle(fontSize: 14)),
                            ),
                          ),
                      ],
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        preview,
                        style: TextStyle(
                          color: t.ink.withValues(alpha: 0.65),
                          fontSize: 12.5,
                          height: 1.55,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Right accent bar ───────────────────────────────────────────
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: moodColor.withValues(alpha: 0.6),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Theme picker sheet ─────────────────────────────────────────────────────────

class _ThemePicker extends StatelessWidget {
  final PaperTheme current;
  final void Function(PaperTheme) onSelect;
  const _ThemePicker({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t = current;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose your paper',
            style: GoogleFonts.playfairDisplay(
              color: t.heading,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: allPaperThemes.map((pt) {
              final selected = pt.id == current.id;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    onSelect(pt);
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: pt.paper,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? pt.accent : pt.border,
                        width: selected ? 2.0 : 0.7,
                      ),
                      boxShadow: selected
                          ? [BoxShadow(color: pt.accent.withValues(alpha: 0.25), blurRadius: 10)]
                          : [],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: pt.dot,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          pt.name,
                          style: TextStyle(
                            color: pt.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (selected) ...[
                          const SizedBox(height: 4),
                          Icon(Icons.check_circle, size: 14, color: pt.accent),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
