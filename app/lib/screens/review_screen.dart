import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/theme_service.dart';

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

class ReviewScreen extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  const ReviewScreen({super.key, required this.entries});

  // ── Stat helpers ────────────────────────────────────────────────────────────

  int _wordCount(Map<String, dynamic> e) {
    final body = (e['body'] as String? ?? '').trim();
    if (body.isEmpty) return 0;
    return body.split(RegExp(r'\s+')).length;
  }

  Map<int, List<Map<String, dynamic>>> _byMonth() {
    final map = <int, List<Map<String, dynamic>>>{};
    for (final e in entries) {
      final dt = DateTime.tryParse(e['created_at'] as String? ?? '');
      if (dt == null) continue;
      final m = dt.toLocal().month;
      map.putIfAbsent(m, () => []).add(e);
    }
    return map;
  }

  String _topMood() {
    final counts = <String, int>{};
    for (final e in entries) {
      final m = e['mood'] as String? ?? '';
      if (m.isNotEmpty) counts[m] = (counts[m] ?? 0) + 1;
    }
    if (counts.isEmpty) return '';
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  List<MapEntry<String, int>> _topTags() {
    final counts = <String, int>{};
    for (final e in entries) {
      final tags = (e['tags'] as String? ?? '');
      for (final tag in tags.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value - a.value);
    return sorted.take(5).toList();
  }

  int _longestStreak() {
    if (entries.isEmpty) return 0;
    final days = entries
        .map((e) => DateTime.tryParse(e['created_at'] as String? ?? ''))
        .whereType<DateTime>()
        .map((d) => DateTime(d.toLocal().year, d.toLocal().month, d.toLocal().day))
        .toSet()
        .toList()
      ..sort();
    if (days.isEmpty) return 0;
    int best = 1, cur = 1;
    for (var i = 1; i < days.length; i++) {
      if (days[i].difference(days[i - 1]).inDays == 1) {
        cur++;
        if (cur > best) best = cur;
      } else {
        cur = 1;
      }
    }
    return best;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = ThemeService.current;
    final byMonth = _byMonth();
    final maxMonthEntries = byMonth.values.fold(0, (m, v) => m > v.length ? m : v.length);
    final totalWords = entries.fold(0, (s, e) => s + _wordCount(e));
    final topMood = _topMood();
    final topTags = _topTags();
    final streak = _longestStreak();
    final year = DateTime.now().year;

    const monthAbbr = ['', 'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.appBarBg,
        foregroundColor: t.appBarFg,
        title: Text('Year in Review — $year',
            style: GoogleFonts.cinzelDecorative(color: t.appBarFg, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('📖', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 16),
                    Text('No entries yet this year.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cormorant(color: t.heading, fontSize: 20, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 8),
                    Text('Write your first entry to see your journey unfold.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: t.muted, fontSize: 14)),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top-line stats ───────────────────────────────────────
                  Row(
                    children: [
                      _statCard(t, '${entries.length}', 'entries', '📝'),
                      const SizedBox(width: 10),
                      _statCard(t, '$totalWords', 'words', '✍️'),
                      const SizedBox(width: 10),
                      _statCard(t, '$streak', 'day streak', '🔥'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Monthly bar chart ─────────────────────────────────────
                  _sectionLabel(t, 'Monthly activity'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: _cardDecor(t),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(12, (i) {
                        final m = i + 1;
                        final count = byMonth[m]?.length ?? 0;
                        final barH = maxMonthEntries > 0
                            ? (count / maxMonthEntries * 90).clamp(4.0, 90.0)
                            : 4.0;
                        final hasEntries = count > 0;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (count > 0)
                              Text('$count',
                                  style: TextStyle(color: t.muted, fontSize: 9, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 600),
                              width: 14,
                              height: hasEntries ? barH : 4,
                              decoration: BoxDecoration(
                                color: hasEntries
                                    ? t.accent.withValues(alpha: 0.85)
                                    : t.border,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(monthAbbr[m],
                                style: TextStyle(color: t.muted, fontSize: 9)),
                          ],
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Top mood ─────────────────────────────────────────────
                  if (topMood.isNotEmpty) ...[
                    _sectionLabel(t, 'Dominant mood'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: _cardDecor(t),
                      child: Row(
                        children: [
                          Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(
                              color: (_moodColors[topMood] ?? t.accent).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Center(child: Text(topMood, style: const TextStyle(fontSize: 28))),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text('You carried this feeling most through $year.',
                                style: GoogleFonts.lora(color: t.ink, fontSize: 14, height: 1.55,
                                    fontStyle: FontStyle.italic)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Mood palette heat strip ───────────────────────────────
                  _moodHeatStrip(t),
                  const SizedBox(height: 20),

                  // ── Top tags ─────────────────────────────────────────────
                  if (topTags.isNotEmpty) ...[
                    _sectionLabel(t, 'Most used tags'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: _cardDecor(t),
                      child: Column(
                        children: topTags.map((e) {
                          final pct = entries.isEmpty ? 0.0 : e.value / entries.length;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                SizedBox(width: 90,
                                    child: Text('#${e.key}',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: t.accent, fontSize: 13, fontWeight: FontWeight.w600))),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: pct.clamp(0.0, 1.0),
                                      minHeight: 7,
                                      backgroundColor: t.border,
                                      color: t.accent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('${e.value}',
                                    style: TextStyle(color: t.muted, fontSize: 12)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _moodHeatStrip(dynamic t) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final moodByDay = <DateTime, String>{};
    for (final e in entries) {
      final dt = DateTime.tryParse(e['created_at'] as String? ?? '');
      if (dt == null) continue;
      final d = DateTime(dt.toLocal().year, dt.toLocal().month, dt.toLocal().day);
      final m = e['mood'] as String? ?? '';
      if (m.isNotEmpty) moodByDay[d] = m;
    }
    if (moodByDay.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(t, 'Mood landscape'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: _cardDecor(t),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: moodByDay.entries.toList().map((e) {
                final c = _moodColors[e.value] ?? t.accent;
                return Tooltip(
                  message: '${e.value} ${e.key.month}/${e.key.day}',
                  child: Container(
                    width: 12, height: 22,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statCard(dynamic t, String value, String label, String emoji) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: _cardDecor(t),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.cinzelDecorative(
                    color: t.heading, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: t.muted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(dynamic t, String label) {
    return Text(label.toUpperCase(),
        style: TextStyle(
            color: t.muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1));
  }

  BoxDecoration _cardDecor(dynamic t) {
    return BoxDecoration(
      color: t.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: t.border, width: 0.6),
    );
  }
}
