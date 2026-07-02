import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api';
import { isSealed, opensOn } from '../lib/seal';
import './PrintView.css';

// Body → printable HTML (handles legacy Flutter JSON-block bodies)
function printableHtml(body) {
  if (!body) return '';
  const s = body.trimStart();
  if (s.startsWith('[')) {
    try {
      return JSON.parse(s)
        .filter(b => b.type === 'text')
        .map(b => `<p>${(b.content || '').replace(/&/g, '&amp;').replace(/</g, '&lt;')}</p>`)
        .join('');
    } catch { /* fall through */ }
  }
  if (s.startsWith('<')) return body;
  return `<p>${body.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/\n/g, '</p><p>')}</p>`;
}

export default function PrintView() {
  const [entries, setEntries] = useState([]);
  const [loading, setLoading] = useState(true);
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');

  const load = useCallback(async () => {
    try {
      const data = await api.listEntries();
      // oldest → newest reads like a book
      setEntries([...data].sort((a, b) => new Date(a.created_at) - new Date(b.created_at)));
    } catch (e) { console.error(e); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { load(); }, [load]);

  const filtered = entries.filter(e => {
    const d = new Date(e.created_at);
    if (from && d < new Date(from)) return false;
    if (to && d > new Date(`${to}T23:59:59`)) return false;
    return true;
  });

  return (
    <div className="pv-page">
      <header className="app-header pv-controls">
        <Link to="/timeline" className="back-btn" title="Back to your journal">⟵</Link>
        <span className="pv-title cinzel">🖨️ Print Journal</span>
        <div className="pv-range">
          <label className="pv-range-label">From <input type="date" value={from} onChange={e => setFrom(e.target.value)} /></label>
          <label className="pv-range-label">To <input type="date" value={to} onChange={e => setTo(e.target.value)} /></label>
        </div>
        <button className="btn" onClick={() => window.print()}>✦ Print{filtered.length ? ` ${filtered.length} entries` : ''}</button>
      </header>

      <div className="pv-paper">
        <div className="pv-cover">
          <h1 className="pv-cover-title">☽ My Journal ☾</h1>
          <p className="pv-cover-sub">
            {filtered.length} entries
            {filtered.length > 0 && (
              <> · {new Date(filtered[0].created_at).toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}
              {' — '}
              {new Date(filtered[filtered.length - 1].created_at).toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}</>
            )}
          </p>
        </div>

        {loading && <p className="pv-state">Gathering your pages…</p>}
        {!loading && filtered.length === 0 && <p className="pv-state">No entries in this range.</p>}

        {filtered.map(e => (
          <article key={e.id} className="pv-entry">
            <div className="pv-entry-head">
              <h2 className="pv-entry-title">{e.mood && <span className="pv-entry-mood">{e.mood} </span>}{e.title || 'Untitled'}</h2>
              <span className="pv-entry-date">
                {new Date(e.created_at).toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' })}
              </span>
            </div>
            {e.tags && <p className="pv-entry-tags">{e.tags.split(',').map(t => t.trim()).filter(Boolean).map(t => `#${t}`).join('  ')}</p>}
            {isSealed(e) ? (
              <p className="pv-sealed">🔒 Sealed until {opensOn(e.locked_until).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })}</p>
            ) : (
              // eslint-disable-next-line react/no-danger
              <div className="pv-entry-body" dangerouslySetInnerHTML={{ __html: printableHtml(e.body) }} />
            )}
          </article>
        ))}
      </div>
    </div>
  );
}
