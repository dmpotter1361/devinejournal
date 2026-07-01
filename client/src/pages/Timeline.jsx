import { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, clearAuth, getUser } from '../api';
import { MOODS, moodColor } from '../moods';
import { THEMES, themeById, applyTheme } from '../themes';
import { openSearch } from '../components/SearchOverlay';
import './Timeline.css';

const ENTRY_TYPES = [
  { id: 'journal',    icon: '📔', label: 'Journal Entry',   desc: 'Write freely about your day' },
  { id: 'gratitude',  icon: '🙏', label: 'Gratitude',       desc: 'Count your blessings today' },
  { id: 'dream',      icon: '🌙', label: 'Dream Log',       desc: 'Capture a dream' },
  { id: 'ritual',     icon: '🌕', label: 'Moon Ritual',     desc: 'Set intentions by the moon' },
  { id: 'spell',      icon: '🕯️', label: 'Spell & Intention', desc: 'Record your magical workings' },
  { id: 'shadow',     icon: '🖤', label: 'Shadow Work',     desc: 'Look inward with courage' },
  { id: 'checkin',    icon: '☀️', label: 'Daily Check-In',  desc: 'A gentle daily self-check' },
  { id: 'letter',     icon: '💌', label: 'Letter to Self',  desc: 'Write to your future self' },
  { id: 'memory',     icon: '🌟', label: 'Memory',          desc: 'Preserve a special moment' },
  { id: 'reflection', icon: '🪞', label: 'Reflection',      desc: 'Look inward with intention' },
  { id: 'travel',     icon: '🧳', label: 'Travel Note',     desc: 'Capture a place and moment' },
  { id: 'quick',      icon: '⚡', label: 'Quick Thought',   desc: 'A fast jot-it-down moment' },
  { id: 'poem',       icon: '✨', label: 'Poem',            desc: 'Express yourself in verse' },
];

const TAG_ICON = { gratitude: '🙏', dream: '💭', letter: '💌', memory: '🌟', reflection: '🪞', quick: '⚡', poem: '✨' };

const MOON_CYCLE = ['🌕','🌖','🌗','🌘','🌑','🌒','🌓','🌔'];

function MoonPhase() {
  const synodicMs = 29.53058867 * 86400000;
  const phase = ((Date.now() - 1704974220000) % synodicMs) / synodicMs;
  const idx = Math.floor(phase * 8) % 8;
  const names = ['New Moon','Waxing Crescent','First Quarter','Waxing Gibbous','Full Moon','Waning Gibbous','Last Quarter','Waning Crescent'];
  return (
    <div className="tl-moon-phase">
      <span className="tl-moon-emoji">{MOON_CYCLE[idx]}</span>
      <span className="tl-moon-phase-name">{names[idx]}</span>
    </div>
  );
}

function getEntryIcon(entry) {
  if (!entry.tags) return '📔';
  const tagList = entry.tags.split(',').map(t => t.trim().toLowerCase());
  for (const [tag, icon] of Object.entries(TAG_ICON)) {
    if (tagList.includes(tag)) return icon;
  }
  return '📔';
}

function plainText(html) {
  if (!html) return '';
  if (html.trimStart().startsWith('[')) {
    try { return JSON.parse(html).filter(b => b.type === 'text').map(b => b.content || '').join(' ').slice(0, 200); }
    catch { /**/ }
  }
  const tmp = document.createElement('div');
  tmp.innerHTML = html;
  return (tmp.textContent || '').slice(0, 200);
}

