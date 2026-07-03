import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { api } from '../api';
import { loadDeck, drawCards, CARD_BACK } from '../lib/deck';
import './Reading.css';

// Her three spreads, labeled the way she actually reads.
const SPREADS = [
  { id: 'ppf', name: 'Past · Present · Future', positions: ['Past', 'Present', 'Future'],
    desc: 'Where you have been, where you stand, and where this is heading' },
  { id: 'sco', name: 'Situation · Challenge · Outcome', positions: ['Situation', 'Challenge', 'Outcome'],
    desc: 'What is, what stands in the way, and where it leads' },
  { id: 'mbs', name: 'Mind · Body · Spirit', positions: ['Mind', 'Body', 'Spirit'],
    desc: 'A gentle check-in across your three centers' },
];

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

function readingHtml(spread, question, cards) {
  const parts = [`<p><strong>🔮 Tarot Reading — ${spread.name}</strong></p>`];
  if (question.trim()) parts.push(`<p><em>The question: ${esc(question.trim())}</em></p>`);
  cards.forEach((card, i) => {
    parts.push(
      `<figure class="ds-figure ds-align-center" data-align="center"><img src="${card.image}" width="230"><figcaption>${spread.positions[i]} — ${esc(card.name)}</figcaption></figure>`,
      `<p><strong>${spread.positions[i]} — ${esc(card.name)}:</strong> ${esc(card.brief)}</p>`
    );
  });
  parts.push('<p><strong>My reading:</strong></p><p></p>');
  return parts.join('');
}

export default function Reading() {
  const nav = useNavigate();
  const [deck, setDeck] = useState(null);
  const [spread, setSpread] = useState(null);
  const [question, setQuestion] = useState('');
  const [cards, setCards] = useState([]);
  const [flipped, setFlipped] = useState([]);
  const [saving, setSaving] = useState(false);

  useEffect(() => { loadDeck().then(setDeck).catch(() => {}); }, []);

  const chooseSpread = (s) => {
    setSpread(s);
    setCards(drawCards(deck, s.positions.length)); // dealt now, revealed on tap
    setFlipped(s.positions.map(() => false));
  };

  const flip = (i) => setFlipped(f => f.map((v, idx) => (idx === i ? true : v)));
  const allFlipped = flipped.length > 0 && flipped.every(Boolean);

  const save = async () => {
    setSaving(true);
    try {
      const dateStr = new Date().toLocaleDateString('en-US', { month: 'long', day: 'numeric' });
      const created = await api.createEntry({
        title: `Tarot Reading — ${dateStr}`,
        body: readingHtml(spread, question, cards),
        mood: '🔮',
        tags: 'tarot,reading',
        paper_style: 'plain',
        is_favorite: false,
        locked_until: null,
        theme_id: null,
      });
      nav(`/entry/${created.id}`, { replace: true });
    } catch (e) {
      alert('Could not save the reading: ' + e.message);
      setSaving(false);
    }
  };

  return (
    <div className="rd-page">
      <header className="app-header">
        <Link to="/timeline" className="back-btn" title="Back to your journal">⟵</Link>
        <span className="header-spacer" />
        <span className="brand cinzel rd-brand">🔮 Tarot Reading</span>
        <span className="header-spacer" />
      </header>

      <div className="rd-body">
        {!deck ? (
          <div className="rd-state">Shuffling the deck…</div>
        ) : !spread ? (
          <>
            <p className="rd-intro">Hold your question in mind, then choose a spread.</p>
            <div className="rd-spreads">
              {SPREADS.map(s => (
                <button key={s.id} className="rd-spread card" onClick={() => chooseSpread(s)}>
                  <span className="rd-spread-name cinzel">{s.name}</span>
                  <span className="rd-spread-desc">{s.desc}</span>
                </button>
              ))}
            </div>
          </>
        ) : (
          <>
            <input
              className="rd-question"
              placeholder="What did you ask? (optional)"
              value={question}
              maxLength={200}
              onChange={e => setQuestion(e.target.value)}
            />

            <p className="rd-hint">
              {allFlipped ? 'Your cards are revealed ✦' : 'Tap each card to turn it over'}
            </p>

            <div className="rd-slots">
              {spread.positions.map((pos, i) => (
                <div key={pos} className="rd-slot-wrap">
                  <span className="rd-pos cinzel">{pos}</span>
                  {flipped[i] ? (
                    <div className="rd-card rd-revealed">
                      <img className="rd-art" src={cards[i].image} alt={cards[i].name} />
                      <span className="rd-card-name">{cards[i].name}</span>
                      <p className="rd-brief">{cards[i].brief}</p>
                    </div>
                  ) : (
                    <button className="rd-card rd-facedown" onClick={() => flip(i)}>
                      <img className="rd-art" src={CARD_BACK} alt="face-down card" />
                    </button>
                  )}
                </div>
              ))}
            </div>

            <div className="rd-actions">
              <button className="btn ghost" onClick={() => { setSpread(null); setQuestion(''); }}>
                Start over
              </button>
              <button className="btn" onClick={save} disabled={!allFlipped || saving}>
                {saving ? 'Saving…' : '✦ Save to journal'}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
