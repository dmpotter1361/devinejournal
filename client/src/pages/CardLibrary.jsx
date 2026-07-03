import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { loadDeck } from '../lib/deck';
import { prettify } from '../lib/prettify';
import './CardLibrary.css';

// A reference library for her deck — for study, not show. Look a card up,
// read the fuller meaning she wrote beyond the base line.
const SUIT_ORDER = ['Major Arcana', 'Cups', 'Pentacles', 'Swords', 'Wands'];

export default function CardLibrary() {
  const [deck, setDeck] = useState(null);
  const [suit, setSuit] = useState('Major Arcana');
  const [openCard, setOpenCard] = useState(null);
  const [aboutOpen, setAboutOpen] = useState(false);

  useEffect(() => { loadDeck().then(setDeck).catch(() => {}); }, []);

  const cards = deck ? deck.cards.filter(c => c.suit === suit) : [];

  return (
    <div className="cl-page">
      <header className="app-header">
        <Link to="/timeline" className="back-btn" title="Back to your journal">⟵</Link>
        <span className="header-spacer" />
        <span className="brand cinzel cl-brand">📖 Card Library</span>
        <span className="header-spacer" />
      </header>

      <div className="cl-body">
        {!deck ? (
          <div className="cl-state">Opening the library…</div>
        ) : (
          <>
            <div className="cl-suits">
              {SUIT_ORDER.map(s => (
                <button
                  key={s}
                  className={`cl-suit ${suit === s ? 'cl-suit-on' : ''}`}
                  onClick={() => { setSuit(s); setAboutOpen(false); setOpenCard(null); }}
                >{s}</button>
              ))}
            </div>

            {deck.suits[suit] && (
              <div className="cl-about card">
                <button className="cl-about-toggle" onClick={() => setAboutOpen(o => !o)}>
                  About the {suit} {aboutOpen ? '▴' : '▾'}
                </button>
                {aboutOpen && (
                  // eslint-disable-next-line react/no-danger
                  <div className="cl-prose" dangerouslySetInnerHTML={{ __html: prettify(deck.suits[suit]) }} />
                )}
              </div>
            )}

            <div className="cl-grid">
              {cards.map(c => (
                <button key={c.name} className="cl-card" onClick={() => setOpenCard(c)}>
                  <img className="cl-thumb" src={c.image} alt={c.name} loading="lazy" />
                  <span className="cl-card-name">{c.name}</span>
                </button>
              ))}
            </div>

            <p className="cl-credit">Art © Debbie · Devine Tarot</p>
          </>
        )}
      </div>

      {openCard && (
        <div className="ne-overlay" onClick={() => setOpenCard(null)}>
          <div className="cl-detail" onClick={e => e.stopPropagation()}>
            <button className="btn icon-btn cl-detail-close" onClick={() => setOpenCard(null)}>✕</button>
            <div className="cl-detail-cols">
              <img className="cl-detail-art" src={openCard.image} alt={openCard.name} />
              <div className="cl-detail-text">
                <h3 className="cl-detail-name cinzel">{openCard.name}</h3>
                <div className="cl-detail-kws">
                  {openCard.keywords.split(',').map(k => <span key={k} className="cod-kw">{k.trim()}</span>)}
                </div>
                <p className="cl-detail-brief">{openCard.brief}</p>
                {/* eslint-disable-next-line react/no-danger */}
                <div className="cl-prose" dangerouslySetInnerHTML={{ __html: prettify(openCard.description) }} />
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
