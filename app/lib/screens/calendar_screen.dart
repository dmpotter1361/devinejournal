import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/theme_service.dart';
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
};

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

  Map<String, Map<String, dynamic>> get _entriesByDate {
    final map = <String, Map<String, dynamic>>{};
    for (final e in widget.entries) {
      final d = DateTime.tryParse(e['created_at'] as String? ?? '');
      if (d == null) continue;
      final local = d.toLocal();
      final key = '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => e);
    }
    return map;
  }

  void _prevMonth() => setState(() => _month = DateTime(_month.year, _month.month - 1));
  void _nextMonth() => setState(() => _month = DateTime(_month.year, _month.month + 1));

  @override
  Widget build(BuildContext context) {
    final t = ThemeService.current;
    final byDate = _entriesByDate;
    final firstDay = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // 0=Sun
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final cells = <Widget>[];
    for (var i = 0; i < startWeekday; i++) { cells.add(const SizedBox()); }
    for (var d = 1; d <= daysInMonth; d++) {
      final key = '${_month.year}-${_month.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      final entry = byDate[key];
      final mood = entry?['mood'] as String? ?? '';
      final moodColor = mood.isNotEmpty ? (_moodColors[mood] ?? t.accent) : null;
      final isToday = key == todayKey;

      cells.add(_DayCell(
        day: d,
        moodColor: moodColor,
        moodEmoji: mood,
        isToday: isToday,
        hasEntry: entry != null,
        theme: t,
        onTap: entry == null ? null : () async {
          final changed = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => EntryScreen(entry: entry)),
          );
          if (changed == true) widget.onRefresh();
        },
      ));
    }

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.appBarBg,
        foregroundColor: t.appBarFg,
        title: Text(
          'Mood Calendar',
          style: GoogleFonts.cinzelDecorative(color: t.appBarFg, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // Month nav
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: t.appBarBg,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: t.appBarFg),
                  onPressed: _prevMonth,
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_month),
                  style: GoogleFonts.cinzelDecorative(
                    color: t.appBarFg,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: t.appBarFg),
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),

          // Day header row
          Container(
            color: t.card,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Row(
              children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'].map((d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      color: t.muted,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              )).toList(),
            ),
          ),
          Divider(color: t.border, height: 0.5, thickness: 0.5),

          // Calendar grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: GridView.count(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                children: cells,
              ),
            ),
          ),

          // Mood legend
          _MoodLegend(theme: t),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final Color? moodColor;
  final String moodEmoji;
  final bool isToday;
  final bool hasEntry;
  final dynamic theme;
  final VoidCallback? onTap;

  const _DayCell({
    required this.day,
    required this.moodColor,
    required this.moodEmoji,
    required this.isToday,
    required this.hasEntry,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final bg = moodColor?.withValues(alpha: 0.18) ?? Colors.transparent;
    final border = isToday
        ? Border.all(color: t.accent, width: 1.5)
        : moodColor != null
            ? Border.all(color: moodColor!.withValues(alpha: 0.5), width: 0.7)
            : Border.all(color: t.border, width: 0.4);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: border,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (moodEmoji.isNotEmpty)
              Text(moodEmoji, style: const TextStyle(fontSize: 20))
            else
              const SizedBox(height: 20),
            const SizedBox(height: 2),
            Text(
              '$day',
              style: TextStyle(
                color: hasEntry ? (moodColor ?? t.heading) : t.muted,
                fontSize: 16,
                fontWeight: hasEntry ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
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
    final moods = ['✨', '🌙', '🌸', '🔥', '💫', '🌿', '💜', '🌊'];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
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
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text(m, style: const TextStyle(fontSize: 16)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