function EntryCard({ entry, onClick, sealed }) {
  const mc = moodColor(entry.mood);
  const theme = themeById(entry.theme_id || 'midnight');
  // Only entries with an explicit journal theme get the card-body tint
  const themedClass = entry.theme_id ? 'entry-card--themed' : '';
  const preview = plainText(entry.body);
  const d = new Date(entry.created_at);

  if (sealed) {
    const opensOn = new Date(entry.locked_until).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
    return (
      <button className={`entry-card entry-card--sealed ${themedClass}`} onClick={onClick} style={{ '--theme-dot': theme.dot }}>
        <div className="ec-date">
          <span className="ec-day-meta">
            <span className="ec-weekday">{d.toLocaleDateString('en-US', { weekday: 'short' })}</span>
            <span className="ec-sep">·</span>
            <span className="ec-month">{d.toLocaleDateString('en-US', { month: 'short' })}</span>
          </span>
          <span className="ec-daynum ec-sealed-lock">🔒</span>
        </div>
        <div className="ec-body">
          <div className="ec-top">
            <h3 className="ec-title ec-sealed-title">Sealed memory</h3>
          </div>
          <p className="ec-preview ec-sealed-opens">Opens {opensOn}</p>
        </div>
      </button>
    );
  }

  return (
    <button className={`entry-card ${themedClass}`} onClick={onClick} style={{ '--theme-dot': theme.dot }}>
      <div className="ec-date">
        <span className="ec-day-meta">
          <span className="ec-weekday">{d.toLocaleDateString('en-US', { weekday: 'short' })}</span>
          <span className="ec-sep">·</span>
          <span className="ec-month">{d.toLocaleDateString('en-US', { month: 'short' })}</span>
        </span>
        <span className="ec-daynum">{d.getDate()}</span>
        <span className="ec-year">{d.getFullYear()}</span>
      </div>
      <div className="ec-body">
        <div className="ec-top">
          {entry.title
            ? <h3 className="ec-title">{entry.title}</h3>
            : <span className="ec-untitled">untitled</span>
          }
          <div className="ec-meta">
            {entry.is_favorite && <span className="ec-fav">⭐</span>}
            {entry.mood && (
              <span className="ec-mood" style={mc ? { '--mc': mc } : {}}>
                {entry.mood}
              </span>
            )}
            <span className="ec-dot" title={theme.name} />
          </div>
        </div>
        {preview && <p className="ec-preview">{preview}</p>}
        {entry.tags && (
          <div className="ec-tags">
            {entry.tags.split(',').map(t => t.trim()).filter(Boolean).map(t => (
              <span key={t} className="tag">{t}</span>
            ))}
          </div>
        )}
      </div>
    </button>
  );
}

const GARDEN_STAGES = [
  { emoji: '',   size: 0,  label: 'Plant your first seed' },
  { emoji: '🌱', size: 26, label: 'seedling' },
  { emoji: '🌿', size: 32, label: 'sprouting' },
  { emoji: '🌷', size: 40, label: 'budding' },
  { emoji: '🌸', size: 48, label: 'blossoming' },
  { emoji: '🌺', size: 56, label: 'in full bloom' },
  { emoji: '🌻', size: 64, label: 'radiant' },
];

function getStage(streak) {
  if (streak === 0) return 0;
  if (streak === 1) return 1;
  if (streak <= 3) return 2;
  if (streak <= 6) return 3;
  if (streak <= 13) return 4;
  return 5;
}

// Perennial garden: every CYCLE_DAYS written days of gratitude grows one
// permanent flower ("bloom"), then a fresh seed starts. Everything is derived
// from entry history — nothing extra is stored.
const FLOWERS = ['🌻', '🌷', '🌹', '🌸', '🌺', '🪻', '🌼', '💐'];
const CYCLE_DAYS = 21;
const MS_DAY = 86400000;

function buildGarden(gratEntries) {
  const dayKey = (v) => { const x = new Date(v); x.setHours(0, 0, 0, 0); return x.getTime(); };
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
      const entry = gratEntries.find(e => { const k = dayKey(e.created_at); return k >= start && k <= end; });
      blooms.push({ emoji: FLOWERS[blooms.length % FLOWERS.length], start, end, entryId: entry?.id });
    }
  }

  const lastRun = runs[runs.length - 1] || [];
  const lastDay = lastRun[lastRun.length - 1];
  const sinceLast = lastDay === undefined ? Infinity : (today - lastDay) / MS_DAY;
  const alive = sinceLast <= 2;
  return {
    blooms,
    currentDays: alive ? lastRun.length % CYCLE_DAYS : 0,
    resting: alive && sinceLast >= 1,
    alive,
    hadAny: days.length > 0,
  };
}

function bloomMonth(b) {
  return new Date(b.end).toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
}

