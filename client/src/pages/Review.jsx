import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api';
import { moodColor } from '../moods';
import './Review.css';

const MONTH_ABBR = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

const plainWords = (html) => {
  if (!html) return 0;
  const tmp = document.createElement('div');
  tmp.innerHTML = html;
  const t = (tmp.textContent || '').trim();
  return t ? t.split(/\s+/).length : 0;
};

function longestStreak(entries) {
  const days = [...new Set(entries.map(e => { const d = new Date(e.created_at); d.setHours(0, 0, 0, 0); return d.getTime(); }))].sort((a, b) => a - b);
  let best = days.length ? 1 : 0, cur = 1;
  for (let i = 1; i < days.length; i++) {
    if (days[i] - days[i - 1] === 86400000) { cur++; best = Math.max(best, cur); } else cur = 1;
  }
  return best;
}

/* Mood constellation — this month's moods drawn as a star map */
const CONST_ADJ = ['Quiet', 'Golden', 'Wandering', 'Silver', 'Hidden', 'Gentle', 'Burning', 'Dreaming', 'Rising', 'Velvet'];
const CONST_NOUN = ['Flame', 'Moon', 'River', 'Sparrow', 'Rose', 'Tide', 'Lantern', 'Fox', 'Star', 'Willow'];

function Constellation({ entries }) {
  const now = new Date();
  const moodByDay = new Map();
  for (const e of entries) {
    const d = new Date(e.created_at);
    if (d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear() && e.mood) {
      moodByDay.set(d.getDate(), e.mood);
    }
  }
  const days = [...moodByDay.keys()].sort((a, b) => a - b);
  if (days.length < 2) {
    return <p className="rv-const-empty muted">Write with moods this month and a constellation will form here ✦</p>;
  }
  // Deterministic star positions seeded by day number
  const pts = days.map(day => ({
    day,
    mood: moodByDay.get(day),
    x: 8 + ((day * 73) % 84),
    y: 12 + ((day * 37) % 66),
  }));
  const seed = now.getFullYear() * 12 + now.getMonth() + days.length;
  const name = `The Month of the ${CONST_ADJ[seed % 10]} ${CONST_NOUN[(seed * 7 + 3) % 10]}`;

  return (
    <div className="rv-const">
      <svg viewBox="0 0 100 90" className="rv-const-svg" preserveAspectRatio="none">
        <polyline
          points={pts.map(p => `${p.x},${p.y}`).join(' ')}
          fill="none"
          stroke="color-mix(in srgb, var(--accent) 45%, transparent)"
          strokeWidth="0.5"
        />
        {pts.map(p => (
          <circle key={p.day} cx={p.x} cy={p.y} r="1.7" fill={moodColor(p.mood) || 'var(--accent)'}>
            <title>{p.mood} · {MONTH_ABBR[now.getMonth()]} {p.day}</title>
          </circle>
        ))}
      </svg>
      <p className="rv-const-name cinzel">✦ {name} ✦</p>
    </div>
  );
}

