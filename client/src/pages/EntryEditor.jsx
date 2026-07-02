import { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate, useParams, useSearchParams, Link } from 'react-router-dom';
import { api } from '../api';
import { MOODS, moodColor } from '../moods';
import { THEMES, themeById } from '../themes';
import RichEditor, { resizeToBase64 } from '../components/RichEditor';
import { editorDirty } from '../lib/dirty';
import './EntryEditor.css';

const PAPER_STYLES = [
  { id: 'plain',  label: 'Plain',  icon: '□' },
  { id: 'lined',  label: 'Lined',  icon: '≡' },
  { id: 'dotted', label: 'Dotted', icon: '⠿' },
  { id: 'grid',   label: 'Grid',   icon: '⊞' },
];

const JOURNAL_PROMPTS = [
  'What are three things you\'re grateful for today?',
  'Describe a small moment that brought you joy recently.',
  'What would you do if you were not afraid?',
  'Write about someone who made a difference in your life.',
  'What does your ideal day look like, from morning to night?',
  'Describe a place that makes you feel completely at peace.',
  'What is something you\'ve been putting off, and why?',
  'Write about a memory that always makes you smile.',
  'What are you looking forward to most right now?',
  'How are you feeling today, really — beneath the surface?',
  'What is one thing you wish you could tell your younger self?',
  'What does home mean to you?',
  'Write about a challenge you overcame and what it taught you.',
  'What are you holding onto that you need to let go of?',
  'What brings you the most comfort when you\'re feeling low?',
  'Write about a dream — waking or sleeping — that stayed with you.',
  'What is something beautiful you saw or heard this week?',
  'What are you learning about yourself lately?',
  'Describe a scent, sound, or texture that takes you back to a specific memory.',
  'Write a letter to someone you love but haven\'t spoken to in a while.',
];

const now = new Date();
const TODAY = now.toLocaleDateString('en-US', { month: 'long', day: 'numeric' });

const TYPE_TEMPLATES = {
  gratitude: {
    title: `Gratitude — ${TODAY}`,
    body: '<p>Today I am grateful for…</p><p></p><p>A small joy I noticed today…</p><p></p><p>Someone I appreciate right now…</p>',
    tags: 'gratitude',
  },
  dream: {
    title: `Dream — ${TODAY}`,
    body: '<p>Last night I dreamed…</p><p></p><p>The feeling I woke up with…</p>',
    tags: 'dream',
  },
  letter: {
    title: `Dear Future Me,`,
    body: '<p>By the time you read this…</p>',
    tags: 'letter',
  },
  memory: {
    title: `Memory — ${TODAY}`,
    body: '<p>I want to remember…</p>',
    tags: 'memory',
  },
  reflection: {
    title: `Reflection — ${TODAY}`,
    body: '<p>What I\'ve been thinking about lately…</p><p></p><p>What I\'m learning about myself…</p>',
    tags: 'reflection',
  },
  quick: {
    title: '',
    body: '',
    tags: 'quick',
  },
  poem: {
    title: '',
    body: '<p></p>',
    tags: 'poem',
  },
  journal: {
    title: '',
    body: '',
    tags: '',
  },
  ritual: {
    title: `Moon Ritual — ${TODAY}`,
    body: '<p><strong>Moon phase:</strong></p><p></p><p><strong>Intention I am setting:</strong></p><p></p><p><strong>What I am releasing:</strong></p><p></p><p><strong>What I am calling in:</strong></p><p></p><p><strong>Tools · candles · cards used:</strong></p><p></p>',
    tags: 'ritual,moon',
  },
  spell: {
    title: `Spell Work — ${TODAY}`,
    body: '<p><strong>Purpose of this working:</strong></p><p></p><p><strong>Ingredients &amp; correspondences:</strong></p><p></p><p><strong>Words spoken:</strong></p><p></p><p><strong>What I felt during and after:</strong></p><p></p>',
    tags: 'spell,intention',
  },
  shadow: {
    title: `Shadow Work — ${TODAY}`,
    body: '<p><strong>What triggered me today:</strong></p><p></p><p><strong>What it brought up from my past:</strong></p><p></p><p><strong>What that part of me needs to hear:</strong></p><p></p><p><strong>One compassionate truth:</strong></p><p></p>',
    tags: 'shadow work',
  },
  checkin: {
    title: `Daily Check-In — ${TODAY}`,
    body: '<p><strong>How I feel right now:</strong></p><p></p><p><strong>One thing that went well today:</strong></p><p></p><p><strong>One thing that was hard:</strong></p><p></p><p><strong>What I need before bed:</strong></p><p></p>',
    tags: 'check-in',
  },
  travel: {
    title: `Travel — ${TODAY}`,
    body: '<p><strong>Where I am:</strong></p><p></p><p><strong>Who I am with:</strong></p><p></p><p><strong>A moment worth keeping:</strong></p><p></p><p><strong>Something I tasted, saw, or heard:</strong></p><p></p>',
    tags: 'travel',
  },
};