function GratitudeGarden({ entries }) {
  const nav = useNavigate();
  const [picked, setPicked] = useState(null);
  const gratEntries = entries.filter(e => {
    const tagList = (e.tags || '').toLowerCase().split(',').map(t => t.trim());
    return tagList.includes('gratitude');
  });

  const g = buildGarden(gratEntries);
  const stage = GARDEN_STAGES[getStage(g.currentDays)];

  const sameDay = (e, d) => new Date(e.created_at).toDateString() === d.toDateString();
  const bgPlants = [];
  for (let i = 1; i <= 6; i++) {
    const d = new Date(); d.setDate(d.getDate() - i);
    if (gratEntries.some(e => sameDay(e, d))) bgPlants.push(i);
  }
  const bgPositions = [15, 80, 25, 72, 8, 88];
  const bgSizes = [16, 18, 14, 20, 14, 16];

  // Garden memory: resurface a long-forgotten bloom, rotating daily
  const oldBlooms = g.blooms.filter(b => (Date.now() - b.end) / MS_DAY > 30);
  const d0 = new Date();
  const daySeed = d0.getFullYear() * 372 + d0.getMonth() * 31 + d0.getDate();
  const memory = oldBlooms.length ? oldBlooms[daySeed % oldBlooms.length] : null;

  const groundText = () => {
    if (!g.hadAny) return <span>Write a Gratitude entry to plant your first seed</span>;
    if (!g.alive) return <span>The soil is ready for a new seed 🫘</span>;
    if (g.currentDays === 0) return <span>A fresh seed rests in the soil — keep writing 🌱</span>;
    if (g.resting) return <span><span className="grat-streak-num">{g.currentDays}</span> day{g.currentDays === 1 ? '' : 's'} · resting 🌙 — write today to keep growing</span>;
    return <span><span className="grat-streak-num">{g.currentDays}</span> day{g.currentDays === 1 ? '' : 's'} growing · {stage.label}</span>;
  };

  return (
    <div className="grat-garden">
      <div className="grat-scene">
        {bgPlants.slice(0, 4).map((dayIdx, i) => (
          <span
            key={dayIdx}
            className="grat-bg-plant"
            style={{ left: `${bgPositions[i]}%`, fontSize: bgSizes[i] }}
          >🌱</span>
        ))}
        {g.currentDays === 0
          ? <span className="grat-seed">🫘</span>
          : <span className={`grat-main-plant ${g.resting ? 'grat-resting' : ''}`} style={{ fontSize: stage.size }}>{stage.emoji}</span>
        }
      </div>

      {/* Garden bed — every completed cycle lives here forever */}
      {g.blooms.length > 0 && (
        <div className="grat-bed">
          {g.blooms.slice(-6).map((b, i) => (
            <button
              key={`${b.end}-${i}`}
              className="grat-bloom"
              title={`Grew ${bloomMonth(b)}`}
              onClick={() => setPicked(picked === b ? null : b)}
            >{b.emoji}</button>
          ))}
        </div>
      )}

      <div className="grat-ground">{groundText()}</div>

      {/* Story of a clicked bloom */}
      {picked && (
        <div className="grat-story">
          <span className="grat-story-flower">{picked.emoji}</span>
          <p className="grat-story-text">Grew from {CYCLE_DAYS} days of gratitude · {bloomMonth(picked)}</p>
          {picked.entryId && (
            <button className="grat-story-link" onClick={() => nav(`/entry/${picked.entryId}`)}>
              Revisit a memory ✦
            </button>
          )}
        </div>
      )}

      {/* Nostalgia nudge for a forgotten flower */}
      {!picked && memory && (
        <button className="grat-memory" onClick={() => setPicked(memory)}>
          Remember this {memory.emoji}? You grew it in {bloomMonth(memory)}.
        </button>
      )}

      {(gratEntries.length > 0 || g.blooms.length > 0) && (
        <p className="grat-total">
          {g.blooms.length > 0 && <>{g.blooms.length} flower{g.blooms.length === 1 ? '' : 's'} grown · </>}
          {gratEntries.length} gratitude {gratEntries.length === 1 ? 'entry' : 'entries'}
        </p>
      )}
    </div>
  );
}

