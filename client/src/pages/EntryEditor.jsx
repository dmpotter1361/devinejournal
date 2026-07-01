import { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate, useParams, Link } from 'react-router-dom';
import { api } from '../api';
import { MOODS, moodColor } from '../moods';
import { THEMES, themeById } from '../themes';
import RichEditor, { resizeToBase64 } from '../components/RichEditor';
import './EntryEditor.css';

const PAPER_STYLES = [
  { id: 'plain',  label: 'Plain',  icon: '□' },
  { id: 'lined',  label: 'Lined',  icon: '≡' },
  { id: 'dotted', label: 'Dotted', icon: '⠿' },
  { id: 'grid',   label: 'Grid',   icon: '⊞' },
];

// Convert legacy JSON block body to TipTap HTML.
function legacyToHtml(body, photos) {
  if (!body || body.trim() === '') return '';
  if (body.trimStart().startsWith('<')) return body;
  if (body.trimStart().startsWith('[')) {
    try {
      const blocks = JSON.parse(body);
      return blocks.map(b => {
        if (b.type === 'text') return `<p>${(b.content || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')}</p>`;
        if (b.type === 'image') {
          const photo = photos.find(p => p.id === b.photo_id);
          const src = photo ? photo.data : '';
          const align = b.align || 'center';
          const w = b.width ? ` width="${b.width}"` : '';
          const cap = b.caption || '';
          return src ? `<figure class="ds-figure ds-align-${align}" data-align="${align}"><img src="${src}"${w}><figcaption>${cap}</figcaption></figure>` : '';
        }
        return '';
      }).join('');
    } catch { /* */ }
  }
  return `<p>${body.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/\n/g, '</p><p>')}</p>`;
}

function VoiceMemoPlayer({ memo, onDelete }) {
  const fmtDuration = (ms) => {
    const s = Math.round(Number(ms) / 1000);
    return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
  };
  return (
    <div className="vm-player">
      <audio controls src={memo.data} className="vm-audio" />
      <span className="vm-dur muted">{fmtDuration(memo.duration_ms)}</span>
      {onDelete && (
        <button className="vm-del btn icon-btn" onClick={() => onDelete(memo.id)} title="Delete">🗑️</button>
      )}
    </div>
  );
}

function VoiceRecorder({ entryId, onSaved }) {
  const [recording, setRecording] = useState(false);
  const [pending, setPending] = useState([]); // { blob, durationMs, url }
  const mrRef = useRef(null);
  const startRef = useRef(0);
  const chunksRef = useRef([]);

  const startRec = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      chunksRef.current = [];
      startRef.current = performance.now();
      const mr = new MediaRecorder(stream, { mimeType: 'audio/webm' });
      mr.ondataavailable = e => { if (e.data.size > 0) chunksRef.current.push(e.data); };
      mr.onstop = () => {
        const durationMs = performance.now() - startRef.current;
        const blob = new Blob(chunksRef.current, { type: 'audio/webm' });
        const url = URL.createObjectURL(blob);
        setPending(p => [...p, { blob, durationMs, url, id: String(Date.now()) }]);
        stream.getTracks().forEach(t => t.stop());
      };
      mr.start();
      mrRef.current = mr;
      setRecording(true);
    } catch (e) {
      alert('Microphone access denied');
    }
  };

  const stopRec = () => {
    mrRef.current?.stop();
    mrRef.current = null;
    setRecording(false);
  };

  const removePending = (id) => {
    setPending(p => { const m = p.find(x => x.id === id); if (m) URL.revokeObjectURL(m.url); return p.filter(x => x.id !== id); });
  };

  const uploadAll = useCallback(async (id) => {
    if (!pending.length) return [];
    const saved = [];
    for (const m of pending) {
      const memo = await api.uploadVoiceMemo(id, m.blob, m.durationMs);
      URL.revokeObjectURL(m.url);
      saved.push(memo);
    }
    setPending([]);
    return saved;
  }, [pending]);

  // Expose uploadAll so parent can call it after saving the entry
  useEffect(() => { if (onSaved) onSaved(uploadAll); }, [uploadAll, onSaved]);

  return (
    <div className="voice-section">
      <div className="voice-section-header">
        <span className="voice-section-label">🎙️ Voice memos</span>
        <button
          className={`vm-rec-btn btn ${recording ? 'vm-recording' : ''}`}
          onClick={recording ? stopRec : startRec}
        >
          {recording ? '⏹ Stop' : '⏺ Record'}
        </button>
      </div>
      {pending.map(m => (
        <div key={m.id} className="vm-player">
          <audio controls src={m.url} className="vm-audio" />
          <span className="muted vm-dur">
            {Math.round(m.durationMs / 1000)}s
          </span>
          <button className="vm-del btn icon-btn" onClick={() => removePending(m.id)} title="Discard">🗑️</button>
        </div>
      ))}
    </div>
  );
}

