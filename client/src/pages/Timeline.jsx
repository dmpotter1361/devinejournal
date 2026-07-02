import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, clearAuth, getUser } from '../api';
import { MOODS, moodColor } from '../moods';
import { THEMES, themeById, applyTheme } from '../themes';
import { openSearch } from '../components/SearchOverlay';
import { CYCLE_DAYS, MS_DAY, GARDEN_STAGES, getStage, isGratitude, buildGarden, bloomMonth } from '../lib/garden';
import { MAJOR_ARCANA } from '../lib/tarot';
import { nextSabbat } from '../lib/sabbats';
import { hasPin, requestLock } from '../lib/pin';
import { skyToday, featuredPlacement, retrogradeNote } from '../lib/astro';
import { lunarInfo, moonPhase } from '../lib/moon';
import { crystalOfTheDay } from '../lib/crystals';
import BreathingOverlay from '../components/BreathingOverlay';
import { isSealed, opensOn } from '../lib/seal';
import SecurityModal from '../components/SecurityModal';
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
  const { emoji, name } = moonPhase();
  return (
    <div className="tl-moon-phase">
      <span className="tl-moon-emoji">{emoji}</span>
      <span className="tl-moon-phase-name">{name}</span>
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
  // Block boundaries and line breaks become spaces, or paragraphs jam together
  const spaced = html
    .replace(/<\/(p|li|div|h[1-6]|blockquote)>/gi, ' ')
    .replace(/<br[^>]*>/gi, ' ');
  const tmp = document.createElement('div');
  tmp.innerHTML = spaced;
  return (tmp.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 200);
}

// First inline image in an entry body → card thumbnail
function firstImage(body) {
  if (!body || body.trimStart().startsWith('[')) return null;
  const m = body.match(/<img[^>]+src="([^"]+)"/i);
  return m ? m[1] : null;
}

function EntryCard({ entry, onClick, sealed }) {
  const mc = moodColor(entry.mood);
  const theme = themeById(entry.theme_id || 'midnight');
  // Only entries with an explicit journal theme get the card-body tint
  const themedClass = entry.theme_id ? 'entry-card--themed' : '';
  const preview = plainText(entry.body);
  const thumb = useMemo(() => firstImage(entry.body), [entry.body]);
  const d = new Date(entry.created_at);

  if (sealed) {
    const opensOnStr = opensOn(entry.locked_until).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
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
            <span className="ec-seal" aria-hidden="true">☾</span>
          </div>
          <p className="ec-preview ec-sealed-opens">Opens {opensOnStr}</p>
        </div>
      </button>
    );
  }

  return (
    <button
      className={`entry-card ${themedClass} ${thumb ? 'entry-card--thumb' : ''}`}
      onClick={onClick}
      style={{ '--theme-dot': theme.dot }}
    >
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
      {thumb && (
        <div className="ec-thumb" aria-hidden="true">
          <img src={thumb} alt="" loading="lazy" />
        </div>
      )}
    </button>
  );
}

function GratitudeGarden({ entries }) {
  const nav = useNavigate();
  const [picked, setPicked] = useState(null);
  const gratEntries = entries.filter(isGratitude);

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
          {memory.sampleLine
            ? <>Remember this {memory.emoji}? “{memory.sampleLine.slice(0, 60)}{memory.sampleLine.length > 60 ? '…' : ''}”</>
            : <>Remember this {memory.emoji}? You grew it in {bloomMonth(memory)}.</>}
        </button>
      )}

      {(gratEntries.length > 0 || g.blooms.length > 0) && (
        <p className="grat-total">
          {g.blooms.length > 0 && <>{g.blooms.length} flower{g.blooms.length === 1 ? '' : 's'} grown · </>}
          {gratEntries.length} gratitude {gratEntries.length === 1 ? 'entry' : 'entries'}
        </p>
      )}
      <button className="grat-visit" onClick={() => nav('/garden')}>Visit your garden ✦</button>
    </div>
  );
}

/* ── The Sky Today ☉ — real planetary positions, a fixed fact of the day ── */
function SkyToday() {
  const sky = skyToday();
  const featured = featuredPlacement();
  const retro = retrogradeNote();
  return (
    <div className="sky-box">
      <div className="sky-rows">
        {sky.map(b => (
          <div key={b.name} className={`sky-row ${featured.name === b.name ? 'sky-featured-row' : ''}`}>
            {/* U+FE0E forces text-style glyphs — emoji rendering overflows the rail */}
            <span className="sky-glyph">{b.glyph + '︎'}</span>
            <span className="sky-planet">
              {b.name}{b.retro && <span className="sky-retro" title="retrograde">℞</span>}
            </span>
            <span className="sky-sign-name">{b.sign.name}</span>
            <span className="sky-glyph sky-sign-glyph">{b.sign.glyph + '︎'}</span>
          </div>
        ))}
      </div>
      <p className="sky-meaning">{featured.meaning}</p>
      {retro && <p className="sky-retro-note">{retro.glyph + '︎'}℞ {retro.text}</p>}
    </div>
  );
}