// Earliest allowed capsule-open date: tomorrow (local) — a capsule that
// "opens today" would never actually appear sealed.
function tomorrowStr() {
  const d = new Date(Date.now() + 86400000);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function pickPrompts(n = 3) {
  const arr = [...JOURNAL_PROMPTS];
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr.slice(0, n);
}

function legacyToHtml(body, photos) {
  if (!body || body.trim() === '') return '';
  if (body.trimStart().startsWith('<')) return body;
  if (body.trimStart().startsWith('[')) {
    try {
      const blocks = JSON.parse(body);
      return blocks.map(b => {
        if (b.type === 'text') {
          return `<p>${(b.content || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')}</p>`;
        }
        if (b.type === 'image') {
          const photo = photos.find(p => p.id === b.photo_id);
          if (!photo) return '';
          const align = b.align || 'center';
          const w = b.width ? ` width="${b.width}"` : '';
          const cap = b.caption || '';
          return `<figure class="ds-figure ds-align-${align}" data-align="${align}"><img src="${photo.data}"${w}><figcaption>${cap}</figcaption></figure>`;
        }
        return '';
      }).join('');
    } catch { /**/ }
  }
  return `<p>${body.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/\n/g, '</p><p>')}</p>`;
}

function VoiceMemoPlayer({ memo, onDelete }) {
  const fmt = (ms) => {
    const s = Math.round(Number(ms) / 1000);
    return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
  };
  return (
    <div className="vm-player">
      <audio controls src={memo.data} className="vm-audio" />
      <span className="vm-dur">{fmt(memo.duration_ms)}</span>
      {onDelete && (
        <button className="btn icon-btn vm-del" onClick={() => onDelete(memo.id)} title="Delete">🗑️</button>
      )}
    </div>
  );
}

function VoiceRecorder({ onSaved }) {
  const [recording, setRecording] = useState(false);
  const [pending, setPending] = useState([]);
  const mrRef = useRef(null);
  const startRef = useRef(0);
  const chunksRef = useRef([]);

  const startRec = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      chunksRef.current = [];
      startRef.current = performance.now();
      const mimeType = MediaRecorder.isTypeSupported('audio/webm') ? 'audio/webm' : 'audio/mp4';
      const mr = new MediaRecorder(stream, { mimeType });
      mr.ondataavailable = e => { if (e.data.size > 0) chunksRef.current.push(e.data); };
      mr.onstop = () => {
        const durationMs = performance.now() - startRef.current;
        const blob = new Blob(chunksRef.current, { type: mimeType });
        const url = URL.createObjectURL(blob);
        setPending(p => [...p, { blob, durationMs, url, id: String(Date.now()) }]);
        stream.getTracks().forEach(t => t.stop());
      };
      mr.start();
      mrRef.current = mr;
      setRecording(true);
    } catch {
      alert('Microphone access denied');
    }
  };

  const stopRec = () => {
    mrRef.current?.stop();
    mrRef.current = null;
    setRecording(false);
  };

  const removePending = (id) => {
    setPending(p => {
      const m = p.find(x => x.id === id);
      if (m) URL.revokeObjectURL(m.url);
      return p.filter(x => x.id !== id);
    });
  };

  const uploadAll = useCallback(async (entryId) => {
    if (!pending.length) return [];
    const saved = [];
    for (const m of pending) {
      const memo = await api.uploadVoiceMemo(entryId, m.blob, m.durationMs);
      URL.revokeObjectURL(m.url);
      saved.push(memo);
    }
    setPending([]);
    return saved;
  }, [pending]);

  useEffect(() => { if (onSaved) onSaved(uploadAll); }, [uploadAll, onSaved]);

  return (
    <div>
      {pending.map(m => (
        <div key={m.id} className="vm-player">
          <audio controls src={m.url} className="vm-audio" />
          <span className="vm-dur">{Math.round(m.durationMs / 1000)}s</span>
          <button className="btn icon-btn vm-del" onClick={() => removePending(m.id)} title="Discard">🗑️</button>
        </div>
      ))}
      <div className="ee-voice-header">
        <span className="ee-voice-label">🎙️ Voice memos</span>
        <button
          className={`btn vm-rec-btn ${recording ? 'vm-recording' : ''}`}
          onClick={recording ? stopRec : startRec}
        >
          {recording ? '⏹ Stop' : '⏺ Record'}
        </button>
      </div>
    </div>
  );
}