export default function EntryEditor() {
  const { id } = useParams();
  const nav = useNavigate();
  const isNew = !id;

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
  const [dirty, setDirty] = useState(false);
  const uploadMemosRef = useRef(null);
  const menuRef = useRef(null);
  const [entryId, setEntryId] = useState(id || null);
  const [createdAt, setCreatedAt] = useState('');

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
      setBody(legacyToHtml(entry.body, photos));
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

      // Upload any pending voice memos
      if (uploadMemosRef.current) {
        const newMemos = await uploadMemosRef.current(savedId);
        if (newMemos?.length) setSavedMemos(m => [...m, ...newMemos]);
      }

      setDirty(false);
      if (isNew) nav(`/entry/${savedId}`, { replace: true });
    } catch (e) {
      alert('Save failed: ' + e.message);
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

  const uploadImageForEditor = useCallback(async (file) => {
    return resizeToBase64(file);
  }, []);

  const moodCol = mood ? moodColor(mood) : null;

  if (loading) return (
    <div className="ee-page">
      <header className="app-header"><Link to="/timeline" className="btn ghost icon-btn">←</Link></header>
      <div className="ee-loading">Loading…</div>
    </div>
  );

  return (
    <div className="ee-page">
      <header className="app-header">
        <Link to="/timeline" className="btn ghost icon-btn" title="Back">←</Link>
        <input
          className="ee-title-input"
          placeholder="Entry title (optional)"
          value={title}
          onChange={e => { setTitle(e.target.value); setDirty(true); }}
          maxLength={200}
        />
        <button
          className="btn ee-save-btn"
          onClick={save}
          disabled={saving}
        >
          {saving ? '…' : '✓ Save'}
        </button>
        <div className="ee-menu-wrap" ref={menuRef}>
          <button className="btn icon-btn" onClick={() => setMenuOpen(o => !o)} title="More">⋮</button>
          {menuOpen && (
            <div className="ee-menu">
              <button className="tl-menu-item" onClick={() => { setIsFavorite(f => !f); setDirty(true); setMenuOpen(false); }}>
                {isFavorite ? '⭐ Remove favorite' : '☆ Add to favorites'}
              </button>
              <button className="tl-menu-item danger" onClick={() => { deleteEntry(); setMenuOpen(false); }}>
                🗑️ Delete entry
              </button>
            </div>
          )}
        </div>
      </header>

      <div className="ee-layout">
        {/* Sidebar / metadata panel */}
        <aside className="ee-sidebar">
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
                      onClick={() => { setMood(m); setDirty(true); }}
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
                    onClick={() => { setPaperStyle(p.id); setDirty(true); }}
                    title={p.label}
                  >
                    <span className="ee-paper-icon">{p.icon}</span>
                    <span className="ee-paper-label">{p.label}</span>
                  </button>
                ))}
              </div>
            </section>

            <section className="ee-section">
              <h4 className="ee-section-label">Theme</h4>
              <div className="ee-theme-row">
                <button
                  className={`ee-theme-btn ${!themeId ? 'sel' : ''}`}
                  onClick={() => { setThemeId(''); setDirty(true); }}
                  title="Global theme"
                >
                  <span className="ee-theme-dot" style={{ background: 'var(--accent)' }} />
                  Default
                </button>
                {THEMES.map(t => (
                  <button
                    key={t.id}
                    className={`ee-theme-btn ${themeId === t.id ? 'sel' : ''}`}
                    onClick={() => { setThemeId(t.id); setDirty(true); }}
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
              <input
                className="ee-tags-input"
                placeholder="gratitude, dreams, …"
                value={tags}
                onChange={e => { setTags(e.target.value); setDirty(true); }}
              />
              {tags && (
                <div className="ee-tags-preview">
                  {tags.split(',').map(t => t.trim()).filter(Boolean).map(t => (
                    <span key={t} className="tag">{t}</span>
                  ))}
                </div>
              )}
            </section>

            <section className="ee-section">
              <h4 className="ee-section-label">Lock until</h4>
              <input
                className="ee-lock-input"
                type="date"
                value={lockedUntil ? lockedUntil.split('T')[0] : ''}
                onChange={e => { setLockedUntil(e.target.value); setDirty(true); }}
              />
              {lockedUntil && <p className="ee-lock-note muted">Capsule opens after this date.</p>}
            </section>
          </div>
        </aside>

        {/* Editor area */}
        <main className="ee-editor-area">
          {createdAt && <p className="ee-date-label muted">
            {new Date(createdAt).toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' })}
          </p>}
          <RichEditor
            value={body}
            onChange={(html) => { setBody(html); setDirty(true); }}
            placeholder="Write here… let your thoughts flow 🌙"
            paperStyle={paperStyle}
            insertImageFn={uploadImageForEditor}
          />
          {/* Voice memos */}
          <div className="ee-memos">
            {savedMemos.map(m => (
              <VoiceMemoPlayer key={m.id} memo={m} onDelete={entryId ? deleteMemo : null} />
            ))}
            <VoiceRecorder
              entryId={entryId}
              onSaved={(fn) => { uploadMemosRef.current = fn; }}
            />
          </div>
        </main>
      </div>
    </div>
  );
}
