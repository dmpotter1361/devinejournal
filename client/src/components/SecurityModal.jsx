import { useCallback, useState } from 'react';
import { clearPin, getLockTimeout, hasPin, setLockTimeout, setPin, verifyPin } from '../lib/pin';
import { PinPad } from './PinLock';

const TIMEOUTS = [
  { secs: 0,    label: 'Never' },
  { secs: 60,   label: 'After 1 minute' },
  { secs: 300,  label: 'After 5 minutes' },
  { secs: 900,  label: 'After 15 minutes' },
  { secs: 1800, label: 'After 30 minutes' },
];

const STEP_LABELS = {
  'set-new':        'Choose a 4-digit passcode',
  'set-confirm':    'Enter it once more to confirm',
  'change-current': 'Enter your current passcode',
  'change-new':     'Choose a new 4-digit passcode',
  'change-confirm': 'Enter it once more to confirm',
  'remove-current': 'Enter your passcode to remove it',
};

export default function SecurityModal({ onClose }) {
  const [step, setStep] = useState('menu');
  const [tempPin, setTempPin] = useState('');
  const [shake, setShake] = useState(false);
  const [pinSet, setPinSet] = useState(hasPin());
  const [timeout_, setTimeout_] = useState(getLockTimeout());
  const [notice, setNotice] = useState('');

  const buzz = () => { setShake(true); setTimeout(() => setShake(false), 650); };

  const onPin = useCallback(async (pin) => {
    switch (step) {
      case 'set-new':
        setTempPin(pin); setStep('set-confirm'); break;
      case 'set-confirm':
        if (pin === tempPin) {
          await setPin(pin); setPinSet(true); setNotice('Passcode set ✦'); setStep('menu');
        } else { buzz(); setStep('set-new'); }
        break;
      case 'change-current':
        if (await verifyPin(pin)) setStep('change-new'); else buzz();
        break;
      case 'change-new':
        setTempPin(pin); setStep('change-confirm'); break;
      case 'change-confirm':
        if (pin === tempPin) {
          await setPin(pin); setNotice('Passcode changed ✦'); setStep('menu');
        } else { buzz(); setStep('change-new'); }
        break;
      case 'remove-current':
        if (await verifyPin(pin)) {
          clearPin(); setPinSet(false); setNotice('Passcode removed'); setStep('menu');
        } else buzz();
        break;
      default: break;
    }
  }, [step, tempPin]);

  return (
    <div className="ne-overlay" onClick={onClose}>
      <div className="sec-dialog" onClick={e => e.stopPropagation()}>
        <div className="sec-head">
          <h3 className="sec-title cinzel">🛡️ Security</h3>
          <button className="btn icon-btn" onClick={onClose}>✕</button>
        </div>

        {step === 'menu' ? (
          <div className="sec-menu">
            {notice && <p className="sec-notice">{notice}</p>}
            {!pinSet ? (
              <>
                <p className="sec-blurb">Protect your journal with a 4-digit passcode. It locks when you step away.</p>
                <button className="btn sec-action" onClick={() => { setNotice(''); setStep('set-new'); }}>
                  ✦ Set a passcode
                </button>
              </>
            ) : (
              <>
                <button className="btn ghost sec-action" onClick={() => { setNotice(''); setStep('change-current'); }}>
                  Change passcode
                </button>
                <button className="btn ghost sec-action" onClick={() => { setNotice(''); setStep('remove-current'); }}>
                  Remove passcode
                </button>
                <label className="sec-timeout">
                  <span>Auto-lock</span>
                  <select
                    value={timeout_}
                    onChange={e => { const s = Number(e.target.value); setTimeout_(s); setLockTimeout(s); }}
                  >
                    {TIMEOUTS.map(t => <option key={t.secs} value={t.secs}>{t.label}</option>)}
                  </select>
                </label>
                <p className="sec-note muted">The journal also locks each time it's opened.</p>
              </>
            )}
          </div>
        ) : (
          <div className="sec-pinstep">
            <p className="sec-step-label">{STEP_LABELS[step]}</p>
            <PinPad key={step} onComplete={onPin} shake={shake} />
            <button className="sec-cancel" onClick={() => setStep('menu')}>Cancel</button>
          </div>
        )}
      </div>
    </div>
  );
}
