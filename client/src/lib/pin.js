// Device-level PIN lock — 4-digit PIN, SHA-256 hashed in localStorage.
// This protects against someone picking up an open journal, not against
// a determined attacker (the data lives behind Google sign-in regardless).

const HASH_KEY = 'dj_pin_hash';
const TIMEOUT_KEY = 'dj_lock_timeout';

export const hasPin = () => !!localStorage.getItem(HASH_KEY);

async function sha256(s) {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s));
  return [...new Uint8Array(buf)].map(b => b.toString(16).padStart(2, '0')).join('');
}

export async function setPin(pin) {
  localStorage.setItem(HASH_KEY, await sha256(pin));
}

export async function verifyPin(pin) {
  return (await sha256(pin)) === localStorage.getItem(HASH_KEY);
}

export function clearPin() {
  localStorage.removeItem(HASH_KEY);
}

// Seconds of inactivity before auto-lock. 0 = never. Default 5 minutes.
export const getLockTimeout = () => parseInt(localStorage.getItem(TIMEOUT_KEY) || '300', 10);
export const setLockTimeout = (secs) => localStorage.setItem(TIMEOUT_KEY, String(secs));

// Manual lock from anywhere (avatar menu) — PinLock listens for this.
export const requestLock = () => window.dispatchEvent(new CustomEvent('dj:lock'));
