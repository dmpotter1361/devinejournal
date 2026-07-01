import { useCallback, useEffect, useRef, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { api, clearAuth, getUser } from '../api';
import { MOODS, moodColor } from '../moods';
import { THEMES, themeById, applyTheme } from '../themes';
import './Timeline.css';

function plainText(html) {
  if (!html) return '';
  if (html.trimStart().startsWith('[')) {
    try {
      return JSON.parse(html).filter(b => b.type === 'text').map(b => b.content || '').join(' ').slice(0, 160);
    } catch { /* */ }
  }
  const tmp = document.createElement('div');
  tmp.innerHTML = html;
  return (tmp.textContent || '').slice(0, 160);
}

function formatDate(iso) {
  const d = new Date(iso);
  return d.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric', year: 'numeric' });
}

function EntryCard({ entry, onClick }) {
  const mc = moodColor(entry.mood);
  const theme = themeById(entry.theme_id || 'midnight');
  const preview = plainText(entry.body);

  return (
    <button className="entry-card" onClick={onClick} style={{ '--theme-dot': theme.dot }}>
      <div className="entry-card-header">
        <span className="entry-card-date">{formatDate(entry.created_at)}</span>
        <div className="entry-card-meta">
          {entry.is_favorite && <span className="entry-card-fav" title="Favorite">⭐</span>}
          {entry.mood && (
            <span className="entry-card-mood" style={{ '--mc': mc || 'var(--muted)' }}>
              {entry.mood}
            </span>
          )}
          <span className="entry-card-dot" title={theme.name} />
        </div>
      </div>
      {entry.title && <h3 className="entry-card-title">{entry.title}</h3>}
      {preview && <p className="entry-card-preview">{preview}</p>}
      {entry.tags && (
        <div className="entry-card-tags">
          {entry.tags.split(',').map(t => t.trim()).filter(Boolean).map(t => (
            <span key={t} className="tag">{t}</span>
          ))}
        </div>
      )}
    </button>
  );
}

export default function Timeline() {
  const nav = useNavigate();
  const user = getUser();
  const [entries, setEntries] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');
  const [moodFilter, setMoodFilter] = useState('');
  const [favOnly, setFavOnly] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [themeOpen, setThemeOpen] = useState(false);
  const menuRef = useRef(null);

  const load = useCallback(async () => {
    try {
      setError('');
      const data = await api.listEntries();
      setEntries(data);
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  useEffect(() => {
    const h = (e) => {
      if (menuRef.current && !menuRef.current.contains(e.target)) {
        setMenuOpen(false);
        setThemeOpen(false);
      }
    };
    document.addEventListener('mousedown', h);
    return () => document.removeEventListener('mousedown', h);
  }, []);

  const signOut = () => { clearAuth(); nav('/', { replace: true }); };

  const filtered = entries.filter(e => {
    if (favOnly && !e.is_favorite) return false;
    if (moodFilter && e.mood !== moodFilter) return false;
    if (search) {
      const q = search.toLowerCase();
      return (e.title || '').toLowerCase().includes(q) ||
             (e.body || '').toLowerCase().includes(q) ||
             (e.tags || '').toLowerCase().includes(q);
    }
    return true;
  });

  return (
    <div className="tl-page">
      <header className="app-header">
        <Link to="/timeline" className="brand">🌙 <span className="cinzel">DevineJournal</span></Link>
        <div className="header-spacer" />
        <Link to="/calendar" className="btn icon-btn" title="Calendar">📅</Link>
        <div className="tl-user-menu" ref={menuRef}>
          <button className="tl-avatar-btn" onClick={() => { setMenuOpen(o => !o); setThemeOpen(false); }}>
            {user?.picture
              ? <img src={user.picture} alt={user.name || 'User'} className="tl-avatar" />
              : <span className="tl-avatar-fallback">👤</span>
            }
          </button>
          {menuOpen && (
            <div className="tl-menu">
              <div className="tl-menu-name">{user?.name || 'Journal'}</div>
              <button className="tl-menu-item" onClick={() => { setMenuOpen(false); setThemeOpen(true); }}>🎨 Change theme</button>
              <button className="tl-menu-item danger" onClick={signOut}>🚪 Sign out</button>
              {themeOpen && (
                <div className="tl-theme-picker">
                  {THEMES.map(t => (
                    <button key={t.id} className="tl-theme-btn" onClick={() => {
                      applyTheme(t.id);
                      localStorage.setItem('dj_theme', t.id);
                      setThemeOpen(false);
                      setMenuOpen(false);
                    }}>
                      <span className="tl-theme-dot" style={{ background: t.dot }} />
                      {t.name}
                    </button>
                  ))}
                </div>
              )}
            </div>
          )}
        </div>
      </header>

      <div className="tl-filters">
        <input
          className="tl-search"
          type="search"
          placeholder="Search entries…"
          value={search}
          onChange={e => setSearch(e.target.value)}
        />
        <div className="tl-mood-filter">
          <button
            className={`tl-mood-chip ${!moodFilter ? 'active' : ''}`}
            onClick={() => setMoodFilter('')}
            title="All moods"
          >All</button>
          {MOODS.filter(Boolean).map(m => (
            <button
              key={m}
              className={`tl-mood-chip ${moodFilter === m ? 'active' : ''}`}
              onClick={() => setMoodFilter(f => f === m ? '' : m)}
              style={moodFilter === m ? { '--mc': moodColor(m) || 'var(--accent)', background: 'color-mix(in srgb, var(--mc) 20%, var(--surface))', borderColor: 'var(--mc)' } : {}}
            >{m}</button>
          ))}
        </div>
        <button
          className={`tl-fav-btn ${favOnly ? 'active' : ''}`}
          onClick={() => setFavOnly(f => !f)}
          title={favOnly ? 'Show all' : 'Favorites only'}
        >⭐ {favOnly ? 'Favs' : 'Favorites'}</button>
      </div>

      <main className="tl-main">
        {loading && <div className="tl-state">Loading your journal…</div>}
        {error && <div className="tl-state tl-error">{error}</div>}
        {!loading && !error && filtered.length === 0 && (
          <div className="tl-state">
            {entries.length === 0
              ? <><p className="tl-empty-icon">🌙</p><p>Your journal is empty.</p><p className="muted">Write your first entry.</p></>
              : <><p className="tl-empty-icon">🔍</p><p className="muted">No entries match.</p></>
            }
          </div>
        )}
        <div className="tl-grid">
          {filtered.map(e => (
            <EntryCard key={e.id} entry={e} onClick={() => nav(`/entry/${e.id}`)} />
          ))}
        </div>
      </main>

      <button className="tl-fab" onClick={() => nav('/entry/new')} title="New entry">
        ✦ New Entry
      </button>
    </div>
  );
}
