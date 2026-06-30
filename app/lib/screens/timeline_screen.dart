import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../theme.dart';
import '../utils/moon_phase.dart';
import '../utils/journal_stats.dart';
import '../utils/affirmations.dart';
import '../widgets/star_field.dart';
import 'entry_screen.dart';
import 'calendar_screen.dart';
import 'gratitude_screen.dart';

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

class TimelineScreen extends StatefulWidget {
  final VoidCallback onSignOut;
  final VoidCallback onThemeChange;
  const TimelineScreen({super.key, required this.onSignOut, required this.onThemeChange});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  String? _error;

  // Search / filter
  bool _showSearch = false;
  String _searchQuery = '';
  String? _activeTag;
  String? _activeMood;
  bool _showFavoritesOnly = false;
  final _searchCtrl = TextEditingController();

  // Expandable FAB
  bool _fabExpanded = false;
  late final AnimationController _fabAnim;
  late final Animation<double> _fabRotate;

  PaperTheme get _t => ThemeService.current;

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _fabRotate = Tween<double>(begin: 0, end: 0.125).animate(
      CurvedAnimation(parent: _fabAnim, curve: Curves.easeInOut),
    );
    _load();
  }

  @override
  void dispose() {
    _fabAnim.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

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

  List<Map<String, dynamic>> get _filtered {
    var list = _entries;
    if (_showFavoritesOnly) {
      list = list.where((e) => e['is_favorite'] == true).toList();
    }
    if (_activeTag != null) {
      list = list.where((e) {
        final tags = (e['tags'] as String? ?? '').split(',').map((s) => s.trim());
        return tags.contains(_activeTag);
      }).toList();
    }
    if (_activeMood != null) {
      list = list.where((e) => e['mood'] == _activeMood).toList();
    }
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((e) {
        final title = (e['title'] as String? ?? '').toLowerCase();
        final body  = (e['body']  as String? ?? '').toLowerCase();
        final tags  = (e['tags']  as String? ?? '').toLowerCase();
        return title.contains(q) || body.contains(q) || tags.contains(q);
      }).toList();
    }
    return list;
  }

  List<Map<String, dynamic>> get _onThisDay {
    final today = DateTime.now();
    return _entries.where((e) {
      final d = DateTime.tryParse(e['created_at'] as String? ?? '');
      if (d == null) return false;
      final l = d.toLocal();
      return l.month == today.month && l.day == today.day && l.year < today.year;
    }).toList();
  }

  bool _isSealed(Map<String, dynamic> entry) {
    final lu = entry['locked_until'] as String?;
    if (lu == null || lu.isEmpty) return false;
    final until = DateTime.tryParse(lu);
    return until != null && until.isAfter(DateTime.now());
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _newEntry() async {
    _closeFab();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const EntryScreen()),
    );
    if (created == true) _load();
  }

  Future<void> _openGratitude() async {
    _closeFab();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const GratitudeScreen()),
    );
    if (saved == true) _load();
  }

  Future<void> _openEntry(Map<String, dynamic> entry) async {
    if (_isSealed(entry)) {
      final lu = DateTime.tryParse(entry['locked_until'] as String? ?? '')!;
      _showSealedDialog(lu);
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EntryScreen(entry: entry)),
    );
    if (changed == true) _load();
  }

  Future<void> _openCalendar() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CalendarScreen(entries: _entries, onRefresh: _load)),
    );
    _load();
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    widget.onSignOut();
  }

  void _showSealedDialog(DateTime until) {
    final t = _t;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.paper,
        title: Row(children: [
          const Text('🔒', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Text('Memory Sealed', style: GoogleFonts.cinzelDecorative(color: t.heading, fontSize: 15)),
        ]),
        content: Text(
          'This memory will open on\n${DateFormat('MMMM d, yyyy').format(until.toLocal())}.\n\nCome back then — it will be waiting for you.',
          style: GoogleFonts.lora(color: t.ink, fontSize: 15, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('I\'ll wait', style: TextStyle(color: t.accent, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  // ── FAB ───────────────────────────────────────────────────────────────────

  void _toggleFab() {
    setState(() => _fabExpanded = !_fabExpanded);
    _fabExpanded ? _fabAnim.forward() : _fabAnim.reverse();
  }

  void _closeFab() {
    if (_fabExpanded) {
      setState(() => _fabExpanded = false);
      _fabAnim.reverse();
    }
  }

  // ── Theme picker ──────────────────────────────────────────────────────────

  Future<void> _pickTheme() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: _t.paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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

  // ── Helpers ───────────────────────────────────────────────────────────────

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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final showStars = t.id == 'midnight' || t.id == 'forest' || t.id == 'celestial';
    final starColor = t.id == 'celestial' ? const Color(0xFFd4c8ff) : Colors.white;

    Widget body;
    if (_loading) {
      body = Center(child: CircularProgressIndicator(color: t.accent, strokeWidth: 2));
    } else if (_error != null) {
      body = Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 14)));
    } else {
      final streak = journalStreak(_entries);
      final words  = totalWordCount(_entries);
      final shown  = _filtered;

      body = Column(
        children: [
          // Search bar (animated)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: _showSearch ? 52 : 0,
            color: t.appBarBg,
            child: _showSearch
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      style: TextStyle(color: t.appBarFg, fontSize: 15),
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search your journal…',
                        hintStyle: TextStyle(color: t.appBarFg.withValues(alpha: 0.45), fontSize: 15),
                        prefixIcon: Icon(Icons.search, color: t.appBarFg.withValues(alpha: 0.6), size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: t.muted, size: 16),
                                onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
                              )
                            : null,
                        filled: true,
                        fillColor: t.card.withValues(alpha: 0.4),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Favorites banner
          if (_showFavoritesOnly)
            Container(
              color: const Color(0xFFf48fb1).withValues(alpha: 0.12),
              padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
              child: Row(
                children: [
                  const Icon(Icons.favorite_rounded, size: 14, color: Color(0xFFf48fb1)),
                  const SizedBox(width: 6),
                  Text('Favorites — ${shown.length} ${shown.length == 1 ? 'entry' : 'entries'}',
                    style: const TextStyle(color: Color(0xFFf48fb1), fontSize: 13, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _showFavoritesOnly = false),
                    child: Icon(Icons.close, size: 14, color: t.muted),
                  ),
                ],
              ),
            ),

          // Active tag filter chip
          if (_activeTag != null)
            Container(
              color: t.card,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: t.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: t.accent.withValues(alpha: 0.3), width: 0.7),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('#$_activeTag', style: TextStyle(color: t.accent, fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => setState(() => _activeTag = null),
                          child: Icon(Icons.close, size: 13, color: t.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${shown.length} ${shown.length == 1 ? 'entry' : 'entries'}',
                    style: TextStyle(color: t.muted, fontSize: 12)),
                ],
              ),
            ),

          // Active mood filter chip
          if (_activeMood != null)
            Container(
              color: t.card,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (_moodColors[_activeMood] ?? t.accent).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: (_moodColors[_activeMood] ?? t.accent).withValues(alpha: 0.3), width: 0.7),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_activeMood!, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() => _activeMood = null),
                        child: Icon(Icons.close, size: 13, color: t.muted),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Text('${shown.length} ${shown.length == 1 ? 'entry' : 'entries'}',
                    style: TextStyle(color: t.muted, fontSize: 12)),
                ],
              ),
            ),

          // Scrollable list
          Expanded(
            child: shown.isEmpty && _entries.isEmpty
                ? _emptyState(t)
                : RefreshIndicator(
                    onRefresh: _load,
                    color: t.accent,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      itemCount: 1 + _onThisDay.length + shown.length,
                      itemBuilder: (ctx, i) {
                        if (i == 0) return _header(t, streak, words);
                        final otdLen = _onThisDay.length;
                        if (i <= otdLen) return _onThisDayCard(_onThisDay[i - 1], t);
                        return _entryCard(shown[i - 1 - otdLen], t);
                      },
                    ),
                  ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _closeFab,
      child: Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(
          backgroundColor: t.appBarBg,
          title: Text(
            'DevineJournal',
            style: GoogleFonts.cinzelDecorative(color: t.appBarFg, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.3),
          ),
          actions: [
            IconButton(
              icon: Icon(_showSearch ? Icons.search_off : Icons.search, color: t.appBarFg, size: 20),
              onPressed: () {
                setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) { _searchQuery = ''; _searchCtrl.clear(); }
                });
              },
            ),
            IconButton(
              icon: Icon(
                _showFavoritesOnly ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _showFavoritesOnly ? const Color(0xFFf48fb1) : t.appBarFg,
                size: 20,
              ),
              onPressed: () => setState(() => _showFavoritesOnly = !_showFavoritesOnly),
              tooltip: _showFavoritesOnly ? 'All entries' : 'Favorites',
            ),
            IconButton(
              icon: Icon(Icons.calendar_month_outlined, color: t.appBarFg, size: 20),
              tooltip: 'Mood calendar',
              onPressed: _loading ? null : _openCalendar,
            ),
            InkWell(
              onTap: _pickTheme,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                child: Row(
                  children: allPaperThemes.map((pt) => Container(
                    width: 9, height: 9,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: pt.dot,
                      shape: BoxShape.circle,
                      border: pt.id == _t.id ? Border.all(color: Colors.white, width: 1.5) : null,
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
                    child: CircleAvatar(radius: 14, backgroundImage: NetworkImage(AuthService.userPic!)),
                  ),
                ),
              )
            else
              IconButton(icon: Icon(Icons.logout, color: _t.muted, size: 18), tooltip: 'Sign out', onPressed: _signOut),
          ],
        ),
        floatingActionButton: _buildFab(_t),
        body: showStars ? StarField(starColor: starColor, count: 80, child: body) : body,
      ),
    );
  }

  // ── FAB ───────────────────────────────────────────────────────────────────

  Widget _buildFab(PaperTheme t) {
    final isDark = t.brightness == Brightness.dark;
    final fg = isDark ? t.bg : Colors.white;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSlide(
          offset: _fabExpanded ? Offset.zero : const Offset(0, 0.5),
          duration: const Duration(milliseconds: 180),
          child: AnimatedOpacity(
            opacity: _fabExpanded ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FloatingActionButton.extended(
                heroTag: 'fab_gratitude',
                onPressed: _fabExpanded ? _openGratitude : null,
                backgroundColor: const Color(0xFFf8df6e),
                foregroundColor: const Color(0xFF2d1a0e),
                elevation: 3,
                icon: const Text('✨', style: TextStyle(fontSize: 16)),
                label: Text('Gratitude', style: GoogleFonts.cinzelDecorative(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
        AnimatedSlide(
          offset: _fabExpanded ? Offset.zero : const Offset(0, 0.5),
          duration: const Duration(milliseconds: 200),
          child: AnimatedOpacity(
            opacity: _fabExpanded ? 1 : 0,
            duration: const Duration(milliseconds: 160),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FloatingActionButton.extended(
                heroTag: 'fab_entry',
                onPressed: _fabExpanded ? _newEntry : null,
                backgroundColor: t.accent,
                foregroundColor: fg,
                elevation: 3,
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: Text('New Entry', style: GoogleFonts.cinzelDecorative(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
        RotationTransition(
          turns: _fabRotate,
          child: FloatingActionButton(
            heroTag: 'fab_main',
            onPressed: _toggleFab,
            backgroundColor: t.accent,
            foregroundColor: fg,
            child: const Icon(Icons.add, size: 26),
          ),
        ),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _header(PaperTheme t, int streak, int words) {
    final now = DateTime.now();
    final moon = moonPhaseEmoji(now);
    final dateStr = DateFormat('EEEE, MMMM d').format(now);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(moon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_greeting, $_firstName',
                      style: GoogleFonts.cormorant(
                        color: t.heading, fontSize: 24,
                        fontWeight: FontWeight.w600, fontStyle: FontStyle.italic,
                      ),
                    ),
                    Text(dateStr, style: TextStyle(color: t.muted, fontSize: 13)),
                  ],
                ),
              ),
              if (streak > 0) _badge(streak >= 7 ? '🔥' : '✦', streak == 1 ? '1 day' : '$streak days', t),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '"${todaysAffirmation()}"',
            style: GoogleFonts.lora(color: t.muted, fontSize: 13, fontStyle: FontStyle.italic, height: 1.55),
          ),
          if (words > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _statPill('${_entries.length}', 'entries', t),
                const SizedBox(width: 6),
                _statPill('$words', 'words', t),
                const SizedBox(width: 6),
                _statPill('${moonPhaseEmoji(now)} ${moonPhaseName(now)}', '', t, combined: true),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String icon, String label, PaperTheme t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: t.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.accent.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(icon, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: t.accent, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _statPill(String val, String label, PaperTheme t, {bool combined = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: t.border.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        combined ? val : '$val $label',
        style: TextStyle(color: t.muted, fontSize: 12),
      ),
    );
  }

  // ── On This Day card ──────────────────────────────────────────────────────

  Widget _onThisDayCard(Map<String, dynamic> entry, PaperTheme t) {
    final date = DateTime.tryParse(entry['created_at'] as String? ?? '')?.toLocal();
    final yearsAgo = date != null ? DateTime.now().year - date.year : 0;
    final title = entry['title'] as String? ?? 'Untitled';
    final body = entry['body'] as String? ?? '';
    final preview = body.length > 100 ? '${body.substring(0, 100)}…' : body;
    final mood = entry['mood'] as String? ?? '';
    final moodColor = _moodColors[mood] ?? t.accent;

    return GestureDetector(
      onTap: () => _openEntry(entry),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [t.accent.withValues(alpha: 0.08), t.card],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.accent.withValues(alpha: 0.3), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('📅', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 6),
                Text(
                  '${yearsAgo == 1 ? '1 year' : '$yearsAgo years'} ago today',
                  style: TextStyle(color: t.accent, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
                const Spacer(),
                if (mood.isNotEmpty)
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: moodColor.withValues(alpha: 0.15), shape: BoxShape.circle,
                    ),
                    child: Center(child: Text(mood, style: const TextStyle(fontSize: 14))),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title.isNotEmpty ? title : 'Untitled',
              style: GoogleFonts.cormorant(color: t.heading, fontSize: 18, fontWeight: FontWeight.w700, fontStyle: FontStyle.italic),
            ),
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(preview, style: TextStyle(color: t.ink.withValues(alpha: 0.65), fontSize: 13, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _emptyState(PaperTheme t) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🌙', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 20),
        Text('Your journal awaits',
          style: GoogleFonts.cormorant(color: t.heading, fontSize: 28, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic)),
        const SizedBox(height: 8),
        Text('Tap + below to write your first entry', style: TextStyle(color: t.muted, fontSize: 14)),
      ]),
    );
  }

  // ── Entry card ────────────────────────────────────────────────────────────

  Widget _entryCard(Map<String, dynamic> entry, PaperTheme t) {
    final date = DateTime.tryParse(entry['created_at'] as String? ?? '');
    final month = date != null ? DateFormat('MMM').format(date.toLocal()) : '';
    final day   = date != null ? DateFormat('d').format(date.toLocal())   : '';
    final year  = date != null ? DateFormat('yyyy').format(date.toLocal()) : '';
    final mood  = entry['mood'] as String? ?? '';
    final title = entry['title'] as String? ?? '';
    final body  = entry['body'] as String? ?? '';
    final tagsRaw = entry['tags'] as String? ?? '';
    final tags  = tagsRaw.isNotEmpty
        ? tagsRaw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).take(3).toList()
        : <String>[];
    final preview = body.length > 130 ? '${body.substring(0, 130)}…' : body;
    final moodColor = _moodColors[mood] ?? t.accent;
    final sealed = _isSealed(entry);
    final isFav = entry['is_favorite'] == true;

    return GestureDetector(
      onTap: () => _openEntry(entry),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: sealed ? t.card.withValues(alpha: 0.7) : t.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: sealed ? t.muted.withValues(alpha: 0.3) : t.border,
            width: 0.7,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date column
            Container(
              width: 60,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: sealed
                    ? t.muted.withValues(alpha: 0.08)
                    : (mood.isNotEmpty ? moodColor.withValues(alpha: 0.11) : t.border.withValues(alpha: 0.25)),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
                border: Border(right: BorderSide(color: t.border, width: 0.5)),
              ),
              child: Column(children: [
                if (sealed)
                  const Text('🔒', style: TextStyle(fontSize: 20))
                else ...[
                  Text(month.toUpperCase(),
                    style: TextStyle(color: mood.isNotEmpty ? moodColor : t.muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                  const SizedBox(height: 2),
                  Text(day,
                    style: GoogleFonts.cinzelDecorative(color: t.heading, fontSize: 22, fontWeight: FontWeight.w700, height: 1)),
                  const SizedBox(height: 2),
                  Text(year, style: TextStyle(color: t.muted, fontSize: 10)),
                ],
              ]),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          sealed ? 'Sealed memory' : (title.isNotEmpty ? title : 'Untitled'),
                          style: GoogleFonts.cormorant(
                            color: sealed ? t.muted : (title.isNotEmpty ? t.heading : t.muted),
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            fontStyle: (sealed || title.isEmpty) ? FontStyle.italic : FontStyle.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isFav)
                        Padding(
                          padding: const EdgeInsets.only(left: 5),
                          child: Icon(Icons.favorite_rounded, size: 14, color: Color(0xFFf48fb1)),
                        ),
                      if (mood.isNotEmpty && !sealed)
                        GestureDetector(
                          onTap: () => setState(() => _activeMood = mood == _activeMood ? null : mood),
                          child: Container(
                            width: 28, height: 28,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: moodColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: moodColor.withValues(alpha: 0.4), width: 0.7),
                            ),
                            child: Center(child: Text(mood, style: const TextStyle(fontSize: 14))),
                          ),
                        ),
                    ]),

                    const SizedBox(height: 4),
                    if (sealed) ...[
                      Builder(builder: (_) {
                        final lu = DateTime.tryParse(entry['locked_until'] as String? ?? '');
                        return Text(
                          lu != null ? 'Opens ${DateFormat('MMM d, yyyy').format(lu.toLocal())}' : 'Sealed',
                          style: TextStyle(color: t.muted, fontSize: 13, fontStyle: FontStyle.italic),
                        );
                      }),
                    ] else if (preview.isNotEmpty) ...[
                      Text(preview,
                        style: TextStyle(color: t.ink.withValues(alpha: 0.65), fontSize: 13, height: 1.5),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    if (tags.isNotEmpty && !sealed) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        children: tags.map((tag) => GestureDetector(
                          onTap: () => setState(() => _activeTag = tag),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: t.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: t.accent.withValues(alpha: 0.25), width: 0.6),
                            ),
                            child: Text('#$tag', style: TextStyle(color: t.accent, fontSize: 12, fontWeight: FontWeight.w600)),
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
                color: sealed ? t.muted.withValues(alpha: 0.25) : (mood.isNotEmpty ? moodColor.withValues(alpha: 0.6) : t.border),
                borderRadius: const BorderRadius.only(topRight: Radius.circular(14), bottomRight: Radius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Theme Picker ──────────────────────────────────────────────────────────────

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
          Text('Choose your paper',
            style: GoogleFonts.cormorant(color: t.heading, fontSize: 24, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (_, constraints) {
            final cardW = (constraints.maxWidth - 8 * 3) / 4;
            return Wrap(
              spacing: 8, runSpacing: 10,
              children: allPaperThemes.map((pt) =>
                SizedBox(width: cardW, child: _card(pt, t, context))
              ).toList(),
            );
          }),
        ],
      ),
    );
  }

  Widget _card(PaperTheme pt, PaperTheme cur, BuildContext context) {
    final sel = pt.id == cur.id;
    return GestureDetector(
      onTap: () { onSelect(pt); Navigator.of(context).pop(); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: pt.paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? pt.accent : pt.border, width: sel ? 2.0 : 0.7),
          boxShadow: sel ? [BoxShadow(color: pt.accent.withValues(alpha: 0.2), blurRadius: 8)] : [],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 22, height: 22, decoration: BoxDecoration(color: pt.dot, shape: BoxShape.circle)),
          const SizedBox(height: 6),
          Text(pt.name, style: TextStyle(color: pt.ink, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          if (sel) ...[const SizedBox(height: 3), Icon(Icons.check_circle, size: 12, color: pt.accent)],
        ]),
      ),
    );
  }
}
