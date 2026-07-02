import { useCallback, useEffect, useRef, useState } from 'react';
import { clearAuth, getToken } from '../api';
import { clearPin, getLockTimeout, hasPin, verifyPin } from '../lib/pin';
import './PinLock.css';

// Reusable 4-digit pad: dots + keypad, auto-submits on the 4th digit.
// Shared by the lock screen and the Security settings flows.
export function PinPad({ onComplete, shake, active = true }) {
  const [digits, setDigits] = useState('');

  useEffect(() => {
    if (digits.length === 4) {
      const d = digits;
      const t = setTimeout(() => { setDigits(''); onComplete(d); }, 140);
      return () => clearTimeout(t);
    }
  }, [digits, onComplete]);

  const push = useCallback((n) => setDigits(d => (d.length < 4 ? d + n : d)), []);
  const pop = useCallback(() => setDigits(d => d.slice(0, -1)), []);

  useEffect(() => {
    if (!active) return undefined;
    const h = (e) => {
      if (/^[0-9]$/.test(e.key)) push(e.key);
      else if (e.key === 'Backspace') pop();
    };
    window.addEventListener('keydown', h);
    return () => window.removeEventListener('keydown', h);
  }, [active, push, pop]);

  return (
    <div className="pp-wrap">
      <div className={`pp-dots ${shake ? 'pp-shake' : ''}`}>
        {[0, 1, 2, 3].map(i => (
          <span key={i} className={`pp-dot ${i < digits.length ? 'pp-filled' : ''}`} />
        ))}
      </div>
      <div className="pp-pad">
        {[1, 2, 3, 4, 5, 6, 7, 8, 9].map(n => (
          <button key={n} type="button" className="pp-key" onClick={() => push(String(n))}>{n}</button>
        ))}
        <button type="button" className="pp-key pp-key-ghost" onClick={pop}>⌫</button>
        <button type="button" className="pp-key" onClick={() => push('0')}>0</button>
        <span className="pp-key-empty" />
      </div>
    </div>
  );
}

// App-level lock: covers everything when locked. Locks on page load (if a
// PIN is set), after the idle timeout, and on the dj:lock event.
export default function PinLock() {
  const [locked, setLocked] = useState(() => !!getToken() && hasPin());
  const [shake, setShake] = useState(false);
  const timerRef = useRef(null);

  const resetIdle = useCallback(() => {
    clearTimeout(timerRef.current);
    const secs = getLockTimeout();
    if (!secs || !hasPin() || !getToken()) return;
    timerRef.current = setTimeout(() => setLocked(true), secs * 1000);
  }, []);

  useEffect(() => {
    const onActivity = () => resetIdle();
    const onLock = () => { if (hasPin() && getToken()) setLocked(true); };
    window.addEventListener('pointerdown', onActivity);
    window.addEventListener('keydown', onActivity);
    window.addEventListener('dj:lock', onLock);
    resetIdle();
    return () => {
      window.removeEventListener('pointerdown', onActivity);
      window.removeEventListener('keydown', onActivity);
      window.removeEventListener('dj:lock', onLock);
      clearTimeout(timerRef.current);
    };
  }, [resetIdle]);

  const tryPin = useCallback(async (pin) => {
    if (await verifyPin(pin)) {
      setLocked(false);
      resetIdle();
    } else {
      setShake(true);
      setTimeout(() => setShake(false), 650);
    }
  }, [resetIdle]);

  const signOut = () => {
    clearPin();
    clearAuth();
    window.location.href = '/';
  };

  if (!locked) return null;

  return (
    <div className="pl-overlay">
      <div className="pl-brand cinzel">🌙 DevineJournal</div>
      <p className="pl-sub">Your journal is locked.</p>
      <PinPad onComplete={tryPin} shake={shake} />
      <button className="pl-forgot" onClick={signOut}>Forgot your PIN? Sign out</button>
    </div>
  );
}
