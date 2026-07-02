// Lunar cycle helper for the New Moon → Full Moon intention practice.
const SYNODIC = 29.530588853;              // mean synodic month (days)
const MS_DAY = 86400000;
const REF_NEW_MOON = Date.UTC(2000, 0, 6, 18, 14); // known new moon, 2000-01-06 18:14 UTC

// cycle = which lunation (integer, constant across a whole month)
// age   = days since the last new moon (0 = new, ~14.77 = full)
export function lunarInfo(date = new Date()) {
  const days = (date.getTime() - REF_NEW_MOON) / MS_DAY;
  const cycle = Math.floor(days / SYNODIC);
  const age = ((days % SYNODIC) + SYNODIC) % SYNODIC;
  return { cycle, age };
}

export const isNewMoonWindow = (age) => age <= 3;               // first 3 days after new
export const isFullMoonWindow = (age) => age >= 13 && age <= 17; // around the full moon

// Northern-hemisphere phase emoji + name from the lunar age.
const PHASES = [
  { emoji: '🌑', name: 'New Moon' },
  { emoji: '🌒', name: 'Waxing Crescent' },
  { emoji: '🌓', name: 'First Quarter' },
  { emoji: '🌔', name: 'Waxing Gibbous' },
  { emoji: '🌕', name: 'Full Moon' },
  { emoji: '🌖', name: 'Waning Gibbous' },
  { emoji: '🌗', name: 'Last Quarter' },
  { emoji: '🌘', name: 'Waning Crescent' },
];

export function moonPhase(date = new Date()) {
  const { age } = lunarInfo(date);
  const idx = Math.round((age / SYNODIC) * 8) % 8; // 0=new … 4=full
  return PHASES[idx];
}
