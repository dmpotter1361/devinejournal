// The Sky Today — real planetary positions (geocentric ecliptic longitude),
// computed from Keplerian orbital elements (JPL approximate ephemeris, J2000).
// Accuracy is within a degree or two — plenty for 30°-wide zodiac signs.

export const SIGNS = [
  { name: 'Aries',       glyph: '♈', flavor: 'bold, spark-lit beginnings' },
  { name: 'Taurus',      glyph: '♉', flavor: 'steady comfort and rooted pleasure' },
  { name: 'Gemini',      glyph: '♊', flavor: 'quick words and curious air' },
  { name: 'Cancer',      glyph: '♋', flavor: 'tides of memory and home' },
  { name: 'Leo',         glyph: '♌', flavor: 'warm, golden-hearted courage' },
  { name: 'Virgo',       glyph: '♍', flavor: 'quiet care in the small details' },
  { name: 'Libra',       glyph: '♎', flavor: 'balance, beauty, and fair winds' },
  { name: 'Scorpio',     glyph: '♏', flavor: 'deep water and honest shadows' },
  { name: 'Sagittarius', glyph: '♐', flavor: 'far horizons and wild hope' },
  { name: 'Capricorn',   glyph: '♑', flavor: 'patient mountains, built to last' },
  { name: 'Aquarius',    glyph: '♒', flavor: 'strange stars and new ideas' },
  { name: 'Pisces',      glyph: '♓', flavor: 'dream-tide and soft knowing' },
];

const rad = (d) => (d * Math.PI) / 180;
const norm = (d) => ((d % 360) + 360) % 360;

// a (AU), e, L (mean longitude °), peri (longitude of perihelion °) + per-century rates
const ELEMENTS = {
  mercury: { a: 0.38709927, e: 0.20563593, L: [252.25032350, 149472.67411175], peri: [77.45779628, 0.16047689] },
  venus:   { a: 0.72333566, e: 0.00677672, L: [181.97909950, 58517.81538729],  peri: [131.60246718, 0.00268329] },
  earth:   { a: 1.00000261, e: 0.01671123, L: [100.46457166, 35999.37244981],  peri: [102.93768193, 0.32327364] },
  mars:    { a: 1.52371034, e: 0.09339410, L: [-4.55343205, 19140.30268499],   peri: [-23.94362959, 0.44441088] },
};

const centuriesSinceJ2000 = (date) => (date.getTime() / 86400000 + 2440587.5 - 2451545.0) / 36525;

// Heliocentric ecliptic-plane position (planar approximation)
function helioXY(key, T) {
  const el = ELEMENTS[key];
  const L = norm(el.L[0] + el.L[1] * T);
  const peri = norm(el.peri[0] + el.peri[1] * T);
  const M = rad(norm(L - peri));
  let E = M;
  for (let i = 0; i < 6; i++) E = M + el.e * Math.sin(E);
  const nu = 2 * Math.atan2(
    Math.sqrt(1 + el.e) * Math.sin(E / 2),
    Math.sqrt(1 - el.e) * Math.cos(E / 2)
  );
  const r = el.a * (1 - el.e * Math.cos(E));
  const lon = nu + rad(peri);
  return { x: r * Math.cos(lon), y: r * Math.sin(lon) };
}

function geocentricLongitude(key, T) {
  const p = helioXY(key, T);
  const e = helioXY('earth', T);
  return norm((Math.atan2(p.y - e.y, p.x - e.x) * 180) / Math.PI);
}

// A planet is retrograde when its apparent (geocentric) longitude is moving
// backward through the zodiac. Compare a few days either side; the daily
// motion is small so a signed diff over 4 days reveals the direction.
function isRetrograde(key, T) {
  const dT = 2 / 36525; // 2 days, in Julian centuries
  let d = geocentricLongitude(key, T + dT) - geocentricLongitude(key, T - dT);
  if (d > 180) d -= 360;
  if (d < -180) d += 360;
  return d < 0;
}

// Retrograde meaning per inner planet (Sun & Moon never go retrograde)
const RETRO_FLAVOR = {
  Mercury: 'reread, revisit, and speak with care',
  Venus: 'old loves and values return for a second look',
  Mars: 'bank your fire — act from patience, not haste',
};

// Truncated lunar longitude (Meeus) — good to ~1–2°
function moonLongitude(date) {
  const d = date.getTime() / 86400000 + 2440587.5 - 2451545.0;
  const L = 218.316 + 13.176396 * d;
  const M = rad(134.963 + 13.064993 * d);
  return norm(L + 6.289 * Math.sin(M));
}

export function skyToday(date = new Date()) {
  const T = centuriesSinceJ2000(date);
  const e = helioXY('earth', T);
  const sunLon = norm((Math.atan2(-e.y, -e.x) * 180) / Math.PI);

  const bodies = [
    { name: 'Sun',     glyph: '☉', theme: 'The Sun — your light and center',      lon: sunLon,                             retro: false },
    { name: 'Moon',    glyph: '☽', theme: 'The Moon — your inner tide',           lon: moonLongitude(date),                retro: false },
    { name: 'Mercury', glyph: '☿', theme: 'Mercury — the messenger of thought',   lon: geocentricLongitude('mercury', T),  retro: isRetrograde('mercury', T) },
    { name: 'Venus',   glyph: '♀', theme: 'Venus — the heart, love and beauty',   lon: geocentricLongitude('venus', T),    retro: isRetrograde('venus', T) },
    { name: 'Mars',    glyph: '♂', theme: 'Mars — the fire of will and courage',  lon: geocentricLongitude('mars', T),     retro: isRetrograde('mars', T) },
  ];
  return bodies.map(b => ({ ...b, sign: SIGNS[Math.floor(norm(b.lon) / 30)] }));
}

// The most poetic retrograde note today, or null. Mercury takes precedence
// (it's the one everyone feels), then Venus, then Mars.
export function retrogradeNote(date = new Date()) {
  const order = ['Mercury', 'Venus', 'Mars'];
  const sky = skyToday(date);
  for (const name of order) {
    const b = sky.find(x => x.name === name);
    if (b && b.retro) return { name, glyph: b.glyph, text: `${name} is retrograde — ${RETRO_FLAVOR[name]}.` };
  }
  return null;
}

// One placement featured per day (date-seeded — the sky is a fixed fact,
// which voice reads it out simply rotates)
export function featuredPlacement(date = new Date()) {
  const sky = skyToday(date);
  const seed = date.getFullYear() * 372 + date.getMonth() * 31 + date.getDate();
  const b = sky[seed % sky.length];
  return { ...b, meaning: `${b.theme}, now in ${b.sign.name}: ${b.sign.flavor}.` };
}
