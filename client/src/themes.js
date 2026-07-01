// DevineJournal paper themes — 7 witchy/atmospheric palettes.
// Applied globally via data-theme on <html>; CSS variables switch the whole app.

export const THEMES = [
  {
    id: 'midnight',
    name: 'Midnight',
    dot: '#9b72cf',
    dark: true,
    vars: {
      '--bg': '#0e0b18',
      '--surface': '#1e1a40',
      '--surface-2': '#181535',
      '--ink': '#ede6ff',
      '--heading': '#c9a84c',
      '--accent': '#c9a84c',
      '--muted': '#8878b8',
      '--line': '#2d2460',
      '--ruler': '#23205a',
    },
  },
  {
    id: 'parchment',
    name: 'Parchment',
    dot: '#c4762a',
    dark: false,
    vars: {
      '--bg': '#b89660',
      '--surface': '#f5ead0',
      '--surface-2': '#fdf6e3',
      '--ink': '#2d1a0e',
      '--heading': '#7a3a10',
      '--accent': '#c4762a',
      '--muted': '#8b6050',
      '--line': '#d4b896',
      '--ruler': '#e8d8b8',
    },
  },
  {
    id: 'moonlit',
    name: 'Moonlit',
    dot: '#5b9fc4',
    dark: false,
    vars: {
      '--bg': '#1a2a3f',
      '--surface': '#e4ecf4',
      '--surface-2': '#eef2f8',
      '--ink': '#1a2535',
      '--heading': '#2c6b9a',
      '--accent': '#5b9fc4',
      '--muted': '#6b8a9f',
      '--line': '#c5d8e8',
      '--ruler': '#d8e6f0',
    },
  },
  {
    id: 'dawn',
    name: 'Dawn',
    dot: '#e87a8c',
    dark: false,
    vars: {
      '--bg': '#f9edf1',
      '--surface': '#f5dfe8',
      '--surface-2': '#fdf5f7',
      '--ink': '#3a1a26',
      '--heading': '#b5385a',
      '--accent': '#d45c7a',
      '--muted': '#b890a0',
      '--line': '#e8c0cc',
      '--ruler': '#f0d5de',
    },
  },
  {
    id: 'forest',
    name: 'Forest',
    dot: '#5aaa6e',
    dark: true,
    vars: {
      '--bg': '#0d1a0f',
      '--surface': '#1a2a1c',
      '--surface-2': '#141f16',
      '--ink': '#d0f0d8',
      '--heading': '#7dcc90',
      '--accent': '#5aaa6e',
      '--muted': '#5a8064',
      '--line': '#243828',
      '--ruler': '#1e2e20',
    },
  },
  {
    id: 'celestial',
    name: 'Celestial',
    dot: '#b39dff',
    dark: true,
    vars: {
      '--bg': '#090916',
      '--surface': '#15153a',
      '--surface-2': '#0f0f28',
      '--ink': '#e8e0f8',
      '--heading': '#d4c0ff',
      '--accent': '#b39dff',
      '--muted': '#7a6a9a',
      '--line': '#2a2055',
      '--ruler': '#221d48',
    },
  },
  {
    id: 'rosewood',
    name: 'Rosewood',
    dot: '#e89aac',
    dark: true,
    vars: {
      '--bg': '#1a0a10',
      '--surface': '#301720',
      '--surface-2': '#261218',
      '--ink': '#f0dce4',
      '--heading': '#f4c4d4',
      '--accent': '#e89aac',
      '--muted': '#8a5a6a',
      '--line': '#4a2030',
      '--ruler': '#3a1828',
    },
  },
];

const BY_ID = Object.fromEntries(THEMES.map((t) => [t.id, t]));

export const themeById = (id) => BY_ID[id] || BY_ID.midnight;

export function applyTheme(id) {
  const t = themeById(id);
  const root = document.documentElement;
  root.setAttribute('data-theme', id);
  for (const [k, v] of Object.entries(t.vars)) {
    root.style.setProperty(k, v);
  }
}