function TagInput({ value, onChange }) {
  const [input, setInput] = useState('');
  const [suggestions, setSuggestions] = useState([]);
  const knownTags = useRef(JSON.parse(localStorage.getItem('dj_known_tags') || '[]'));

  const currentTags = value.split(',').map(t => t.trim()).filter(Boolean);

  const handleInput = (v) => {
    setInput(v);
    const last = v.split(',').pop().trim().toLowerCase();
    if (last.length < 1) { setSuggestions([]); return; }
    const hits = knownTags.current.filter(t =>
      t.toLowerCase().startsWith(last) && !currentTags.includes(t)
    ).slice(0, 5);
    setSuggestions(hits);
  };

  const commitInput = (raw) => {
    const parts = raw.split(',').map(t => t.trim()).filter(Boolean);
    const merged = [...new Set([...currentTags, ...parts])];
    onChange(merged.join(', '));
    setInput('');
    setSuggestions([]);
  };

  const addSuggestion = (tag) => {
    const merged = [...new Set([...currentTags, tag])];
    onChange(merged.join(', '));
    setInput('');
    setSuggestions([]);
  };

  const removeTag = (tag) => {
    onChange(currentTags.filter(t => t !== tag).join(', '));
  };

  return (
    <div className="ee-tag-input-wrap">
      {currentTags.length > 0 && (
        <div className="ee-tags-preview">
          {currentTags.map(t => (
            <span key={t} className="tag ee-tag-pill">
              {t}
              <button className="ee-tag-remove" onClick={() => removeTag(t)}>✕</button>
            </span>
          ))}
        </div>
      )}
      <input
        className="ee-tags-input"
        placeholder="Add a tag…"
        value={input}
        onChange={e => handleInput(e.target.value)}
        onKeyDown={e => {
          if ((e.key === 'Enter' || e.key === ',') && input.trim()) {
            e.preventDefault();
            commitInput(input);
          }
        }}
        onBlur={() => { if (input.trim()) commitInput(input); setTimeout(() => setSuggestions([]), 150); }}
      />
      {suggestions.length > 0 && (
        <div className="ee-tag-suggestions">
          {suggestions.map(s => (
            <button key={s} className="ee-tag-suggestion" onMouseDown={() => addSuggestion(s)}>{s}</button>
          ))}
        </div>
      )}
    </div>
  );
}