function ThemePicker({ themes, currentId, onChange }) {
  const [open, setOpen] = useState(false);
  const ref = useRef(null);
  const current = themes.find(t => t.id === currentId) || themes[0];
  useEffect(() => {
    const h = e => { if (ref.current && !ref.current.contains(e.target)) setOpen(false); };
    document.addEventListener('mousedown', h);
    return () => document.removeEventListener('mousedown', h);
  }, []);
  return (
    <div className="tl-theme-picker" ref={ref}>
      <button className="tl-theme-trigger" onClick={() => setOpen(o => !o)}>
        <span className="tl-right-dot" style={{ background: current.dot }} />
        <span>{current.name}</span>
        <span className="tl-tp-arrow">{open ? '▴' : '▾'}</span>
      </button>
      {open && (
        <div className="tl-theme-dropdown">
          {themes.map(t => (
            <button
              key={t.id}
              className={`tl-theme-opt ${t.id === currentId ? 'active' : ''}`}
              onClick={() => { onChange(t.id); setOpen(false); }}
            >
              <span className="tl-right-dot" style={{ background: t.dot }} />
              <span>{t.name}</span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

function NewEntryModal({ onClose, onSelect }) {
  return (
    <div className="ne-overlay" onClick={onClose}>
      <div className="ne-modal" onClick={e => e.stopPropagation()}>
        <div className="ne-modal-header">
          <h2 className="ne-modal-title cinzel">New Entry</h2>
          <button className="btn icon-btn ne-close" onClick={onClose}>✕</button>
        </div>
        <div className="ne-types">
          {ENTRY_TYPES.map(t => (
            <button key={t.id} className="ne-type-btn" onClick={() => onSelect(t)}>
              <span className="ne-type-icon">{t.icon}</span>
              <div className="ne-type-text">
                <span className="ne-type-label">{t.label}</span>
                <span className="ne-type-desc">{t.desc}</span>
              </div>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

const AFFIRMATIONS = [
  'You are a vessel of ancient wisdom and infinite light.',
  'The universe conspires in your favor, always.',
  'Your intuition is a sacred compass — trust it.',
  'You bloom beautifully in every season of your soul.',
  'Magic lives in the quiet moments you choose to notice.',
  'You are held by the moon and guided by the stars.',
  'Every breath you take is a prayer answered.',
  'Your sensitivity is your greatest strength.',
  'You are the author of a story worth telling.',
  'The sacred lives within you — you need only be still.',
  'You carry the wisdom of those who came before you.',
  'Your heart knows things your mind is still learning.',
  'You are enough, in this moment, exactly as you are.',
  'Beauty finds you because you have learned to seek it.',
  'The stars aligned for your becoming.',
  'You are a living ceremony of grace and resilience.',
  'Trust the timing of your unfolding.',
  'You are worthy of the love you so freely give.',
  'Every ending is a threshold into something sacred.',
  'The moon waxes and wanes — so too shall your seasons.',
  'You are rooted in love and reaching toward wonder.',
  'Rest is not retreat — it is preparation.',
  'You are a garden tended by time and intention.',
  'Softness is not weakness; it is the signature of the brave.',
  'You are held in the arms of the universe tonight.',
  'Every scar is a map of how far you have traveled.',
  'The moon rises for you, faithful as your own heartbeat.',
  'You are woven from starlight and ancient song.',
  'You do not need to earn rest — you are worthy of ease.',
  'Your story is still being written — and it is magnificent.',
  'Grace follows you like moonlight through open windows.',
  'The sacred is not elsewhere — it lives in your ordinary days.',
  'You are allowed to take up space, in your fullness.',
  'Healing happens in the spaces between your bravest moments.',
  'The universe has not forgotten you — it is working on your behalf.',
  'Be as gentle with yourself as you are with the things you love.',
  'What you tend to with love will always grow.',
  'Let the moon hold what is heavy tonight.',
  'The path ahead is lit by the light you already carry.',
];

function todaysAffirmation() {
  const d = new Date();
  const seed = d.getFullYear() * 10000 + (d.getMonth() + 1) * 100 + d.getDate();
  return AFFIRMATIONS[seed % AFFIRMATIONS.length];
}

function TimelineHeader({ user, entries }) {
  const h = new Date().getHours();
  const greeting = h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
  const firstName = (user?.name || '').split(' ')[0] || 'dear';
  const dateStr = new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' });
  const synodicMs = 29.53058867 * 86400000;
  const phase = ((Date.now() - 1704974220000) % synodicMs) / synodicMs;
  const moon = ['🌕','🌖','🌗','🌘','🌑','🌒','🌓','🌔'][Math.floor(phase * 8) % 8];
  const streak = (() => {
    let s = 0;
    for (let i = 0; i < 90; i++) {
      const d = new Date(); d.setDate(d.getDate() - i);
      const ds = d.toDateString();
      if (entries.some(e => new Date(e.created_at).toDateString() === ds)) s++; else break;
    }
    return s;
  })();

  return (
    <div className="tl-header-card">
      <div className="tl-hc-top">
        <span className="tl-hc-moon">{moon}</span>
        <div className="tl-hc-greet">
          <span className="tl-hc-name">{greeting}, {firstName}</span>
          <span className="tl-hc-date">{dateStr}</span>
        </div>
        {streak > 0 && (
          <span className="tl-hc-streak">{streak >= 7 ? '🔥' : '✦'} {streak}d</span>
        )}
      </div>
      <p className="tl-hc-affirmation">"{todaysAffirmation()}"</p>
      {entries.length > 0 && (
        <div className="tl-hc-stats">
          <span className="tl-hc-stat">{entries.length} entries</span>
          <span className="tl-hc-dot-sep">·</span>
          <span className="tl-hc-stat">{entries.reduce((a, e) => a + (e.body ? e.body.replace(/<[^>]+>/g,'').split(/\s+/).filter(Boolean).length : 0), 0).toLocaleString()} words</span>
        </div>
      )}
    </div>
  );
}

export default function Timeline() {
  const nav = useNavigate();
  const user = getUser();
  const [entries, setEntries] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [moodFilter, setMoodFilter] = useState('');
  const [favOnly, setFavOnly] = useState(false);
  const [newModalOpen, setNewModalOpen] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [moodPickOpen, setMoodPickOpen] = useState(false);
  const moodPickRef = useRef(null);
  const [currentThemeId, setCurrentThemeId] = useState(
    () => localStorage.getItem('dj_theme') || 'midnight'
  );
  const menuRef = useRef(null);

  const [sealedEntry, setSealedEntry] = useState(null); // entry being shown in lock dialog

  const load = useCallback(async () => {
    try {
      setError('');
      const data = await api.listEntries();
      setEntries(data);
      // Cache all known tags for autocomplete in EntryEditor
      const allTags = [...new Set(
        data.flatMap(e => (e.tags || '').split(',').map(t => t.trim()).filter(Boolean))
      )];
      localStorage.setItem('dj_known_tags', JSON.stringify(allTags));
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  useEffect(() => {
    const h = (e) => {
      if (menuRef.current && !menuRef.current.contains(e.target)) setMenuOpen(false);
      if (moodPickRef.current && !moodPickRef.current.contains(e.target)) setMoodPickOpen(false);
    };
    document.addEventListener('mousedown', h);
    return () => document.removeEventListener('mousedown', h);
  }, []);

  const switchTheme = (id) => {
    applyTheme(id);
    localStorage.setItem('dj_theme', id);
    setCurrentThemeId(id);
  };

  const signOut = () => { clearAuth(); nav('/', { replace: true }); };

  const handleNewType = (type) => {
    setNewModalOpen(false);
    nav(`/entry/new?type=${type.id}`);
  };

  const isSealed = (e) => {
    if (!e.locked_until) return false;
    return new Date(e.locked_until) > new Date();
  };

  const onThisDay = entries.filter(e => {
    const d = new Date(e.created_at);
    const now = new Date();
    return d.getUTCMonth() === now.getUTCMonth() && d.getUTCDate() === now.getUTCDate() && d.getUTCFullYear() < now.getUTCFullYear();
  });

  const handleCardClick = (e) => {
    if (isSealed(e)) { setSealedEntry(e); return; }
    nav(`/entry/${e.id}`);
  };

  const filtered = entries.filter(e => {
    if (favOnly && !e.is_favorite) return false;
    if (moodFilter && e.mood !== moodFilter) return false;
    return true;
  });

  return (
    <div className="tl-page">
      <header className="app-header">
        <span className="brand cinzel">🌙 DevineJournal</span>
        <div className="header-spacer" />
        <button className="tl-search-btn" onClick={openSearch} title="Search your journal (Ctrl+K)">
          <span aria-hidden="true">🔍</span>
          <span className="tl-search-btn-label">Search…</span>
          <kbd className="tl-search-kbd">Ctrl K</kbd>
        </button>
        <button className="btn ghost cal-btn" onClick={() => nav('/calendar')} title="Calendar">
          <span className="cal-icon" aria-hidden="true" />Calendar
        </button>
        <div className="tl-user-menu" ref={menuRef}>
          <button className="tl-avatar-btn" onClick={() => setMenuOpen(o => !o)}>
            {user?.picture
              ? <img src={user.picture} alt={user.name || 'User'} className="tl-avatar" />
              : <span className="tl-avatar-fallback">👤</span>
            }
          </button>
          {menuOpen && (
            <div className="tl-menu">
              <div className="tl-menu-name">{user?.name || 'Journal'}</div>
              <button className="tl-menu-item danger" onClick={signOut}>🚪 Sign out</button>
            </div>
          )}
        </div>
      </header>

      <div className="tl-body">
        {/* Left decorative gutter */}
        <div className="tl-left-rail" aria-hidden="true">
          <div className="tl-rail-inner">
            <div className="tl-rail-line" />
            <div className="tl-rail-moons">
              {MOON_CYCLE.map((m, i) => (
                <span key={i} className="tl-rail-moon" style={{ animationDelay: `${i * 0.5}s` }}>{m}</span>
              ))}
            </div>
          </div>
        </div>

        {/* Center journal feed */}
        <div className="tl-center">

          {/* Theme strip — visible on mobile; hidden on desktop (handled by right panel) */}
          <div className="tl-theme-strip">
            {THEMES.map(t => (
              <button
                key={t.id}
                className={`tl-theme-pip ${currentThemeId === t.id ? 'active' : ''}`}
                onClick={() => switchTheme(t.id)}
                title={t.name}
              >
                <span className="tl-pip-dot" style={{ background: t.dot }} />
                <span className="tl-pip-name">{t.name}</span>
              </button>
            ))}
          </div>

          {/* Greeting + affirmation header */}
          {!loading && !error && <TimelineHeader user={user} entries={entries} />}

          {/* Compact filter bar */}
          <div className="tl-filter-bar">
            <button
              className={`tl-chip ${!moodFilter && !favOnly ? 'active' : ''}`}
              onClick={() => { setMoodFilter(''); setFavOnly(false); setMoodPickOpen(false); }}
            >All</button>
            <button
              className={`tl-chip tl-fav-chip ${favOnly ? 'active' : ''}`}
              onClick={() => { setFavOnly(f => !f); setMoodFilter(''); }}
            >⭐ Favorites</button>
            <div className="tl-mood-wrap" ref={moodPickRef}>
              <button
                className={`tl-chip ${moodFilter ? 'active mood' : ''}`}
                onClick={() => setMoodPickOpen(o => !o)}
                style={moodFilter ? { '--mc': moodColor(moodFilter) || 'var(--accent)' } : {}}
              >
                {moodFilter ? <>{moodFilter} <span className="tl-chip-clear" onClick={e => { e.stopPropagation(); setMoodFilter(''); }}>✕</span></> : 'Mood ▾'}
              </button>
              {moodPickOpen && (
                <div className="tl-mood-popup">
                  {MOODS.filter(Boolean).map(m => (
                    <button
                      key={m}
                      className={`tl-mood-opt ${moodFilter === m ? 'sel' : ''}`}
                      onClick={() => { setMoodFilter(m); setMoodPickOpen(false); setFavOnly(false); }}
                    >{m}</button>
                  ))}
                </div>
              )}
            </div>
          </div>

          {/* Entry feed */}
          <div className="tl-feed">
            {loading && <div className="tl-state">Loading your journal…</div>}
            {error && <div className="tl-state tl-error">{error}</div>}

            {/* On This Day */}
            {!loading && !moodFilter && !favOnly && onThisDay.length > 0 && (
              <div className="tl-otd">
                <div className="tl-otd-label">✦ On this day ✦</div>
                {onThisDay.map(e => {
                  const yearsAgo = new Date().getFullYear() - new Date(e.created_at).getFullYear();
                  return (
                    <button key={e.id} className="tl-otd-card" onClick={() => handleCardClick(e)}>
                      <span className="tl-otd-years">{yearsAgo} {yearsAgo === 1 ? 'year' : 'years'} ago</span>
                      {e.mood && <span className="tl-otd-mood">{e.mood}</span>}
                      <span className="tl-otd-title">{e.title || 'untitled'}</span>
                    </button>
                  );
                })}
              </div>
            )}

            {!loading && !error && filtered.length === 0 && (
              entries.length === 0 ? (
                <div className="tl-empty-state">
                  <div className="tl-empty-art">
                    <span className="tl-empty-moon">🌙</span>
                    <div className="tl-empty-star-row">✦ · ✧ · ✦ · ✧ · ✦</div>
                    <div className="tl-empty-botanicals">🌹 🌺 🌸</div>
                  </div>
                  <h3 className="tl-empty-title cinzel">Your journal awaits</h3>
                  <p className="tl-empty-sub">Every great journey begins with a single word.</p>
                  <p className="tl-empty-hint">Click ✦ New Entry to begin your story.</p>
                </div>
              ) : (
                <div className="tl-state">
                  <p className="tl-empty-icon">🔍</p>
                  <p className="muted">No entries match your filter.</p>
                </div>
              )
            )}
            {filtered.map(e => (
              <EntryCard key={e.id} entry={e} onClick={() => handleCardClick(e)} sealed={isSealed(e)} />
            ))}
          </div>
        </div>

        {/* Right sidebar — theme + gratitude garden (desktop only) */}
        <aside className="tl-right-panel">
          <div className="tl-right-inner">
            <MoonPhase />

            <div className="tl-right-divider"><span>✦</span></div>

            <p className="tl-right-heading cinzel">Theme</p>
            <ThemePicker themes={THEMES} currentId={currentThemeId} onChange={switchTheme} />

            <div className="tl-right-divider"><span>✦</span></div>

            {/* Gratitude Garden */}
            <p className="tl-right-heading cinzel">Garden</p>
            <GratitudeGarden entries={entries} />

            <div className="tl-right-divider"><span>✦</span></div>

            <p className="tl-right-heading cinzel">Journal</p>
            <div className="tl-right-stats">
              <div className="tl-stat">
                <span className="tl-stat-num">{entries.length}</span>
                <span className="tl-stat-label">entries</span>
              </div>
              <div className="tl-stat">
                <span className="tl-stat-num">{entries.filter(e => e.is_favorite).length}</span>
                <span className="tl-stat-label">favorites</span>
              </div>
              <div className="tl-stat">
                <span className="tl-stat-num">{new Set(entries.map(e => new Date(e.created_at).toDateString())).size}</span>
                <span className="tl-stat-label">days</span>
              </div>
            </div>
          </div>
        </aside>
      </div>

      {/* FAB */}
      <button className="tl-fab" onClick={() => setNewModalOpen(true)} title="New entry">
        ✦ New Entry
      </button>

      {/* New Entry Type Modal */}
      {newModalOpen && (
        <NewEntryModal
          onClose={() => setNewModalOpen(false)}
          onSelect={handleNewType}
        />
      )}

      {/* Sealed memory dialog */}
      {sealedEntry && (() => {
        const opensOn = new Date(sealedEntry.locked_until).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
        return (
          <div className="ne-overlay" onClick={() => setSealedEntry(null)}>
            <div className="sealed-dialog" onClick={e => e.stopPropagation()}>
              <div className="sealed-dialog-icon">🔒</div>
              <h3 className="sealed-dialog-title cinzel">Memory Sealed</h3>
              <p className="sealed-dialog-body">
                {sealedEntry.title ? `"${sealedEntry.title}"` : 'This memory'} will open on<br />
                <strong>{opensOn}</strong>.<br /><br />
                Come back then — it will be waiting for you.
              </p>
              <button className="btn" onClick={() => setSealedEntry(null)}>I'll wait ✦</button>
            </div>
          </div>
        );
      })()}
    </div>
  );
}
