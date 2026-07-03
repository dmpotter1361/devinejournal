// Debbie's own 78-card tarot deck — her paintings and her meanings, bundled
// with the app under /deck/ (built by tools/build-deck.mjs from TarotTraining).
// Fetched once at runtime so the big meaning text stays out of the JS bundle.

export const CARD_BACK = '/deck/card-back.jpg';

let deckPromise = null;
export function loadDeck() {
  if (!deckPromise) {
    deckPromise = fetch('/deck/deck.json').then(r => {
      if (!r.ok) throw new Error('deck unavailable');
      return r.json();
    });
  }
  return deckPromise;
}

export const findCard = (deck, name) => deck.cards.find(c => c.name === name);

// Draw n distinct cards — a real shuffle-and-deal, no repeats in a spread.
export function drawCards(deck, n) {
  const pool = [...deck.cards];
  const out = [];
  for (let i = 0; i < n && pool.length; i++) {
    out.push(pool.splice(Math.floor(Math.random() * pool.length), 1)[0]);
  }
  return out;
}
