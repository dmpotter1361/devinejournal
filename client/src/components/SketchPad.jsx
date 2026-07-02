import { useCallback, useEffect, useRef, useState } from 'react';
import './SketchPad.css';

// Handwriting / sketch pad — draw with a stylus (pressure-aware), finger, or
// mouse; the result is inserted into the entry as an image.

const W = 1000;
const H = 640;
const PAPER = '#fdfbf5';

const INKS = [
  { id: 'ink',    color: '#2a2018', name: 'Ink' },
  { id: 'plum',   color: '#6b3fa0', name: 'Plum' },
  { id: 'rose',   color: '#c2416b', name: 'Rose' },
  { id: 'ocean',  color: '#2c6b9a', name: 'Ocean' },
  { id: 'forest', color: '#2e7d4f', name: 'Forest' },
  { id: 'gold',   color: '#b8860b', name: 'Gold' },
];
const SIZES = [
  { id: 'fine',   px: 2.2, label: '·' },
  { id: 'medium', px: 4,   label: '•' },
  { id: 'bold',   px: 7,   label: '⬤' },
];

export default function SketchPad({ onDone, onClose }) {
  const canvasRef = useRef(null);
  const ctxRef = useRef(null);
  const strokesRef = useRef([]);   // finished strokes (for undo/redraw)
  const liveRef = useRef(null);    // stroke currently being drawn
  const [ink, setInk] = useState(INKS[0]);
  const [size, setSize] = useState(SIZES[1]);
  const [eraser, setEraser] = useState(false);
  const [penOnly, setPenOnly] = useState(false);
  const [paper, setPaper] = useState('plain'); // 'plain' | 'lined'
  const paperRef = useRef('plain');
  const [, setBump] = useState(0); // re-render for undo button state

  // Lines are part of the paper — they bake into the exported image
  const paintBackground = (ctx) => {
    ctx.fillStyle = PAPER;
    ctx.fillRect(0, 0, W, H);
    if (paperRef.current === 'lined') {
      ctx.strokeStyle = 'rgba(60, 100, 140, 0.22)';
      ctx.lineWidth = 1;
      for (let y = 72; y < H - 12; y += 46) {
        ctx.beginPath();
        ctx.moveTo(26, y);
        ctx.lineTo(W - 26, y);
        ctx.stroke();
      }
    }
  };

  useEffect(() => {
    const canvas = canvasRef.current;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = W * dpr;
    canvas.height = H * dpr;
    const ctx = canvas.getContext('2d');
    ctx.scale(dpr, dpr);
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctxRef.current = ctx;
    paintBackground(ctx);
  }, []);

  const strokeWidth = (stroke, p) =>
    stroke.eraser ? stroke.size * 6 : stroke.size * (stroke.pen ? 0.5 + p * 1.4 : 1);

  const drawSegment = (ctx, stroke, a, b) => {
    ctx.strokeStyle = stroke.eraser ? PAPER : stroke.color;
    ctx.lineWidth = strokeWidth(stroke, (a.p + b.p) / 2);
    ctx.beginPath();
    ctx.moveTo(a.x, a.y);
    // midpoint smoothing keeps handwriting from looking jagged
    ctx.quadraticCurveTo(a.x, a.y, (a.x + b.x) / 2, (a.y + b.y) / 2);
    ctx.lineTo(b.x, b.y);
    ctx.stroke();
  };

  const redraw = useCallback(() => {
    const ctx = ctxRef.current;
    paintBackground(ctx);
    for (const s of strokesRef.current) {
      for (let i = 1; i < s.points.length; i++) drawSegment(ctx, s, s.points[i - 1], s.points[i]);
      if (s.points.length === 1) { // a dot
        const pt = s.points[0];
        ctx.fillStyle = s.eraser ? PAPER : s.color;
        ctx.beginPath();
        ctx.arc(pt.x, pt.y, strokeWidth(s, pt.p) / 2, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  }, []);

  const toPoint = (e) => {
    const rect = canvasRef.current.getBoundingClientRect();
    return {
      x: ((e.clientX - rect.left) / rect.width) * W,
      y: ((e.clientY - rect.top) / rect.height) * H,
      p: e.pressure && e.pressure > 0 ? e.pressure : 0.5,
    };
  };

  const accepts = (e) => !(penOnly && e.pointerType === 'touch');

  const onPointerDown = (e) => {
    if (!accepts(e)) return;
    e.preventDefault();
    canvasRef.current.setPointerCapture(e.pointerId);
    liveRef.current = {
      color: ink.color,
      size: size.px,
      eraser,
      pen: e.pointerType === 'pen',
      points: [toPoint(e)],
    };
  };

  const onPointerMove = (e) => {
    const s = liveRef.current;
    if (!s || !accepts(e)) return;
    e.preventDefault();
    const pt = toPoint(e);
    const prev = s.points[s.points.length - 1];
    s.points.push(pt);
    drawSegment(ctxRef.current, s, prev, pt);
  };

  const onPointerUp = () => {
    if (!liveRef.current) return;
    strokesRef.current.push(liveRef.current);
    liveRef.current = null;
    redraw(); // normalizes single-point dots
    setBump(n => n + 1);
  };

  const undo = () => { strokesRef.current.pop(); redraw(); setBump(n => n + 1); };
  const clearAll = () => { strokesRef.current = []; redraw(); setBump(n => n + 1); };
  const setPaperMode = (p) => { paperRef.current = p; setPaper(p); redraw(); };

  const finish = () => {
    if (strokesRef.current.length === 0) { onClose(); return; }
    onDone(canvasRef.current.toDataURL('image/png'));
  };

  return (
    <div className="sk-overlay">
      <div className="sk-frame">
        <div className="sk-toolbar">
          <span className="sk-title cinzel">✍️ Handwrite</span>
          <div className="sk-inks">
            {INKS.map(i => (
              <button
                key={i.id}
                className={`sk-ink ${!eraser && ink.id === i.id ? 'sk-on' : ''}`}
                style={{ background: i.color }}
                title={i.name}
                onClick={() => { setInk(i); setEraser(false); }}
              />
            ))}
          </div>
          <div className="sk-sizes">
            {SIZES.map(s => (
              <button
                key={s.id}
                className={`sk-size ${size.id === s.id ? 'sk-on' : ''}`}
                title={s.id}
                onClick={() => setSize(s)}
              >{s.label}</button>
            ))}
          </div>
          <div className="sk-sizes">
            <button className={`sk-size ${paper === 'plain' ? 'sk-on' : ''}`} title="Plain paper" onClick={() => setPaperMode('plain')}>▭</button>
            <button className={`sk-size ${paper === 'lined' ? 'sk-on' : ''}`} title="Lined paper" onClick={() => setPaperMode('lined')}>≡</button>
          </div>
          <button className={`sk-tool ${eraser ? 'sk-on' : ''}`} title="Eraser" onClick={() => setEraser(e => !e)}>🧽</button>
          <button className="sk-tool" title="Undo last stroke" onClick={undo} disabled={strokesRef.current.length === 0}>↩</button>
          <button className="sk-tool" title="Clear the page" onClick={clearAll} disabled={strokesRef.current.length === 0}>🗑️</button>
          <label className="sk-penonly" title="Ignore finger touches — rest your palm freely (needs an active pen)">
            <input type="checkbox" checked={penOnly} onChange={e => setPenOnly(e.target.checked)} />
            Pen only
          </label>
        </div>

        <canvas
          ref={canvasRef}
          className="sk-canvas"
          onPointerDown={onPointerDown}
          onPointerMove={onPointerMove}
          onPointerUp={onPointerUp}
          onPointerCancel={onPointerUp}
        />

        <div className="sk-actions">
          <button className="btn ghost" onClick={onClose}>Cancel</button>
          <button className="btn" onClick={finish}>✦ Add to entry</button>
        </div>
      </div>
    </div>
  );
}
