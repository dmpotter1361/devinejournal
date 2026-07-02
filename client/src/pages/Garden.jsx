import { useCallback, useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { api } from '../api';
import {
  CYCLE_DAYS, GARDEN_STAGES, getStage, isGratitude,
  buildGarden, bloomMonth, bloomEntries,
} from '../lib/garden';
import './Garden.css';

export default function Garden() {
  const nav = useNavigate();
  const [entries, setEntries] = useState([]);
  const [loading, setLoading] = useState(true);
  const [picked, setPicked] = useState(null); // index of expanded bloom

  const load = useCallback(async () => {
    try { setEntries(await api.listEntries()); }
    catch (e) { console.error(e); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { load(); }, [load]);

  const gratEntries = entries.filter(isGratitude);
  const g = buildGarden(gratEntries);
  const stage = GARDEN_STAGES[getStage(g.currentDays)];
  const pickedBloom = picked !== null ? g.blooms[picked] : null;
  const pickedDetail = pickedBloom ? bloomEntries(pickedBloom, gratEntries) : [];

  return (
    <div className="gd-page">
      <header className="app-header">
        <Link to="/timeline" className="back-btn" title="Back to your journal">⟵</Link>
        <span className="header-spacer" />
        <span className="brand cinzel gd-brand">❀ Gratitude Garden ❀</span>
        <span className="header-spacer" />
      </header>

      <div className="gd-body">
        {loading ? (
          <div className="gd-state">Tending the soil…</div>
        ) : !g.hadAny ? (
          <div className="gd-empty">
            <span className="gd-empty-seed">🌱</span>
            <h3 className="gd-empty-title cinzel">Your garden is still a quiet patch of soil.</h3>
            <p className="gd-empty-sub">Plant a gratitude entry and watch it grow.</p>
            <button className="btn" onClick={() => nav('/entry/new?type=gratitude')}>🙏 Write a gratitude entry</button>
          </div>
        ) : (
          <>
            {/* Current plant status */}
            <div className="gd-now card">
              <span className="gd-now-plant">
                {g.currentDays === 0 ? '🫘' : stage.emoji}
              </span>
              <div className="gd-now-text">
                {g.currentDays > 0 ? (
                  <>
                    <span className="gd-now-line">
                      Your current plant has <strong>{g.currentDays}</strong> day{g.currentDays === 1 ? '' : 's'} of gratitude — {stage.label}
                      {g.resting && ' · resting 🌙'}
                    </span>
                    <span className="gd-now-sub">{CYCLE_DAYS - g.currentDays} more day{CYCLE_DAYS - g.currentDays === 1 ? '' : 's'} until it blooms into the garden</span>
                  </>
                ) : (
                  <span className="gd-now-line">A fresh seed rests in the soil — write a gratitude entry to wake it 🌱</span>
                )}
              </div>
            </div>

            {/* The bed of harvested blooms */}
            <p className="gd-count cinzel">
              {g.blooms.length === 0
                ? 'No blooms yet — your first flower arrives after a full cycle of gratitude'
                : `${g.blooms.length} bloom${g.blooms.length === 1 ? '' : 's'} planted since you began`}
            </p>

            {g.blooms.length > 0 && (
              <div className="gd-bed card">
                {g.blooms.map((b, i) => (
                  <button
                    key={`${b.end}-${i}`}
                    className={`gd-bloom ${picked === i ? 'gd-picked' : ''}`}
                    onClick={() => setPicked(picked === i ? null : i)}
                  >
                    <span className="gd-bloom-flower">{b.emoji}</span>
                    <span className="gd-bloom-month">{new Date(b.end).toLocaleDateString('en-US', { month: 'short', year: '2-digit' })}</span>
                  </button>
                ))}
              </div>
            )}

            {/* Expanded bloom — the real gratitude that grew it */}
            {pickedBloom && (
              <div className="gd-detail card">
                <div className="gd-detail-head">
                  <span className="gd-detail-flower">{pickedBloom.emoji}</span>
                  <div>
                    <h3 className="gd-detail-title cinzel">Grew from {CYCLE_DAYS} days of gratitude</h3>
                    <p className="gd-detail-sub">{bloomMonth(pickedBloom)}</p>
                  </div>
                  <button className="btn icon-btn gd-detail-close" onClick={() => setPicked(null)}>✕</button>
                </div>
                <div className="gd-lines">
                  {(() => {
                    const flat = pickedDetail.flatMap(({ entry, lines }) =>
                      lines.slice(0, 3).map((line, li) => ({ entry, line, key: `${entry.id}-${li}` }))
                    );
                    if (flat.length === 0) {
                      return <p className="gd-line-none muted">The words from this cycle rest inside their entries — tap a date on the Almanac to revisit them.</p>;
                    }
                    return (
                      <>
                        {flat.slice(0, 10).map(({ entry, line, key }) => (
                          <button key={key} className="gd-line" onClick={() => nav(`/entry/${entry.id}`)}>
                            <span className="gd-line-petal">❀</span>
                            <span className="gd-line-text">“{line}”</span>
                            <span className="gd-line-date">
                              {new Date(entry.created_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}
                            </span>
                          </button>
                        ))}
                        {flat.length > 10 && (
                          <p className="gd-line-none muted">…and {flat.length - 10} more moments of gratitude in this cycle</p>
                        )}
                      </>
                    );
                  })()}
                </div>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
