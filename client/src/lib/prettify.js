// Her card meanings are stored as plain text (kept untouched, her words).
// This turns that text into readable markup at display time: blank lines
// become paragraphs, "• " runs become real lists. No walls of text.

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

export function prettify(text) {
  if (!text) return '';
  const blocks = text.replace(/\r/g, '').split(/\n{2,}/);
  return blocks.map(block => {
    let html = '';
    let list = [];
    const flush = () => {
      if (list.length) {
        html += `<ul>${list.map(l => `<li>${esc(l)}</li>`).join('')}</ul>`;
        list = [];
      }
    };
    for (const line of block.split('\n')) {
      const m = line.match(/^\s*[•-]\s+(.*)/);
      if (m) list.push(m[1]);
      else {
        flush();
        if (line.trim()) html += `<p>${esc(line.trim())}</p>`;
      }
    }
    flush();
    return html;
  }).join('');
}