/* ── New Moon → Full Moon intention cycle 🌑🌕 ── */
function MoonIntention() {
  const nav = useNavigate();
  const { cycle, age } = lunarInfo();
  const [stored, setStored] = useState(() => {
    try { return JSON.parse(localStorage.getItem('dj_moon_intention') || 'null'); }
    catch { return null; }
  });
  const [draft, setDraft] = useState('');
  const mine = stored && stored.cycle === cycle ? stored : null;

  const save = () => {
    const text = draft.trim();
    if (!text) return;
    const rec = { cycle, text, released: false };
    localStorage.setItem('dj_moon_intention', JSON.stringify(rec));
    setStored(rec); setDraft('');
  };
  const release = () => {
    const rec = { ...mine, released: true };
    localStorage.setItem('dj_moon_intention', JSON.stringify(rec));
    setStored(rec);
  };

  const newWin = age <= 3;
  const fullWin = age >= 13 && age <= 17;

  if (newWin) {
    if (mine) return (
      <div className="moon-int">
        <p className="moon-int-line">🌑 Your intention is planted:</p>
        <p className="moon-int-text">"{mine.text}"</p>
      </div>
    );
    return (
      <div className="moon-int">
        <p className="moon-int-line">🌑 A new moon rises — what do you wish to call in?</p>
        <textarea
          className="moon-int-input" rows={2} maxLength={160}
          placeholder="Set your intention…" value={draft}
          onChange={e => setDraft(e.target.value)}
        />
        <button className="moon-int-btn" onClick={save} disabled={!draft.trim()}>Plant it ✦</button>
      </div>
    );
  }

  if (fullWin && mine && !mine.released) {
    return (
      <div className="moon-int">
        <p className="moon-int-line">🌕 At the new moon you asked for:</p>
        <p className="moon-int-text">"{mine.text}"</p>
        <p className="moon-int-sub">How has it unfolded?</p>
        <div className="moon-int-actions">
          <button className="moon-int-btn" onClick={() => nav(`/entry/new?type=ritual&intention=${encodeURIComponent(mine.text)}`)}>Reflect ✦</button>
          <button className="moon-int-btn ghost" onClick={release}>Release 🌙</button>
        </div>
      </div>
    );
  }

  // Quiet growing reminder between the two windows
  if (mine && !mine.released && age > 3 && age < 13) {
    return (
      <div className="moon-int moon-int-quiet">
        <p className="moon-int-line">🌱 Your intention is growing:</p>
        <p className="moon-int-text">"{mine.text}"</p>
      </div>
    );
  }
  return null; // waning / nothing active → stay out of the way
}

/* ── Crystal of the Day 🔮 ── */
function CrystalOfDay() {
  const c = crystalOfTheDay();
  return (
    <div className="crystal-box">
      <span className="crystal-emoji">{c.emoji}</span>
      <div className="crystal-text">
        <span className="crystal-name">{c.name}</span>
        <span className="crystal-props">{c.props}</span>
      </div>
    </div>
  );
}

/* ── Card of the Day 🔮 — a true random pull, locked in once drawn ── */
function CardOfDay() {
  const nav = useNavigate();
  const todayKey = new Date().toDateString();
  const [pick, setPick] = useState(() => {
    try {
      const p = JSON.parse(localStorage.getItem('dj_card_pick') || 'null');
      return p && p.date === todayKey ? p.idx : null;
    } catch { return null; }
  });
  const card = pick !== null ? MAJOR_ARCANA[pick] : null;
  const draw = () => {
    const idx = Math.floor(Math.random() * MAJOR_ARCANA.length);
    localStorage.setItem('dj_card_pick', JSON.stringify({ date: todayKey, idx }));
    setPick(idx);
  };

  if (!card) {
    return (
      <button className="cod-back" onClick={draw}>
        <span className="cod-back-moon">☾</span>
        <span className="cod-back-label">Draw today's card ✦</span>
      </button>
    );
  }
  return (
    <div className="cod-card">
      <span className="cod-symbol">{card.symbol}</span>
      <span className="cod-name cinzel">{card.name}</span>
      <p className="cod-reading">{card.reading}</p>
      <button
        className="cod-journal"
        onClick={() => nav(`/entry/new?type=reflection&card=${encodeURIComponent(card.name)}`)}
      >Journal this ✦</button>
    </div>
  );
}

