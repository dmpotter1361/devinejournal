// Time-capsule seal logic. locked_until is stored as a date string
// ("YYYY-MM-DD"); it must be treated as a LOCAL calendar date — parsing it
// with new Date() reads it as UTC midnight, which shifts the open moment
// (and even the displayed day) in western timezones.
export function opensOn(lockedUntil) {
  const [y, m, d] = lockedUntil.split('T')[0].split('-').map(Number);
  return new Date(y, m - 1, d); // local midnight of the open date
}

export const isSealed = (e) => !!e.locked_until && opensOn(e.locked_until) > new Date();
