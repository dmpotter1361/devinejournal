// Perennial Gratitude Garden — shared logic for the Timeline widget and the
// full Garden page. Every CYCLE_DAYS written days of gratitude grows one
// permanent bloom; everything is derived from entry history (nothing stored).

export const FLOWERS = ['🌻', '🌷', '🌹', '🌸', '🌺', '🪻', '🌼', '💐'];
export const CYCLE_DAYS = 21;
export const MS_DAY = 86400000;

export const GARDEN_STAGES = [
  { emoji: '',   size: 0,  label: 'Plant your first seed' },
  { emoji: '🌱', size: 26, label: 'seedling' },
  { emoji: '🌿', size: 32, label: 'sprouting' },
  { emoji: '🌷', size: 40, label: 'budding' },
  { emoji: '🌸', size: 48, label: 'blossoming' },
  { emoji: '🌺', size: 56, label: 'in full bloom' },
];

export function getStage(days) {
  if (days === 0) return 0;
  if (days === 1) return 1;
  if (days <= 3) return 2;
  if (days <= 6) return 3;
  if (days <= 13) return 4;
  return 5;
}

export const isGratitude = (e) =>
  (e.tags || '').toLowerCase().split(',').map(t => t.trim()).includes('gratitude');

const dayKey = (v) => { const x = new Date(v); x.setHours(0, 0, 0, 0); return x.getTime(); };

// Template prompts that shouldn't count as real gratitude lines
const TEMPLATE_LINES = [
  'Today I am grateful for…',
  'A small joy I noticed today…',
  'Someone I appreciate right now…',
];

// Extract the individual gratitude lines from an entry body (HTML or plain).
export function gratitudeLines(body) {
  if (!body) return [];
  const withBreaks = body
    .replace(/<\/(p|li|div|h[1-6])>/gi, '\n')
    .replace(/<br[^>]*>/gi, '\n');
  const tmp = document.createElement('div');
  tmp.innerHTML = withBreaks;
  return (tmp.textContent || '')
    .split('\n')
    .map(l => l.replace(/^\d+\.\s*/, '').trim())
    .filter(l => l && !TEMPLATE_LINES.includes(l));
}

export function bloomMonth(b) {
  return new Date(b.end).toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
}

export function buildGarden(gratEntries) {
  const days = [...new Set(gratEntries.map(e => dayKey(e.created_at)))].sort((a, b) => a - b);
  const today = dayKey(Date.now());

  // Split into runs; a single missed day (gap ≤ 2) rests the plant, never kills it
  const runs = [];
  for (const d of days) {
    const run = runs[runs.length - 1];
    if (run && (d - run[run.length - 1]) / MS_DAY <= 2) run.push(d);
    else runs.push([d]);
  }

  const blooms = [];
  for (const run of runs) {
    for (let n = CYCLE_DAYS; n <= run.length; n += CYCLE_DAYS) {
      const start = run[n - CYCLE_DAYS];
      const end = run[n - 1];
      const cycleEntries = gratEntries.filter(e => {
        const k = dayKey(e.created_at);
        return k >= start && k <= end;
      });
      const entry = cycleEntries[0];
      // A real gratitude line from this cycle, for nostalgia nudges
      let sampleLine = '';
      for (const ce of cycleEntries) {
        const lines = gratitudeLines(ce.body);
        if (lines.length) { sampleLine = lines[0]; break; }
      }
      blooms.push({
        emoji: FLOWERS[blooms.length % FLOWERS.length],
        start,
        end,
        entryId: entry?.id,
        sampleLine,
      });
    }
  }

  const lastRun = runs[runs.length - 1] || [];
  const lastDay = lastRun[lastRun.length - 1];
  const sinceLast = lastDay === undefined ? Infinity : (today - lastDay) / MS_DAY;
  const alive = sinceLast <= 2;
  return {
    blooms,
    runs,
    currentDays: alive ? lastRun.length % CYCLE_DAYS : 0,
    resting: alive && sinceLast >= 1,
    alive,
    hadAny: days.length > 0,
  };
}

// The entries (with their lines) that grew a given bloom — for the Garden page.
export function bloomEntries(bloom, gratEntries) {
  return gratEntries
    .filter(e => {
      const k = dayKey(e.created_at);
      return k >= bloom.start && k <= bloom.end;
    })
    .sort((a, b) => new Date(a.created_at) - new Date(b.created_at))
    .map(e => ({ entry: e, lines: gratitudeLines(e.body) }));
}
