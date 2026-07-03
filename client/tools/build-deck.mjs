// One-time deck builder: reads Debbie's TarotTraining app (her art + meanings)
// and produces the journal's bundled deck — optimized JPEGs + deck.json —
// in client/public/deck/ (which Vite copies into the served static dir).
//
// Run from client/:  node tools/build-deck.mjs
import { readFileSync, writeFileSync, mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import sharp from 'sharp';

const here = dirname(fileURLToPath(import.meta.url));
const SRC = 'C:/Users/micha/Projects/TarotTraining';
const OUT = join(here, '..', 'public', 'deck');
const WIDTH = 640;   // plenty for a 240px panel and a reading layout
const QUALITY = 80;

mkdirSync(OUT, { recursive: true });

const slug = (name) => name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');

const src = JSON.parse(readFileSync(join(SRC, 'cards.json'), 'utf8'));
if (src.cards.length !== 78) throw new Error(`Expected 78 cards, got ${src.cards.length}`);

let total = 0;
async function optimize(inFile, outName) {
  const buf = await sharp(join(SRC, 'Resources', inFile))
    .resize({ width: WIDTH, withoutEnlargement: true })
    .jpeg({ quality: QUALITY, mozjpeg: true })
    .toBuffer();
  writeFileSync(join(OUT, outName), buf);
  total += buf.length;
  return buf.length;
}

// Card back
await optimize('Marble.png', 'card-back.jpg');

// All 78 cards
const cards = [];
for (const c of src.cards) {
  const out = `${slug(c.name)}.jpg`;
  const size = await optimize(`${c.name}.png`, out);
  cards.push({ ...c, image: `/deck/${out}` });
  process.stdout.write(`${c.name.padEnd(24)} ${(size / 1024).toFixed(0).padStart(4)} KB\n`);
}

writeFileSync(
  join(OUT, 'deck.json'),
  JSON.stringify({ suits: src.suits, cards }, null, 0)
);

console.log(`\n${cards.length} cards + back → ${(total / 1024 / 1024).toFixed(1)} MB total`);