/* ── The familiar 🐈‍⬛ — naps until you write, then leaves you a keepsake ── */
const LUNA_GIFTS = [
  { emoji: '🌷', msg: 'Luna left a pressed tulip between your pages.' },
  { emoji: '🍃', msg: 'Luna brought you a leaf still cool with dew.' },
  { emoji: '✨', msg: 'Luna curled up and left a little wish behind.' },
  { emoji: '🌾', msg: 'Luna nudged a sprig of wheat your way — for abundance.' },
  { emoji: '🪶', msg: 'Luna dropped a soft feather beside your candle.' },
  { emoji: '🌙', msg: 'Luna traced a tiny moon in the dust, just for you.' },
  { emoji: '🐚', msg: 'Luna carried in a shell that still remembers the sea.' },
  { emoji: '⭐', msg: 'Luna blinked at you slowly — in cat, that means "I love you."' },
  { emoji: '🍯', msg: 'Luna left something sweet — a small, quiet kindness.' },
  { emoji: '🌟', msg: 'Luna kept a wish warm for you through the night.' },
];
function lunaGift(d = new Date()) {
  const seed = d.getFullYear() * 372 + d.getMonth() * 31 + d.getDate();
  return LUNA_GIFTS[seed % LUNA_GIFTS.length];
}

function Familiar({ entries }) {
  const wroteToday = entries.some(e => new Date(e.created_at).toDateString() === new Date().toDateString());
  const [open, setOpen] = useState(false);
  const gift = lunaGift();
  return (
    <div className="fam-box">
      <button
        className="fam-scene"
        onClick={() => wroteToday && setOpen(o => !o)}
        style={{ cursor: wroteToday ? 'pointer' : 'default' }}
        title={wroteToday ? 'Luna has something for you' : 'Luna is napping'}
      >
        <span className={`fam-cat ${wroteToday ? 'fam-awake' : 'fam-asleep'}`}>🐈‍⬛</span>
        {wroteToday ? <span className="fam-star">✦</span> : <span className="fam-zzz">💤</span>}
      </button>
      {wroteToday
        ? (open
            ? <p className="fam-gift">{gift.emoji} {gift.msg}</p>
            : <p className="fam-caption">Luna has something for you — tap her ✦</p>)
        : <p className="fam-caption">Luna is napping — write to wake her</p>}
    </div>
  );
}

/* ── Charm shelf 🧿 — milestones derived from entry history ── */
function longestStreak(entries) {
  const days = [...new Set(entries.map(e => { const d = new Date(e.created_at); d.setHours(0, 0, 0, 0); return d.getTime(); }))].sort((a, b) => a - b);
  let best = days.length ? 1 : 0, cur = 1;
  for (let i = 1; i < days.length; i++) {
    if (days[i] - days[i - 1] === MS_DAY) { cur++; best = Math.max(best, cur); } else cur = 1;
  }
  return best;
}

const CHARMS = [
  { id: 'first',    emoji: '🕯️', name: 'First Light — your first entry',         earned: (es) => es.length > 0 },
  { id: 'dream',    emoji: '🌙', name: 'Dream Catcher — your first dream log',   earned: (es) => es.some(e => (e.tags || '').toLowerCase().includes('dream')) },
  { id: 'grateful', emoji: '🙏', name: 'Grateful Heart — your first gratitude',  earned: (es) => es.some(isGratitude) },
  { id: 'shadow',   emoji: '🖤', name: 'Shadow Walker — your first shadow work', earned: (es) => es.some(e => (e.tags || '').toLowerCase().includes('shadow')) },
  { id: 'capsule',  emoji: '💌', name: 'Time Weaver — your first sealed memory', earned: (es) => es.some(e => e.locked_until) },
  { id: 'week',     emoji: '✦',  name: 'Seven Stars — a 7-day writing streak',   earned: (es) => longestStreak(es) >= 7 },
  { id: 'bloom',    emoji: '🌸', name: 'First Bloom — a full gratitude cycle',   earned: (es) => buildGarden(es.filter(isGratitude)).blooms.length > 0 },
  { id: 'century',  emoji: '📖', name: 'Century Scribe — one hundred entries',   earned: (es) => es.length >= 100 },
];

