import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../theme.dart';
import '../utils/moon_phase.dart';
import '../utils/journal_stats.dart';
import '../widgets/star_field.dart';
import 'entry_screen.dart';
import 'calendar_screen.dart';

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

  PaperTheme get _t => ThemeService.current;

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

  Future<void> _openCalendar() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CalendarScreen(
          entries: _entries,
          onRefresh: _load,
        ),
      ),
    );
    _load();
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    widget.onSignOut();
  }

  Future<void> _pickTheme() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: _t.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ThemePicker(
        current: _t,
        onSelect: (pt) async {
          await ThemeService.set(pt);
          widget.onThemeChange();
          if (mounted) setState(() {});
        },
      ),
    );
    setState(() {});
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _firstName {
    final name = AuthService.userName ?? '';
    return name.isNotEmpty ? name.split(' ').first : 'dear';
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final isMidnight = t.id == 'midnight';
    final isForest = t.id == 'forest';
    final showStars = isMidnight || isForest;

    Widget body;
    if (_loading) {
      body = Center(child: CircularProgressIndicator(color: t.accent, strokeWidth: 2));
    } else if (_error != null) {
      body = Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)));
    } else {
      final streak = journalStreak(_entries);
      final words = totalWordCount(_entries);
      final listContent = _entries.isEmpty
          ? _emptyState(t)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              itemCount: _entries.length,
              itemBuilder: (_, i) => _entryCard(_entries[i], t),
            );

      body = CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _header(t, streak, words)),
          SliverFillRemaining(hasScrollBody: true, child: listContent),
        ],
      );
    }

    if (showStars) {
      body = StarField(starColor: Colors.white, count: 80, child: body);
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
          // Calendar
          IconButton(
            icon: Icon(Icons.calendar_month_outlined, color: t.appBarFg, size: 20),
            tooltip: 'Mood calendar',
            onPressed: _loading ? null : _openCalendar,
          ),
          // Theme dots
          InkWell(
            onTap: _pickTheme,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Row(
                children: allPaperThemes.map((pt) => Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
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
            GestureDetector(
              onTap: _signOut,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Tooltip(
                  message: 'Sign out',
                  child: CircleAvatar(
                    radius: 14,
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

  Widget _header(PaperTheme t, int streak, int words) {
    final now = DateTime.now();
    final moon = moonPhaseEmoji(now);
    final dateStr = DateFormat('EEEE, MMMM d').format(now);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        color: t.card,
        border: Border(bottom: BorderSide(color: t.border, width: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Moon + greeting
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(moon, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_greeting, $_firstName',
                          style: GoogleFonts.playfairDisplay(
                            color: t.heading,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          dateStr,
                          style: TextStyle(color: t.muted, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Streak badge
              if (streak > 0)
                _badge(
                  streak == 1 ? '1 day' : '$streak days',
                  streak >= 7 ? '🔥' : '✦',
                  t,
                ),
            ],
          ),
          if (words > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _statPill('${_entries.length}', 'entries', t),
                const SizedBox(width: 8),
                _statPill('$words', 'words', t),
                const SizedBox(width: 8),
                _statPill(moonPhaseEmoji(now), moonPhaseName(now), t, isEmoji: true),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String label, String icon, PaperTheme t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: t.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.accent.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: t.accent, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _statPill(String value, String label, PaperTheme t, {bool isEmoji = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: t.border.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isEmoji)
            Text(value, style: TextStyle(color: t.heading, fontSize: 11, fontWeight: FontWeight.w700)),
          if (!isEmoji) const SizedBox(width: 3),
          Text(
            isEmoji ? '$value $label' : label,
            style: TextStyle(color: t.muted, fontSize: 11),
          ),
        ],
      ),
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
    final date = DateTime.tryParse(entry['created_at'] as String? ?? '');
    final month  = date != null ? DateFormat('MMM').format(date.toLocal()) : '';
    final day    = date != null ? DateFormat('d').format(date.toLocal())   : '';
    final year   = date != null ? DateFormat('yyyy').format(date.toLocal()) : '';
    final mood   = entry['mood'] as String? ?? '';
    final title  = entry['title'] as String? ?? '';
    final body   = entry['body'] as String? ?? '';
    final tagsRaw = entry['tags'] as String? ?? '';
    final tags   = tagsRaw.isNotEmpty
        ? tagsRaw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).take(3).toList()
        : <String>[];
    final preview = body.length > 120 ? '${body.substring(0, 120)}…' : body;
    final moodColor = _moodColors[mood] ?? t.accent;

    return GestureDetector(
      onTap: () => _openEntry(entry),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.border, width: 0.7),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date column
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: mood.isNotEmpty ? moodColor.withValues(alpha: 0.11) : t.border.withValues(alpha: 0.3),
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
                    style: TextStyle(color: mood.isNotEmpty ? moodColor : t.muted, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    day,
                    style: GoogleFonts.playfairDisplay(
                      color: t.heading,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(year, style: TextStyle(color: t.muted, fontSize: 9)),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
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
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              fontStyle: title.isEmpty ? FontStyle.italic : FontStyle.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (mood.isNotEmpty)
                          Container(
                            width: 26,
                            height: 26,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: moodColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: moodColor.withValues(alpha: 0.4), width: 0.7),
                            ),
                            child: Center(child: Text(mood, style: const TextStyle(fontSize: 13))),
                          ),
                      ],
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        preview,
                        style: TextStyle(color: t.ink.withValues(alpha: 0.6), fontSize: 12, height: 1.5),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 4,
                        children: tags.map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: t.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: t.accent.withValues(alpha: 0.25), width: 0.6),
                          ),
                          child: Text(
                            '#$tag',
                            style: TextStyle(color: t.accent, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Right accent bar
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: mood.isNotEmpty ? moodColor.withValues(alpha: 0.6) : t.border,
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

// ── Theme picker ──────────────────────────────────────────────────────────────

class _ThemePicker extends StatelessWidget {
  final PaperTheme current;
  final void Function(PaperTheme) onSelect;
  const _ThemePicker({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t = current;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose your paper',
            style: GoogleFonts.playfairDisplay(color: t.heading, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          // Row 1: first 3 themes
          Row(
            children: allPaperThemes.take(3).map((pt) => _themeCard(pt, t, context)).toList(),
          ),
          const SizedBox(height: 8),
          // Row 2: remaining 2 themes
          Row(
            children: [
              ...allPaperThemes.skip(3).map((pt) => _themeCard(pt, t, context)),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _themeCard(PaperTheme pt, PaperTheme current, BuildContext context) {
    final selected = pt.id == current.id;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          onSelect(pt);
          Navigator.of(context).pop();
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: pt.paper,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? pt.accent : pt.border,
              width: selected ? 2.0 : 0.7,
            ),
            boxShadow: selected
                ? [BoxShadow(color: pt.accent.withValues(alpha: 0.2), blurRadius: 8)]
                : [],
          ),
          child: Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: pt.dot, shape: BoxShape.circle),
              ),
              const SizedBox(height: 6),
              Text(pt.name, style: TextStyle(color: pt.ink, fontSize: 11, fontWeight: FontWeight.w600)),
              if (selected) ...[
                const SizedBox(height: 3),
                Icon(Icons.check_circle, size: 12, color: pt.accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
