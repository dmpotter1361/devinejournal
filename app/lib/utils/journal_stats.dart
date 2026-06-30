int journalStreak(List<Map<String, dynamic>> entries) {
  if (entries.isEmpty) return 0;

  final days = entries
      .map((e) => DateTime.tryParse(e['created_at'] as String? ?? ''))
      .whereType<DateTime>()
      .map((d) => DateTime(d.toLocal().year, d.toLocal().month, d.toLocal().day))
      .toSet()
      .toList()
    ..sort((a, b) => b.compareTo(a)); // newest first

  if (days.isEmpty) return 0;

  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final yesterday = todayDate.subtract(const Duration(days: 1));

  if (days.first != todayDate && days.first != yesterday) return 0;

  int streak = 1;
  for (var i = 1; i < days.length; i++) {
    if (days[i - 1].difference(days[i]).inDays == 1) {
      streak++;
    } else {
      break;
    }
  }
  return streak;
}

int totalWordCount(List<Map<String, dynamic>> entries) {
  return entries.fold(0, (sum, e) {
    final body = (e['body'] as String? ?? '').trim();
    if (body.isEmpty) return sum;
    return sum + body.split(RegExp(r'\s+')).length;
  });
}