export default function Review() {
  const [entries, setEntries] = useState([]);
  const [loading, setLoading] = useState(true);
  const year = new Date().getFullYear();

  const load = useCallback(async () => {
    try {
      const data = await api.listEntries();
      setEntries(data.filter(e => new Date(e.created_at).getFullYear() === year));
    } catch (e) { console.error(e); }
    finally { setLoading(false); }
  }, [year]);
  useEffect(() => { load(); }, [load]);

  const totalWords = entries.reduce((s, e) => s + plainWords(e.body), 0);
  const streak = longestStreak(entries);

  const byMonth = Array.from({ length: 12 }, () => 0);
  entries.forEach(e => { byMonth[new Date(e.created_at).getMonth()]++; });
  const maxMonth = Math.max(1, ...byMonth);

  const moodCounts = {};
  entries.forEach(e => { if (e.mood) moodCounts[e.mood] = (moodCounts[e.mood] || 0) + 1; });
  const topMood = Object.entries(moodCounts).sort((a, b) => b[1] - a[1])[0]?.[0] || '';

  // Mood landscape: one tick per journaled day (latest mood wins)
  const moodByDay = new Map();
  entries.forEach(e => {
    if (!e.mood) return;
    const d = new Date(e.created_at); d.setHours(0, 0, 0, 0);
    moodByDay.set(d.getTime(), e.mood);
  });
  const landscape = [...moodByDay.entries()].sort((a, b) => a[0] - b[0]);

  const tagCounts = {};
  entries.forEach(e => {
    (e.tags || '').split(',').map(t => t.trim()).filter(Boolean).forEach(t => {
      tagCounts[t] = (tagCounts[t] || 0) + 1;
    });
  });
  const topTags = Object.entries(tagCounts).sort((a, b) => b[1] - a[1]).slice(0, 5);

  return (
    <div className="rv-page">
      <header className="app-header">
        <Link to="/timeline" className="back-btn" title="Back to your journal">⟵</Link>
        <span className="header-spacer" />
        <span className="brand cinzel rv-brand">🔮 Year in Review — {year}</span>
        <span className="header-spacer" />
      </header>

      <div className="rv-body">
        {loading ? (
          <div className="rv-state">Reading the stars…</div>
        ) : entries.length === 0 ? (
          <div className="rv-empty">
            <span className="rv-empty-icon">📖</span>
            <h3 className="cinzel rv-empty-title">No entries yet this year.</h3>
            <p className="muted">Write your first entry to see your journey unfold.</p>
          </div>
        ) : (
          <>
            {/* Top-line stats */}
            <div className="rv-stats">
              <div className="rv-stat card"><span className="rv-stat-icon">📝</span><span className="rv-stat-num cinzel">{entries.length}</span><span className="rv-stat-label">entries</span></div>
              <div className="rv-stat card"><span className="rv-stat-icon">✍️</span><span className="rv-stat-num cinzel">{totalWords.toLocaleString()}</span><span className="rv-stat-label">words</span></div>
              <div className="rv-stat card"><span className="rv-stat-icon">🔥</span><span className="rv-stat-num cinzel">{streak}</span><span className="rv-stat-label">day streak</span></div>
            </div>

            {/* Monthly activity */}
            <p className="rv-section-label">Monthly activity</p>
            <div className="rv-chart card">
              {byMonth.map((count, m) => (
                <div key={m} className="rv-bar-col">
                  {count > 0 && <span className="rv-bar-count">{count}</span>}
                  <div
                    className={`rv-bar ${count ? 'rv-bar-on' : ''}`}
                    style={{ height: count ? `${Math.max(6, (count / maxMonth) * 90)}px` : '4px' }}
                  />
                  <span className="rv-bar-month">{MONTH_ABBR[m]}</span>
                </div>
              ))}
            </div>

            {/* Dominant mood */}
            {topMood && (
              <>
                <p className="rv-section-label">Dominant mood</p>
                <div className="rv-mood card">
                  <span className="rv-mood-emoji" style={{ '--mc': moodColor(topMood) || 'var(--accent)' }}>{topMood}</span>
                  <p className="rv-mood-text">You carried this feeling most through {year}.</p>
                </div>
              </>
            )}

            {/* Mood landscape */}
            {landscape.length > 0 && (
              <>
                <p className="rv-section-label">Mood landscape</p>
                <div className="rv-strip card">
                  {landscape.map(([ts, mood]) => (
                    <span
                      key={ts}
                      className="rv-tick"
                      style={{ background: moodColor(mood) || 'var(--accent)' }}
                      title={`${mood} ${new Date(ts).toLocaleDateString('en-US', { month: 'numeric', day: 'numeric' })}`}
                    />
                  ))}
                </div>
              </>
            )}

            {/* Mood constellation — this month */}
            <p className="rv-section-label">This month's constellation</p>
            <div className="card rv-const-card">
              <Constellation entries={entries} />
            </div>

            {/* Top tags */}
            {topTags.length > 0 && (
              <>
                <p className="rv-section-label">Most used tags</p>
                <div className="rv-tags card">
                  {topTags.map(([tag, count]) => (
                    <div key={tag} className="rv-tag-row">
                      <span className="rv-tag-name">#{tag}</span>
                      <div className="rv-tag-track">
                        <div className="rv-tag-fill" style={{ width: `${Math.min(100, (count / entries.length) * 100)}%` }} />
                      </div>
                      <span className="rv-tag-count">{count}</span>
                    </div>
                  ))}
                </div>
              </>
            )}
          </>
        )}
      </div>
    </div>
  );
}
