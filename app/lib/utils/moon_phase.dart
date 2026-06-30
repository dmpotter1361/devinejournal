String moonPhaseEmoji(DateTime date) {
  final epoch = DateTime.utc(2000, 1, 6); // known new moon
  final days = date.toUtc().difference(epoch).inDays;
  const cycle = 29.53058867;
  final phase = (days % cycle) / cycle;

  if (phase < 0.0625) return '🌑';
  if (phase < 0.1875) return '🌒';
  if (phase < 0.3125) return '🌓';
  if (phase < 0.4375) return '🌔';
  if (phase < 0.5625) return '🌕';
  if (phase < 0.6875) return '🌖';
  if (phase < 0.8125) return '🌗';
  if (phase < 0.9375) return '🌘';
  return '🌑';
}

String moonPhaseName(DateTime date) {
  final epoch = DateTime.utc(2000, 1, 6);
  final days = date.toUtc().difference(epoch).inDays;
  const cycle = 29.53058867;
  final phase = (days % cycle) / cycle;

  if (phase < 0.0625) return 'New Moon';
  if (phase < 0.1875) return 'Waxing Crescent';
  if (phase < 0.3125) return 'First Quarter';
  if (phase < 0.4375) return 'Waxing Gibbous';
  if (phase < 0.5625) return 'Full Moon';
  if (phase < 0.6875) return 'Waning Gibbous';
  if (phase < 0.8125) return 'Last Quarter';
  if (phase < 0.9375) return 'Waning Crescent';
  return 'New Moon';
}
