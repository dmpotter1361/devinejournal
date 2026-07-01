import { useCallback, useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { api } from '../api';
import { moodColor } from '../moods';
import './Calendar.css';

const MONTH_NAMES = ['January','February','March','April','May','June',
                     'July','August','September','October','November','December'];
const DAY_NAMES = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];

// Simplified moon phase (0=new, 4=full, 7=waning crescent cycle 0-7)
function moonPhase(year, month, day) {
  const known = new Date(2000, 0, 6); // known new moon
  const diff = (new Date(year, month, day) - known) / 86400000;
  const cycle = ((diff % 29.53) + 29.53) % 29.53;
  if (cycle < 1.85) return '🌑';
  if (cycle < 5.53) return '🌒';
  if (cycle < 9.22) return '🌓';
  if (cycle < 12.91) return '🌔';
  if (cycle < 16.61) return '🌕';
  if (cycle < 20.30) return '🌖';
  if (cycle < 23.99) return '🌗';
  if (cycle < 27.68) return '🌘';
  return '🌑';
}

export default function Calendar() {
  const nav = useNavigate();
  const [entries, setEntries] = useState([]);
  const [today] = useState(new Date());
  const [year, setYear] = useState(today.getFullYear());
  const [month, setMonth] = useState(today.getMonth());
  const [selected, setSelected] = useState(null); // { date: Date, entries: [] }

  const load = useCallback(async () => {
    try {
      const data = await api.listEntries();
      setEntries(data);
    } catch (e) {
      console.error(e);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  const entryMap = {};
  entries.forEach(e => {
    const d = new Date(e.created_at);
    const key = `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
    if (!entryMap[key]) entryMap[key] = [];
    entryMap[key].push(e);
  });

  const firstDay = new Date(year, month, 1).getDay();
  const daysInMonth = new Date(year, month + 1, 0).getDate();

  const prevMonth = () => { if (month === 0) { setMonth(11); setYear(y => y - 1); } else setMonth(m => m - 1); };
  const nextMonth = () => { if (month === 11) { setMonth(0); setYear(y => y + 1); } else setMonth(m => m + 1); };

  const cells = [];
  for (let i = 0; i < firstDay; i++) cells.push(null);
  for (let d = 1; d <= daysInMonth; d++) cells.push(d);

  const handleDay = (day) => {
    if (!day) return;
    const key = `${year}-${month}-${day}`;
    const dayEntries = entryMap[key] || [];
    setSelected({ date: new Date(year, month, day), entries: dayEntries });
  };

  return (
    <div className="cal-page">
      <header className="app-header">
        <Link to="/timeline" className="btn ghost icon-btn">←</Link>
        <span className="header-spacer" />
        <span className="brand cinzel">📅 Calendar</span>
        <span className="header-spacer" />
      </header>

      <div className="cal-body">
        <div className="cal-panel">
          <div className="cal-nav">
            <button className="btn ghost icon-btn" onClick={prevMonth}>‹</button>
            <h2 className="cal-month cinzel">{MONTH_NAMES[month]} {year}</h2>
            <button className="btn ghost icon-btn" onClick={nextMonth}>›</button>
          </div>

          <div className="cal-grid">
            {DAY_NAMES.map(d => (
              <div key={d} className="cal-day-name">{d}</div>
            ))}
            {cells.map((day, i) => {
              if (!day) return <div key={`e-${i}`} className="cal-cell empty" />;
              const key = `${year}-${month}-${day}`;
              const dayEntries = entryMap[key] || [];
              const isToday = year === today.getFullYear() && month === today.getMonth() && day === today.getDate();
              const isSel = selected?.date?.getDate() === day && selected?.date?.getMonth() === month && selected?.date?.getFullYear() === year;
              const moon = moonPhase(year, month, day);

              return (
                <button
                  key={day}
                  className={`cal-cell ${isToday ? 'today' : ''} ${isSel ? 'sel' : ''} ${dayEntries.length ? 'has-entries' : ''}`}
                  onClick={() => handleDay(day)}
                >
                  <span className="cal-day-num">{day}</span>
                  <span className="cal-moon" title={moon}>{moon}</span>
                  {dayEntries.length > 0 && (
                    <div className="cal-dots">
                      {dayEntries.slice(0, 3).map(e => (
                        <span
                          key={e.id}
                          className="cal-dot"
                          style={{ background: e.mood ? (moodColor(e.mood) || 'var(--accent)') : 'var(--accent)' }}
                        />
                      ))}
                    </div>
                  )}
                </button>
              );
            })}
          </div>
        </div>

        {/* Day entries panel */}
        {selected && (
          <div className="cal-entries">
            <div className="cal-entries-header">
              <h3 className="cal-entries-date cinzel">
                {selected.date.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })}
              </h3>
              <button className="btn icon-btn" onClick={() => setSelected(null)}>✕</button>
            </div>
            {selected.entries.length === 0 ? (
              <div className="cal-no-entries">
                <p className="muted">No entries</p>
                <button className="btn" onClick={() => nav('/entry/new')}>✦ New entry</button>
              </div>
            ) : (
              <div className="cal-entries-list">
                {selected.entries.map(e => (
                  <button key={e.id} className="cal-entry-btn" onClick={() => nav(`/entry/${e.id}`)}>
                    <div className="cal-entry-row">
                      {e.mood && <span className="cal-entry-mood">{e.mood}</span>}
                      <span className="cal-entry-title">{e.title || '(untitled)'}</span>
                    </div>
                    {e.tags && <div className="cal-entry-tags">{e.tags.split(',').map(t => t.trim()).filter(Boolean).map(t => <span key={t} className="tag">{t}</span>)}</div>}
                  </button>
                ))}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
