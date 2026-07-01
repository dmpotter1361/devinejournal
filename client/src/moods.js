// DevineJournal moods — 17 emoji + empty (no mood).
// Empty string = "no mood selected" (shows as an outline icon).

export const MOODS = [
  '', '✨', '🌙', '🌸', '🔥', '💫', '🌿', '🖤', '💜',
  '🌊', '⚡', '🌻', '🦋', '🌹', '💝', '🌺', '🌼', '🌠',
];

export const MOOD_COLORS = {
  '✨': '#f8df6e',
  '🌙': '#9b72cf',
  '🌸': '#f48fb1',
  '🔥': '#ff7043',
  '💫': '#81d4fa',
  '🌿': '#81c784',
  '🖤': '#90a4ae',
  '💜': '#ce93d8',
  '🌊': '#4dd0e1',
  '⚡': '#ffee58',
  '🌻': '#ffd54f',
  '🦋': '#80deea',
  '🌹': '#ef9a9a',
  '💝': '#ff80ab',
  '🌺': '#ffab40',
  '🌼': '#fff176',
  '🌠': '#7986cb',
};

export const moodColor = (m) => MOOD_COLORS[m] || null;
