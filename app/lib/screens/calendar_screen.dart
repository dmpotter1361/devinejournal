import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/theme_service.dart';
import '../utils/moon_phase.dart';
import 'entry_screen.dart';

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

const _daysFull   = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
const _daysShort  = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
const _daysMini   = ['Su','Mo','Tu','We','Th','Fr','Sa'];

class CalendarScreen extends StatefulWidget {
  final List<Map<String, dynamic>> entries;
  final VoidCallback onRefresh;

  const CalendarScreen({
    super.key,
    required this.entries,
    required this.onRefresh,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  Map<String, List<Map<String, dynamic>>> get _entriesByDate {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final e in widget.entries) {
      final d = DateTime.tryParse(e['created_at'] as String? ?? '');
      if (d == null) continue;
      final local = d.toLocal();
      final key =
          '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(e);
    }
    return map;
  }

  void _prevMonth() =>
      setState(() => _month = DateTime(_month.year, _month.month - 1));
  void _nextMonth() =>
      setState(() => _month = DateTime(_month.year, _month.month + 1));

  Future<void> _openEntry(Map<String, dynamic> entry) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EntryScreen(entry: entry)),
    );
    if (changed == true) widget.onRefresh();
  }

  Future<void> _showDayEntries(
      List<Map<String, dynamic>> entries, DateTime date) async {
    final t = ThemeService.current;
    await showModalBottomSheet(
      context: context,
      backgroundColor: t.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: t.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              DateFormat('EEEE, MMMM d').format(date),
              style: GoogleFonts.cormorant(
                  color: t.heading,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic),
            ),
          ),
          ...entries.map((e) {
            final mood = e['mood'] as String? ?? '';
            final title = (e['title'] as String? ?? '').trim();
            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: mood.isNotEmpty
                  ? Text(mood, style: const TextStyle(fontSize: 28))
                  : Icon(Icons.book_outlined, color: t.muted, size: 28),
              title: Text(
                title.isNotEmpty ? title : 'Untitled entry',
                style: TextStyle(
                    color: t.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                DateFormat('h:mm a').format(
                    DateTime.tryParse(e['created_at'] as String? ?? '')
                            ?.toLocal() ??
                        date),
                style: TextStyle(color: t.muted, fontSize: 15),
              ),
              onTap: () {
                Navigator.pop(context);
                _openEntry(e);
              },
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeService.current;
    final byDate = _entriesByDate;
    final firstDay = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // 0=Sun
    final today = DateTime.now();
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final cells = <Widget>[];
    for (var i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final key =
          '${_month.year}-${_month.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      final dayEntries = byDate[key] ?? [];
      final date = DateTime(_month.year, _month.month, d);
      final isToday = key == todayKey;
      final phase = moonPhaseEmoji(date);

      final moods = dayEntries
          .map((e) => e['mood'] as String? ?? '')
          .where((m) => m.isNotEmpty)
          .toList();

      final primaryMoodColor = moods.isNotEmpty
          ? (_moodColors[moods.first] ?? t.accent)
          : null;

      cells.add(_DayCell(
        day: d,
        entries: dayEntries,
        moods: moods,
        moodColor: primaryMoodColor,
        moonPhase: phase,
        isToday: isToday,
        theme: t,
        onTap: dayEntries.isEmpty
            ? null
            : dayEntries.length == 1
                ? () => _openEntry(dayEntries.first)
                : () => _showDayEntries(dayEntries, date),
      ));
    }

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.appBarBg,
        foregroundColor: t.appBarFg,
        title: Text(
          'Mood Calendar',
          style: GoogleFonts.cinzelDecorative(
              color: t.appBarFg, fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // Month navigation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: t.appBarBg,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: t.appBarFg, size: 28),
                  onPressed: _prevMonth,
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_month).toUpperCase(),
                  style: GoogleFonts.cinzelDecorative(
                      color: t.appBarFg,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: t.appBarFg, size: 28),
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),

          // Day-of-week header (responsive: full names on wide, short on narrow)
          Container(
            color: t.card,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: LayoutBuilder(
              builder: (ctx, bc) {
                final cellW = bc.maxWidth / 7;
                final labels = cellW >= 110
                    ? _daysFull
                    : cellW >= 65
                        ? _daysShort
                        : _daysMini;
                return Row(
                  children: labels
                      .map((d) => Expanded(
                            child: Center(
                              child: Text(
                                d,
                                style: TextStyle(
                                    color: t.muted,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ),
          Divider(color: t.border, height: 0.5, thickness: 0.5),

          // Calendar grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: GridView.count(
                crossAxisCount: 7,
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
                childAspectRatio: 0.9,
                children: cells,
              ),
            ),
          ),

          _MoodLegend(theme: t),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final List<Map<String, dynamic>> entries;
  final List<String> moods;
  final Color? moodColor;
  final String moonPhase;
  final bool isToday;
  final dynamic theme;
  final VoidCallback? onTap;

  const _DayCell({
    required this.day,
    required this.entries,
    required this.moods,
    required this.moodColor,
    required this.moonPhase,
    required this.isToday,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final hasEntries = entries.isNotEmpty;
    final bg = moodColor?.withValues(alpha: 0.18) ?? Colors.transparent;
    final borderColor = isToday
        ? (t.accent as Color)
        : moodColor?.withValues(alpha: 0.55) ?? (t.border as Color);
    final borderWidth = isToday ? 2.5 : (hasEntries ? 1.2 : 0.5);
    final displayMoods = moods.toSet().take(3).toList();
    final extraCount = entries.length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: LayoutBuilder(builder: (ctx, bc) {
          // Scale emoji and text to the actual cell size
          final cellH = bc.maxHeight;
          final emojiSz = cellH < 70
              ? (displayMoods.length > 1 ? 14.0 : 18.0)
              : cellH < 110
                  ? (displayMoods.length > 1 ? 20.0 : 26.0)
                  : (displayMoods.length > 1 ? 24.0 : 32.0);
          final daySz = cellH < 70
              ? 14.0
              : cellH < 110
                  ? 20.0
                  : 26.0;
          final moonSz = cellH < 70 ? 11.0 : 16.0;
          final badgeSz = cellH < 70 ? 11.0 : 15.0;
          final pad = cellH < 70 ? 3.0 : 6.0;

          return Column(
            children: [
              // Top row: entry count badge + moon phase
              Padding(
                padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    extraCount > 1
                        ? Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: pad, vertical: 1),
                            decoration: BoxDecoration(
                              color: (moodColor ?? t.accent as Color)
                                  .withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$extraCount',
                              style: TextStyle(
                                  color: moodColor ?? t.accent as Color,
                                  fontSize: badgeSz,
                                  fontWeight: FontWeight.w800),
                            ),
                          )
                        : SizedBox(width: badgeSz),
                    Text(
                      moonPhase,
                      style: TextStyle(
                          fontSize: moonSz,
                          color: (t.muted as Color)
                              .withValues(alpha: hasEntries ? 0.65 : 0.4)),
                    ),
                  ],
                ),
              ),

              // Middle: mood emojis (take remaining space)
              Expanded(
                child: Center(
                  child: displayMoods.isNotEmpty
                      ? Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 1,
                          children: displayMoods
                              .map((m) =>
                                  Text(m, style: TextStyle(fontSize: emojiSz)))
                              .toList(),
                        )
                      : const SizedBox(),
                ),
              ),

              // Day number — prominent, at bottom
              Padding(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
                child: Text(
                  '$day',
                  style: TextStyle(
                    color: hasEntries
                        ? (moodColor ?? t.heading as Color)
                        : (t.muted as Color),
                    fontSize: daySz,
                    fontWeight:
                        hasEntries ? FontWeight.w800 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _MoodLegend extends StatelessWidget {
  final dynamic theme;
  const _MoodLegend({required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final moods = ['✨', '🌙', '🌸', '🔥', '💫', '🌿', '💜', '🌊', '🌻', '🦋'];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
      color: t.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: t.border, height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: moods.map((m) {
              final c = _moodColors[m] ?? t.accent;
              return Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(m, style: const TextStyle(fontSize: 18)),
              ]);
            }).toList(),
          ),
        ],
      ),
    );
  }
}
