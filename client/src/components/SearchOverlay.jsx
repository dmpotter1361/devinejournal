import { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, getToken } from '../api';
import { moodColor } from '../moods';
import './SearchOverlay.css';

export const OPEN_SEARCH_EVENT = 'dj:open-search';
export const openSearch = () => window.dispatchEvent(new CustomEvent(OPEN_SEARCH_EVENT));

// Strip an entry body (HTML, legacy JSON blocks, or plain text) down to searchable text.
function bodyText(body) {
  if (!body) return '';
  const s = body.trimStart();
  if (s.startsWith('[')) {
    try {
      return JSON.parse(s).filter(b => b.type === 'text').map(b => b.content || '').join(' ');
    } catch { /* fall through */ }
  }
  const tmp = document.createElement('div');
  tmp.innerHTML = body;
  return tmp.textContent || '';
}

// Build a snippet around the first match: { before, match, after } or null.
function makeSnippet(text, query, radius = 70) {
  const clean = text.replace(/\s+/g, ' ').trim();
  const idx = clean.toLowerCase().indexOf(query.toLowerCase());
  if (idx === -1) return clean ? { before: clean.slice(0, radius * 2), match: '', after: '' } : null;
  const start = Math.max(0, idx - radius);
  const end = Math.min(clean.length, idx + query.length + radius);
  return {
    before: (start > 0 ? '…' : '') + clean.slice(start, idx),
    match: clean.slice(idx, idx + query.length),
    after: clean.slice(idx + query.length, end) + (end < clean.length ? '…' : ''),
  };
}

function Highlight({ text, query }) {
  if (!text || !query) return text || '';
  const idx = text.toLowerCase().indexOf(query.toLowerCase());
  if (idx === -1) return text;
  return (
    <>
      {text.slice(0, idx)}
      <mark className="so-mark">{text.slice(idx, idx + query.length)}</mark>
      {text.slice(idx + query.length)}
    </>
  );
}

export default function SearchOverlay() {
  const nav = useNavigate();
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const [results, setResults] = useState([]);
  const [searching, setSearching] = useState(false);
  const [selected, setSelected] = useState(0);
  const inputRef = useRef(null);
  const listRef = useRef(null);
  const reqSeq = useRef(0);

  const close = useCallback(() => {
    setOpen(false);
    setQuery('');
    setResults([]);
    setSelected(0);
  }, []);

  // Global open triggers: Ctrl/Cmd+K and the custom event (header button)
  useEffect(() => {
    const onKey = (e) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        if (!getToken()) return;
        e.preventDefault();
        setOpen(true);
      }
    };
    const onOpen = () => { if (getToken()) setOpen(true); };
    window.addEventListener('keydown', onKey);
    window.addEventListener(OPEN_SEARCH_EVENT, onOpen);
    return () => {
      window.removeEventListener('keydown', onKey);
      window.removeEventListener(OPEN_SEARCH_EVENT, onOpen);
    };
  }, []);

  useEffect(() => {
    if (open) setTimeout(() => inputRef.current?.focus(), 30);
  }, [open]);

  // Debounced server search
  useEffect(() => {
    if (!open) return;
    const q = query.trim();
    if (!q) { setResults([]); setSearching(false); setSelected(0); return; }
    setSearching(true);
    const seq = ++reqSeq.current;
    const t = setTimeout(async () => {
      try {
        const data = await api.searchEntries(q);
        if (seq === reqSeq.current) {
          setResults(data);
          setSelected(0);
          setSearching(false);
        }
      } catch {
        if (seq === reqSeq.current) { setResults([]); setSearching(false); }
      }
    }, 250);
    return () => clearTimeout(t);
  }, [query, open]);

  const openEntry = useCallback((entry) => {
    close();
    nav(`/entry/${entry.id}`);
  }, [close, nav]);

  const onInputKey = (e) => {
    if (e.key === 'Escape') { close(); return; }
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setSelected(s => Math.min(s + 1, results.length - 1));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setSelected(s => Math.max(s - 1, 0));
    } else if (e.key === 'Enter' && results[selected]) {
      openEntry(results[selected]);
    }
  };

  // Keep the selected result scrolled into view
  useEffect(() => {
    listRef.current?.children[selected]?.scrollIntoView({ block: 'nearest' });
  }, [selected]);

  if (!open) return null;

  const q = query.trim();

  return (
    <div className="so-overlay" onClick={close}>
      <div className="so-panel" onClick={e => e.stopPropagation()}>
        <div className="so-input-row">
          <span className="so-input-icon" aria-hidden="true">🔍</span>
          <input
            ref={inputRef}
            className="so-input"
            type="text"
            placeholder="Search your journal…"
            value={query}
            onChange={e => setQuery(e.target.value)}
            onKeyDown={onInputKey}
            aria-label="Search your journal"
          />
          <button className="so-esc" onClick={close}>esc</button>
        </div>

        {q && (
          <div className="so-results" ref={listRef}>
            {searching && results.length === 0 && (
              <div className="so-state">Searching…</div>
            )}
            {!searching && results.length === 0 && (
              <div className="so-state">
                <span className="so-state-icon">🌙</span>
                Nothing found for “{q}”
              </div>
            )}
            {results.map((e, i) => {
              const d = new Date(e.created_at);
              const snippet = makeSnippet(bodyText(e.body), q);
              const mc = moodColor(e.mood);
              return (
                <button
                  key={e.id}
                  className={`so-result ${i === selected ? 'so-selected' : ''}`}
                  onClick={() => openEntry(e)}
                  onMouseEnter={() => setSelected(i)}
                >
                  <div className="so-r-top">
                    {e.mood && <span className="so-r-mood" style={mc ? { '--mc': mc } : {}}>{e.mood}</span>}
                    <span className="so-r-title">
                      {e.title ? <Highlight text={e.title} query={q} /> : <em className="so-untitled">untitled</em>}
                    </span>
                    <span className="so-r-date">
                      {d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
                    </span>
                  </div>
                  {snippet && (
                    <p className="so-r-snippet">
                      {snippet.before}
                      {snippet.match && <mark className="so-mark">{snippet.match}</mark>}
                      {snippet.after}
                    </p>
                  )}
                  {e.tags && (
                    <div className="so-r-tags">
                      {e.tags.split(',').map(t => t.trim()).filter(Boolean).map(t => (
                        <span key={t} className="so-r-tag"><Highlight text={t} query={q} /></span>
                      ))}
                    </div>
                  )}
                </button>
              );
            })}
          </div>
        )}

        <div className="so-footer">
          <span><kbd>↑</kbd><kbd>↓</kbd> navigate</span>
          <span><kbd>↵</kbd> open</span>
          <span><kbd>esc</kbd> close</span>
        </div>
      </div>
    </div>
  );
}
