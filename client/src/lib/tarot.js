// Card of the Day — the 22 Major Arcana with short, gentle readings.
export const MAJOR_ARCANA = [
  { name: 'The Fool',           symbol: '🌈', reading: 'A fresh path opens. Step forward with a light heart — not knowing is part of the magic.' },
  { name: 'The Magician',       symbol: '✨', reading: 'Everything you need is already in your hands. Focus your will and begin.' },
  { name: 'The High Priestess', symbol: '🌙', reading: 'The answer is not out there — it is beneath the surface. Be still and listen inward.' },
  { name: 'The Empress',        symbol: '🌹', reading: 'Tend what you love and it will flourish. Today favors nurture, comfort, and creation.' },
  { name: 'The Emperor',        symbol: '🏔️', reading: 'Structure is a kindness you give your future self. Build the frame; let life fill it.' },
  { name: 'The Hierophant',     symbol: '🗝️', reading: 'Old wisdom has something for you today. Honor tradition — then make it your own.' },
  { name: 'The Lovers',         symbol: '💞', reading: 'A choice of the heart is near. Choose what aligns with who you are becoming.' },
  { name: 'The Chariot',        symbol: '🌠', reading: 'Momentum is with you. Hold the reins gently but do not stop moving.' },
  { name: 'Strength',           symbol: '🦁', reading: 'True strength is soft-handed. Meet what is wild in you with patience, not force.' },
  { name: 'The Hermit',         symbol: '🏮', reading: 'Withdraw a little and carry your own lantern. Solitude will show you the way.' },
  { name: 'Wheel of Fortune',   symbol: '🎡', reading: 'The wheel turns whether we push or not. Ride the change — it is turning in your favor.' },
  { name: 'Justice',            symbol: '⚖️', reading: 'Truth wants daylight today. Weigh honestly, speak clearly, and balance will follow.' },
  { name: 'The Hanged One',     symbol: '🦇', reading: 'Pause. Seen from another angle, the problem may be the answer.' },
  { name: 'Death',              symbol: '🦋', reading: 'Something is ready to be released. Endings are how the garden makes room for spring.' },
  { name: 'Temperance',         symbol: '🕊️', reading: 'Blend, do not battle. The middle path carries healing today.' },
  { name: 'The Devil',          symbol: '⛓️', reading: 'Notice what binds you — most chains are looser than they look. You hold the key.' },
  { name: 'The Tower',          symbol: '⚡', reading: 'What crumbles was never load-bearing for your soul. Clear ground is a gift.' },
  { name: 'The Star',           symbol: '⭐', reading: 'Hope is not naive — it is navigation. Pour yourself out and be replenished.' },
  { name: 'The Moon',           symbol: '🌕', reading: 'Not everything must be understood tonight. Trust your intuition through the mist.' },
  { name: 'The Sun',            symbol: '☀️', reading: 'Joy is allowed to be simple today. Stand in the warmth and take it in.' },
  { name: 'Judgement',          symbol: '🎺', reading: 'Something in you is being called to rise. Answer it — you are ready.' },
  { name: 'The World',          symbol: '🌍', reading: 'A circle completes. Celebrate how far you have come before the next dance begins.' },
];

// Same card all day, everywhere — date-seeded like the daily affirmation.
export function cardOfTheDay(d = new Date()) {
  const seed = d.getFullYear() * 372 + d.getMonth() * 31 + d.getDate();
  return MAJOR_ARCANA[seed % MAJOR_ARCANA.length];
}
