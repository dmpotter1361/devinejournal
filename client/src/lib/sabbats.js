// Wheel of the Year — the eight sabbats (Northern Hemisphere dates;
// solar festivals use their common fixed approximations).
export const SABBATS = [
  { month: 1,  day: 1,  name: 'Imbolc',     emoji: '🕯️' },
  { month: 2,  day: 20, name: 'Ostara',     emoji: '🌱' },
  { month: 4,  day: 1,  name: 'Beltane',    emoji: '🔥' },
  { month: 5,  day: 21, name: 'Litha',      emoji: '☀️' },
  { month: 7,  day: 1,  name: 'Lughnasadh', emoji: '🌾' },
  { month: 8,  day: 22, name: 'Mabon',      emoji: '🍂' },
  { month: 9,  day: 31, name: 'Samhain',    emoji: '🎃' },
  { month: 11, day: 21, name: 'Yule',       emoji: '❄️' },
];
// month is 0-indexed (JS Date convention)

export function sabbatOn(year, month, day) {
  return SABBATS.find(s => s.month === month && s.day === day) || null;
}

// Next upcoming sabbat from today: { name, emoji, daysAway }
export function nextSabbat(now = new Date()) {
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  let best = null;
  for (const s of SABBATS) {
    for (const y of [today.getFullYear(), today.getFullYear() + 1]) {
      const d = new Date(y, s.month, s.day);
      if (d >= today) {
        const daysAway = Math.round((d - today) / 86400000);
        if (!best || daysAway < best.daysAway) best = { ...s, daysAway };
        break;
      }
    }
  }
  return best;
}
