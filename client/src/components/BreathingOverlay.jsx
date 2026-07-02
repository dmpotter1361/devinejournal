import { useEffect, useState } from 'react';
import './BreathingOverlay.css';

// Box breathing (4-4-4-4): a calm grounding pause. The circle expands on the
// inhale, holds, contracts on the exhale, and rests — the light leads.
const PHASES = [
  { key: 'in',   label: 'Breathe in…',  secs: 4, scale: 1 },
  { key: 'hold', label: 'Hold…',        secs: 4, scale: 1 },
  { key: 'out',  label: 'Breathe out…', secs: 4, scale: 0.42 },
  { key: 'rest', label: 'Rest…',        secs: 4, scale: 0.42 },
];

export default function BreathingOverlay({ onClose }) {
  const [i, setI] = useState(0);
  const [breaths, setBreaths] = useState(0);

  useEffect(() => {
    const t = setTimeout(() => {
      setI(prev => {
        const next = (prev + 1) % PHASES.length;
        if (next === 0) setBreaths(b => b + 1);
        return next;
      });
    }, PHASES[i].secs * 1000);
    return () => clearTimeout(t);
  }, [i]);

  useEffect(() => {
    const onKey = (e) => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  const phase = PHASES[i];
  return (
    <div className="br-overlay" onClick={onClose}>
      <div className="br-inner" onClick={e => e.stopPropagation()}>
        <div
          className="br-circle"
          style={{ transform: `scale(${phase.scale})`, transitionDuration: `${phase.secs}s` }}
        />
        <p className="br-label cinzel">{phase.label}</p>
        <p className="br-count">
          {breaths > 0 ? `${breaths} breath${breaths === 1 ? '' : 's'} taken` : 'Follow the light'}
        </p>
        <button className="br-done" onClick={onClose}>I'm ready ✦</button>
      </div>
    </div>
  );
}