function CharmShelf({ entries }) {
  const earnedIds = new Set(CHARMS.filter(c => c.earned(entries)).map(c => c.id));
  return (
    <div className="charm-shelf">
      <div className="charm-row">
        {CHARMS.map(c => (
          <span
            key={c.id}
            className={`charm ${earnedIds.has(c.id) ? 'charm-earned' : ''}`}
            title={earnedIds.has(c.id) ? c.name : 'A charm awaits…'}
          >{earnedIds.has(c.id) ? c.emoji : '·'}</span>
        ))}
      </div>
      <p className="charm-count">{earnedIds.size} of {CHARMS.length} charms gathered</p>
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

function TimelineHeader({ user, entries, onBreathe }) {
  const h = new Date().getHours();
  const greeting = h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
  const firstName = (user?.name || '').split(' ')[0] || 'dear';
  const dateStr = new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' });
  const moon = moonPhase().emoji;
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
      {(() => {
        const s = nextSabbat();
        if (!s || s.daysAway > 7) return null;
        return (
          <p className="tl-hc-sabbat">
            {s.emoji} {s.name} {s.daysAway === 0 ? 'is today ✦' : `is in ${s.daysAway} day${s.daysAway === 1 ? '' : 's'} ✦`}
          </p>
        );
      })()}
      <div className="tl-hc-footer">
        {entries.length > 0 ? (
          <div className="tl-hc-stats">
            <span className="tl-hc-stat">{entries.length} entries</span>
            <span className="tl-hc-dot-sep">·</span>
            <span className="tl-hc-stat">{entries.reduce((a, e) => a + (e.body ? e.body.replace(/<[^>]+>/g,'').split(/\s+/).filter(Boolean).length : 0), 0).toLocaleString()} words</span>
          </div>
        ) : <span />}
        <button className="tl-hc-breathe" onClick={onBreathe} title="A grounding pause">◯ Take a breath</button>
      </div>
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
  const [securityOpen, setSecurityOpen] = useState(false);
  const [breathOpen, setBreathOpen] = useState(false);

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
              <button className="tl-menu-item" onClick={() => nav('/garden')}>🌸 Gratitude Garden</button>
              <button className="tl-menu-item" onClick={() => nav('/review')}>🔮 Year in Review</button>
              <button className="tl-menu-item" onClick={() => nav('/print')}>🖨️ Print journal</button>
              {hasPin() && (
                <button className="tl-menu-item" onClick={() => { setMenuOpen(false); requestLock(); }}>🔒 Lock journal</button>
              )}
              <button className="tl-menu-item" onClick={() => { setMenuOpen(false); setSecurityOpen(true); }}>🛡️ Security</button>
              <button className="tl-menu-item danger" onClick={signOut}>🚪 Sign out</button>
            </div>
          )}
        </div>
      </header>

      <div className="tl-body">
        {/* Left rail — moon strip + secondary tiles */}
        <div className="tl-left-rail">
          <div className="tl-rail-inner" aria-hidden="true">
            <div className="tl-rail-line" />
            <div className="tl-rail-moons">
              {MOON_CYCLE.map((m, i) => (
                <span key={i} className="tl-rail-moon" style={{ animationDelay: `${i * 0.5}s` }}>{m}</span>
              ))}
            </div>
          </div>
          <aside className="tl-left-panel">
            <div className="tl-right-inner">
              <p className="tl-right-heading cinzel">Theme</p>
              <ThemePicker themes={THEMES} currentId={currentThemeId} onChange={switchTheme} />

              <div className="tl-right-divider"><span>✦</span></div>

              <p className="tl-right-heading cinzel">Today's Crystal</p>
              <CrystalOfDay />

              <div className="tl-right-divider"><span>✦</span></div>

              <p className="tl-right-heading cinzel">Familiar</p>
              <Familiar entries={entries} />

              <div className="tl-right-divider"><span>✦</span></div>

              <p className="tl-right-heading cinzel">Charms</p>
              <CharmShelf entries={entries} />

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
          {!loading && !error && <TimelineHeader user={user} entries={entries} onBreathe={() => setBreathOpen(true)} />}

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
            <MoonIntention />

            <div className="tl-right-divider"><span>✦</span></div>

            <p className="tl-right-heading cinzel">The Sky Today</p>
            <SkyToday />

            <div className="tl-right-divider"><span>✦</span></div>

            <p className="tl-right-heading cinzel">Card of the Day</p>
            <CardOfDay />

            <div className="tl-right-divider"><span>✦</span></div>

            {/* Gratitude Garden */}
            <p className="tl-right-heading cinzel">Garden</p>
            <GratitudeGarden entries={entries} />
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

      {/* Grounding pause */}
      {breathOpen && <BreathingOverlay onClose={() => setBreathOpen(false)} />}

      {/* Security settings */}
      {securityOpen && <SecurityModal onClose={() => setSecurityOpen(false)} />}

      {/* Sealed memory dialog */}
      {sealedEntry && (() => {
        const opensOnStr = opensOn(sealedEntry.locked_until).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
        return (
          <div className="ne-overlay" onClick={() => setSealedEntry(null)}>
            <div className="sealed-dialog" onClick={e => e.stopPropagation()}>
              <div className="sealed-dialog-icon">🔒</div>
              <h3 className="sealed-dialog-title cinzel">Memory Sealed</h3>
              <p className="sealed-dialog-body">
                {sealedEntry.title ? `"${sealedEntry.title}"` : 'This memory'} will open on<br />
                <strong>{opensOnStr}</strong>.<br /><br />
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
