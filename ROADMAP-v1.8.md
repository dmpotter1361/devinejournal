# DevineJournal — Roadmap (planned, not yet built)

Captured 2026-07-01 at end of session. App is LIVE at journal.devinetarot.net, currently **v1.7.0**.
This is a PLAN only — nothing here is implemented yet. User will say "run with it" per group.
Accessibility rule stands: large fonts (editor body 24px / line-height 1.9, UI labels ≥14px), Debbie has visual difficulties.

---

## GROUP A — User's bugs & concerns (highest priority)

### A1. Unsaved-changes awareness (editor)
Problem: not obvious when a save is needed.
- **Dirty tracking**: snapshot fields (title, body, mood, tags, paper, journal theme, lock date, favorite) at load/after-save; diff → `dirty` flag.
- **Save button states**: clean = quiet "Saved ✓" (dimmed); dirty = bright accent + soft pulsing glow (must be obvious at Debbie's vision, not a subtle hue shift). Settle back after save with brief ✓ confirmation.
- **Leave-with-unsaved guard**:
  - Back button (main exit) intercepted when dirty → witchy modal: **Save & leave / Leave without saving / Stay** (big buttons).
  - Browser close/refresh → native `beforeunload` when dirty.
  - Ctrl+K search overlay navigation must respect the same dirty check (it can leave the editor too).

### A2. Redesign Save button to fit theme (pairs with A1)
- Metaphor: "sealing the page" — wax-seal/sigil feel, gold accent, Cinzel lettering, flanked by ✦, same glow language as new `.back-btn` (header reads as a matched set).
- State mapping: dirty = warm candlelight pulse "✦ Save"; saved = settled/dim seal "Saved ☾". Keep the literal word "Save" (clarity > cleverness).
- **Mock 2+ variants in screenshots before wiring — taste call, show user.**

### A3. Favorite out of the kebab menu (accident risk next to Delete)
- Promote favorite to its own **header star toggle** next to Save: `☆` off / glowing gold `⭐` on; circular glow treatment matching `.back-btn`; ≥44px target; tooltip "Add to favorites."
- ⋮ menu then holds **only** "Delete entry" (destructive action alone; keep existing confirm dialog).

### A4. "Photo" → "Image" (editor)
- Toolbar 📷 button becomes insert-**Image**: 📷 is wrong metaphor (implies camera/gallery). Swap glyph to framed-picture (try 🖼️ vs a CSS moon-and-frame glyph matching toolbar line style — pick best at Debbie's size) + "Image" label/tooltip.
- Rename all USER-FACING "photo" strings → "image" (upload errors, tooltips, captions UI).
- Leave internal names as-is: `/photos` API, DB table, code identifiers (churn with no user benefit).

---

## GROUP B — Flutter "fallout" (features in old Flutter app, never ported to React)
Flutter source still at `C:\Users\micha\Projects\devinejournal\app\lib\` (reference only).

### B1. Full-page Gratitude Garden (garden_screen.dart, 167 lines) ⭐ MUST integrate with v1.7 system
- Flutter had a whole Garden PAGE: **every line of every gratitude entry = its own flower** in a grid; tapping a flower reveals the actual gratitude TEXT + date ("🌷 · March 4, 2026 — 'the smell of rain on the porch'").
- Flutter flower pool: `['🌸','🌼','🌻','🌷','🌹','💐','🌺','🪻']`. Parse: split body into lines, strip leading `N. `, each non-empty line → flower.

**CRITICAL — must reconcile with the v1.7 perennial system (user's explicit requirement), NOT replace it.**
The two mechanics are different granularities; unify into ONE coherent garden so they don't contradict:
- v1.7 (already LIVE): right-panel WIDGET = daily mini-game. Growing plant (streak/stage), 1-day grace "resting" state, and **cycle-blooms** = 1 permanent flower per 21 written days, harvested into the bed. `buildGarden()` in Timeline.jsx. Bloom click → story card + entry link. Nostalgia nudge for blooms >30 days old.
- v1.9 full page = **"Visit your garden ✦"**, reached from the widget's bed. Design so the two agree:
  - The page shows the SAME harvested cycle-blooms as the widget (one flower per completed 21-day cycle), each tappable → its story (the reconciling unit is the CYCLE, consistent with what the widget already renders).
  - Then, WITHIN a bloom's detail, expand to the individual gratitude LINES written during that cycle (this is where the Flutter "each line = a flower/keepsake" idea lives — as the petals/contents of that bloom, not as a separate competing count).
  - So: widget = today's plant + bed of cycle-blooms → page = full bed + per-bloom the real gratitude lines that grew it. Nostalgia nudge upgrades to quote a REAL line from that cycle instead of just the date.
  - Keep FLOWERS pool consistent between widget and page. Do NOT introduce a second, contradictory "line-count" flower total on the timeline widget.

### B2. Year in Review / Mood Insights (review_screen.dart, 353 lines) — this IS the backlog "mood insights" item
Exact metrics from Flutter (complete spec to port):
- 3 stat cards: entries 📝 / total words ✍️ / longest streak 🔥.
- 12-month activity **bar chart** (bars scaled to busiest month, count labels).
- **Dominant mood**: biggest mood emoji in a tinted circle + sentence "You carried this feeling most through {year}."
- **Mood landscape strip**: one colored tick per journaled day (color = mood), horizontally scrollable, tooltip "{mood} m/d".
- **Top 5 tags** with proportion bars (value/total entries) + counts.
- Mood→color map is in review_screen.dart lines 6-24 (reuse or map to existing moods.js).
- Longest-streak algo: unique days sorted, count consecutive (diff == 1 day).
- Later: could fold in "mood constellations" idea (C5) here.

### B3. PDF / Print export (pdf_export.dart, 121 lines) — backlog
- "Print journal": export selected entries or a date range to formatted PDF.
- React recommendation: `window.print()` + print stylesheet (simplest) OR jspdf+html2canvas for a real file. Read pdf_export.dart for layout intent.

### B4. PIN / passcode lock (lock_screen.dart + security_settings_screen.dart + passcode_service.dart) — DEFERRED by design
- 4-digit PIN, SHA-256 hash in localStorage, auto-lock timeout, shake on wrong PIN, "Forgot PIN = sign out."
- Full plan already written: `C:\Users\micha\.claude\plans\i-woul-like-to-elegant-balloon.md`.
- Keep deferred until core experience is solid.

(Note: gratitude_screen.dart = dedicated composer; already covered by React entry-type template. Nothing to port.)

---

## GROUP C — New "fun & cute" ideas (Claude's suggestions, user liked ALL)
Shortlist for impact-per-effort: **C1 Card of the Day, C2 Wheel of the Year, C3 Familiar** (all deepen the daily-visit ritual).

### C1. Card of the Day 🔮 (Debbie reads tarot professionally — app has zero tarot!)
- Right-panel daily draw, 22 Major Arcana + short gentle interpretations, date-seeded (same card all day, like the affirmation).
- "Draw today's card" → flip with shimmer. "Journal this" → starts a Reflection entry pre-filled with card + prompt.

### C2. Wheel of the Year 🎡 (app knows moon, not sabbats)
- Awareness of Samhain, Yule, Imbolc, Ostara, Beltane, Litha, Lughnasadh, Mabon.
- Header/Almanac: "✦ Litha is in 3 days ✦"; special prompts on the day; Almanac marks them like holidays.

### C3. A familiar 🐈‍⬛
- Little black cat in timeline right panel: asleep if she hasn't written today; awake/blinking after she writes; occasionally bats a ✦ across the panel. Zero mechanics, pure companionship (same spirit as garden).

### C4. Candlelit writing mode 🕯️
- Editor "light a candle" toggle: dims chrome, soft flickering candle glow in corner. Fits shadow work / evening journaling.

### C5. Mood constellations ✨
- Each month's moods plotted as stars joined into a unique constellation; auto-name it ("The Month of the Quiet Flame") from a small word list. Dovetails with B2 review screen.

### C6. Wax-seal moment for time capsules 💌
- Sealing an entry (Lock until) plays a brief wax-stamp animation; sealed card carries the seal mark. Makes her favorite dramatic feature FEEL dramatic. (Synergy: shares wax-seal visual language with A2 save button.)

### C7. Charm shelf 🧿
- Quiet milestone collectibles (first dream log, 100 entries, full-moon ritual on an actual full moon) → crystals/herbs/talismans appear on a shelf in right panel. Derived from history, no storage.

---

## Suggested sequencing (for discussion, not locked)
1. **v1.8 — Group A** (the 4 bugs; A1+A2+A3 all touch the editor header, do together; A4 small).
2. **v1.9 — B1 Garden page + B2 Year in Review** (both are history-derived, high delight, complete Flutter specs).
3. **v1.10 — C1 Card of the Day + C6 wax-seal + C3 familiar** (daily-ritual pack).
4. Later / as-wanted: C2 Wheel of the Year, C4 candlelit, C5 constellations, C7 charm shelf, B3 PDF export.
5. Deferred: B4 PIN lock.

## Build/deploy reminders
- Full deploy creds/host details are in PRIVATE memory (devinejournal-build-state) — NOT here (this file is in the public repo).
- Flow: `npm run build` → ../server/static; upload changed files; rebuild Docker `--no-cache`.
- Verify with `client/shots.mjs` (gitignored) — local `vite preview` before deploy, then live. READ the PNGs; runtime errors only surface there.
- Model note: planning/exploration → cheaper subagents; implementation/deploy → top model.