export default function EntryEditor() {
  const { id } = useParams();
  const [searchParams] = useSearchParams();
  const nav = useNavigate();
  const isNew = !id;
  const entryType = isNew ? (searchParams.get('type') || 'journal') : null;

  const [loading, setLoading] = useState(!isNew);
  const [saving, setSaving] = useState(false);
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [mood, setMood] = useState('');
  const [tags, setTags] = useState('');
  const [paperStyle, setPaperStyle] = useState('lined');
  const [themeId, setThemeId] = useState('');
  const [isFavorite, setIsFavorite] = useState(false);
  const [lockedUntil, setLockedUntil] = useState('');
  const [savedMemos, setSavedMemos] = useState([]);
  const [menuOpen, setMenuOpen] = useState(false);
  const [entryId, setEntryId] = useState(id || null);
  const [createdAt, setCreatedAt] = useState('');
  const [prompts] = useState(() => pickPrompts(3));
  const [leaveOpen, setLeaveOpen] = useState(false);
  const [candlelit, setCandlelit] = useState(false);
  const [sealShow, setSealShow] = useState(false);
  const uploadMemosRef = useRef(null);
  const menuRef = useRef(null);
  // Snapshot of the last-saved (or freshly-templated) field values — the
  // baseline for detecting unsaved changes.
  const snapRef = useRef(null);

  // Apply template for new entries based on type param (+ Card of the Day prefill)
  useEffect(() => {
    if (!isNew) return;
    const tpl = (entryType && TYPE_TEMPLATES[entryType]) || {};
    const card = searchParams.get('card');
    const intention = searchParams.get('intention');
    let t = tpl.title || '';
    let b = tpl.body || '';
    const g = tpl.tags || '';
    if (card) {
      t = t || `Card of the Day — ${card}`;
      b = `<p><strong>🔮 Card of the day: ${card}</strong></p><p>What this card stirs in me…</p>${b}`;
    }
    if (intention) {
      t = t || 'Full Moon Reflection';
      b = `<p><strong>🌕 Full moon reflection</strong></p><p>At the new moon I asked for: "${intention}"</p><p>How it has unfolded…</p>`;
    }
    if (t) setTitle(t);
    if (b) setBody(b);
    if (g) setTags(g);
    snapRef.current = JSON.stringify({
      title: t, body: b, mood: '', tags: g,
      paperStyle: 'lined', themeId: '', isFavorite: false, lockedUntil: '',
    });
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []); // run once on mount only

  const loadEntry = useCallback(async () => {
    if (!id) return;
    try {
      const [entry, photos, memos] = await Promise.all([
        api.getEntry(id),
        api.listPhotos(id),
        api.listVoiceMemos(id),
      ]);
      setTitle(entry.title || '');
      setMood(entry.mood || '');
      setTags(entry.tags || '');
      setPaperStyle(entry.paper_style || 'lined');
      setThemeId(entry.theme_id || '');
      setIsFavorite(entry.is_favorite || false);
      setLockedUntil(entry.locked_until || '');
      setCreatedAt(entry.created_at || '');
      setSavedMemos(memos);
      const html = legacyToHtml(entry.body, photos);
      setBody(html);
      snapRef.current = JSON.stringify({
        title: entry.title || '', body: html, mood: entry.mood || '', tags: entry.tags || '',
        paperStyle: entry.paper_style || 'lined', themeId: entry.theme_id || '',
        isFavorite: entry.is_favorite || false, lockedUntil: entry.locked_until || '',
      });
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => { loadEntry(); }, [loadEntry]);

  useEffect(() => {
    const h = (e) => { if (menuRef.current && !menuRef.current.contains(e.target)) setMenuOpen(false); };
    document.addEventListener('mousedown', h);
    return () => document.removeEventListener('mousedown', h);
  }, []);

  const save = async () => {
    setSaving(true);
    try {
      const payload = {
        title: title.trim(),
        body,
        mood,
        tags,
        paper_style: paperStyle,
        theme_id: themeId || null,
        is_favorite: isFavorite,
        locked_until: lockedUntil || null,
      };
      let savedId = entryId;
      if (isNew || !entryId) {
        const created = await api.createEntry(payload);
        savedId = created.id;
        setEntryId(savedId);
      } else {
        await api.updateEntry(savedId, payload);
      }
      if (uploadMemosRef.current) {
        const newMemos = await uploadMemosRef.current(savedId);
        if (newMemos?.length) setSavedMemos(m => [...m, ...newMemos]);
      }
      // Wax-seal moment when a time capsule is first sealed
      const wasLocked = snapRef.current ? JSON.parse(snapRef.current).lockedUntil : '';
      snapRef.current = JSON.stringify({ title, body, mood, tags, paperStyle, themeId, isFavorite, lockedUntil });
      if (lockedUntil && !wasLocked) {
        setSealShow(true);
        setTimeout(() => setSealShow(false), 2200);
      }
      if (isNew) nav(`/entry/${savedId}`, { replace: true });
      return true;
    } catch (e) {
      alert('Save failed: ' + e.message);
      return false;
    } finally {
      setSaving(false);
    }
  };

  const deleteEntry = async () => {
    if (!entryId) { nav('/timeline'); return; }
    if (!confirm('Delete this entry?')) return;
    await api.deleteEntry(entryId);
    nav('/timeline', { replace: true });
  };

  const deleteMemo = async (memoId) => {
    if (!confirm('Delete this voice memo?')) return;
    await api.deleteVoiceMemo(memoId);
    setSavedMemos(m => m.filter(x => x.id !== memoId));
  };

  const showPrompts = isNew && (!body || body === '<p></p>' || body.trim() === '');
  const insertImage = useCallback(async (file) => resizeToBase64(file), []);

  // Unsaved-changes detection: compare current fields to the saved snapshot
  const currentSnap = JSON.stringify({ title, body, mood, tags, paperStyle, themeId, isFavorite, lockedUntil });
  const dirty = snapRef.current !== null && currentSnap !== snapRef.current;

  useEffect(() => {
    editorDirty.current = dirty;
    return () => { editorDirty.current = false; };
  }, [dirty]);

  // Native browser warning on close/refresh with unsaved changes
  useEffect(() => {
    const h = (e) => { if (editorDirty.current) { e.preventDefault(); e.returnValue = ''; } };
    window.addEventListener('beforeunload', h);
    return () => window.removeEventListener('beforeunload', h);
  }, []);

  const goBack = () => { if (dirty) setLeaveOpen(true); else nav('/timeline'); };

  // Journal theme: scoped CSS vars on the page root only — never touches the
  // global theme (:root vars stay whatever the Timeline picker set).
  const journalTheme = themeId ? themeById(themeId) : null;
  const pageClass = `ee-page ${journalTheme ? 'ee-themed' : ''} ${candlelit ? 'ee-candlelit' : ''}`;
  const pageStyle = journalTheme ? journalTheme.vars : undefined;

  if (loading) return (
    <div className="ee-page">
      <header className="app-header">
        <Link to="/timeline" className="back-btn" title="Back to your journal">⟵</Link>
      </header>
      <div className="ee-loading">Loading…</div>
    </div>
  );

  return (
    <div className={pageClass} style={pageStyle}>
      <header className="app-header">
        <button className="back-btn" onClick={goBack} title="Back to your journal">⟵</button>
        <input
          className="ee-title-input"
          placeholder="✎ Give this entry a title…"
          value={title}
          onChange={e => setTitle(e.target.value)}
          maxLength={200}
        />
        <button
          className={`ee-round-btn ee-candle-btn ${candlelit ? 'on' : ''}`}
          onClick={() => setCandlelit(c => !c)}
          title={candlelit ? 'Blow out the candle' : 'Light a candle · cozy writing mode'}
        >🕯️</button>
        <button
          className={`ee-round-btn ee-fav-btn ${isFavorite ? 'on' : ''}`}
          onClick={() => setIsFavorite(f => !f)}
          title={isFavorite ? 'Remove from favorites' : 'Add to favorites'}
        >{isFavorite ? '⭐' : '☆'}</button>
        <button
          className={`btn ee-save-btn ${dirty ? 'ee-save-dirty' : 'ee-save-clean'}`}
          onClick={save}
          disabled={saving}
        >
          {saving ? 'Sealing…' : dirty || !entryId ? '✦ Save' : 'Saved ☾'}
        </button>
        <div className="ee-menu-wrap" ref={menuRef}>
          <button className="btn icon-btn" onClick={() => setMenuOpen(o => !o)} title="More">⋮</button>
          {menuOpen && (
            <div className="ee-menu">
              <button className="tl-menu-item danger" onClick={() => { deleteEntry(); setMenuOpen(false); }}>
                🗑️ Delete entry
              </button>
            </div>
          )}
        </div>
      </header>

      <div className="ee-layout">
        {/* ── Sidebar ── */}
        <aside className="ee-sidebar">
          <div className="ee-sidebar-art" aria-hidden="true">
            <span className="ee-sidebar-moon">🌙</span>
            <div className="ee-sidebar-sparkle">✦ · ✦</div>
          </div>
          <div className="ee-sidebar-inner">
            <section className="ee-section">
              <h4 className="ee-section-label">Mood</h4>
              <div className="ee-mood-grid">
                {MOODS.map((m) => {
                  const mc = m ? moodColor(m) : null;
                  const sel = mood === m;
                  return (
                    <button
                      key={m || 'none'}
                      className={`ee-mood-btn ${sel ? 'sel' : ''}`}
                      style={sel && mc ? { '--mc': mc, background: `color-mix(in srgb, ${mc} 18%, var(--surface-2))`, borderColor: mc } : {}}
                      onClick={() => setMood(m)}
                      title={m || 'No mood'}
                    >
                      {m || '○'}
                    </button>
                  );
                })}
              </div>
            </section>

            <section className="ee-section">
              <h4 className="ee-section-label">Paper</h4>
              <div className="ee-paper-row">
                {PAPER_STYLES.map(p => (
                  <button
                    key={p.id}
                    className={`ee-paper-btn ${paperStyle === p.id ? 'sel' : ''}`}
                    onClick={() => setPaperStyle(p.id)}
                    title={p.label}
                  >
                    <span className="ee-paper-icon">{p.icon}</span>
                    <span className="ee-paper-label">{p.label}</span>
                  </button>
                ))}
              </div>
            </section>

            <section className="ee-section">
              <h4 className="ee-section-label">Journal Theme</h4>
              <div className="ee-theme-row">
                <button
                  className={`ee-theme-btn ${!themeId ? 'sel' : ''}`}
                  onClick={() => setThemeId('')}
                  title="Use global theme"
                >
                  <span className="ee-theme-dot" style={{ background: 'var(--accent)' }} />
                  Default
                </button>
                {THEMES.map(t => (
                  <button
                    key={t.id}
                    className={`ee-theme-btn ${themeId === t.id ? 'sel' : ''}`}
                    onClick={() => setThemeId(t.id)}
                    title={t.name}
                  >
                    <span className="ee-theme-dot" style={{ background: t.dot }} />
                    {t.name}
                  </button>
                ))}
              </div>
            </section>

            <section className="ee-section">
              <h4 className="ee-section-label">Tags</h4>
              <TagInput value={tags} onChange={setTags} />
            </section>

            <section className="ee-section">
              <h4 className="ee-section-label">Lock until</h4>
              <input
                className="ee-lock-input"
                type="date"
                min={tomorrowStr()}
                value={lockedUntil ? lockedUntil.split('T')[0] : ''}
                onChange={e => setLockedUntil(e.target.value)}
              />
              {lockedUntil && <p className="ee-lock-note muted">Capsule opens after this date.</p>}
            </section>
          </div>

          {/* Voice memos anchored to bottom of sidebar */}
          <div className="ee-voice-section">
            {savedMemos.map(m => (
              <VoiceMemoPlayer key={m.id} memo={m} onDelete={entryId ? deleteMemo : null} />
            ))}
            <VoiceRecorder onSaved={(fn) => { uploadMemosRef.current = fn; }} />
          </div>
        </aside>

        {/* ── Editor ── */}
        <main className="ee-editor-area">
          {createdAt && (
            <p className="ee-date-label">
              {new Date(createdAt).toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' })}
            </p>
          )}
          <RichEditor
            value={body}
            onChange={(html) => setBody(html)}
            placeholder="Write here… let your thoughts flow 🌙"
            paperStyle={paperStyle}
            insertImageFn={insertImage}
          />
          {showPrompts && (
            <div className="ee-prompts">
              <p className="ee-prompts-label">Writing prompts</p>
              {prompts.map((p, i) => (
                <button
                  key={i}
                  className="ee-prompt-btn"
                  onClick={() => setBody(`<p>${p}</p>`)}
                >
                  {p}
                </button>
              ))}
            </div>
          )}
        </main>
      </div>

      {/* Candlelit ambience */}
      {candlelit && <div className="ee-candle-glow" aria-hidden="true">🕯️</div>}

      {/* Unsaved-changes guard */}
      {leaveOpen && (
        <div className="ne-overlay" onClick={() => setLeaveOpen(false)}>
          <div className="sealed-dialog" onClick={e => e.stopPropagation()}>
            <div className="sealed-dialog-icon">🕯️</div>
            <h3 className="sealed-dialog-title cinzel">Unsaved Changes</h3>
            <p className="sealed-dialog-body">This page holds words you haven't saved yet.</p>
            <div className="ee-leave-actions">
              <button className="btn" onClick={async () => { setLeaveOpen(false); if (await save()) nav('/timeline'); }}>
                ✦ Save &amp; leave
              </button>
              <button className="btn ghost" onClick={() => nav('/timeline')}>Leave without saving</button>
              <button className="btn ghost" onClick={() => setLeaveOpen(false)}>Stay</button>
            </div>
          </div>
        </div>
      )}

      {/* Wax-seal moment for newly sealed time capsules */}
      {sealShow && (
        <div className="ee-seal-overlay" aria-hidden="true">
          <div className="ee-seal-stamp">
            <span className="ee-seal-moon">☾</span>
            <span className="ee-seal-text cinzel">Sealed</span>
          </div>
        </div>
      )}
    </div>
  );
}
