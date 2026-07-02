// DevineJournal API wrapper — uses JWT Bearer token from localStorage.
// Auth: POST /api/auth/google → JWT → store in localStorage.

export const TOKEN_KEY = 'dj_token';
export const USER_KEY = 'dj_user';

export const getToken = () => localStorage.getItem(TOKEN_KEY);
export const setToken = (t) => localStorage.setItem(TOKEN_KEY, t);
export const clearAuth = () => {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(USER_KEY);
};
export const getUser = () => {
  try { return JSON.parse(localStorage.getItem(USER_KEY) || 'null'); } catch { return null; }
};

async function req(path, method = 'GET', body) {
  const token = getToken();
  const headers = {};
  if (token) headers['Authorization'] = `Bearer ${token}`;
  if (body !== undefined) headers['Content-Type'] = 'application/json';

  const res = await fetch(`/api${path}`, {
    method,
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });

  if (res.status === 401) {
    clearAuth();
    window.location.href = '/';
    throw new Error('Not authenticated');
  }
  if (!res.ok) {
    let msg = 'Something went wrong';
    try { const j = await res.json(); msg = j.detail || j.error || msg; } catch { /* */ }
    const e = new Error(msg);
    e.status = res.status;
    throw e;
  }
  if (res.status === 204) return null;
  const ct = res.headers.get('content-type') || '';
  return ct.includes('application/json') ? res.json() : res.text();
}

export const api = {
  googleAuth: (access_token) => req('/auth/google', 'POST', { access_token }),

  listEntries: () => req('/entries'),
  searchEntries: (q) => req(`/entries/search?q=${encodeURIComponent(q)}`),
  getEntry: (id) => req(`/entries/${id}`),
  createEntry: (data) => req('/entries', 'POST', data),
  updateEntry: (id, data) => req(`/entries/${id}`, 'PUT', data),
  deleteEntry: (id) => req(`/entries/${id}`, 'DELETE'),

  listPhotos: (entryId) => req(`/entries/${entryId}/photos`),
  uploadPhoto: async (entryId, file) => {
    const token = getToken();
    const fd = new FormData();
    fd.append('file', file);
    const res = await fetch(`/api/entries/${entryId}/photos`, {
      method: 'POST',
      headers: token ? { 'Authorization': `Bearer ${token}` } : {},
      body: fd,
    });
    if (!res.ok) throw new Error('Image upload failed');
    return res.json();
  },
  deletePhoto: (photoId) => req(`/photos/${photoId}`, 'DELETE'),

  listVoiceMemos: (entryId) => req(`/entries/${entryId}/voice-memos`),
  uploadVoiceMemo: async (entryId, blob, durationMs) => {
    const token = getToken();
    const fd = new FormData();
    fd.append('file', blob, 'memo.webm');
    fd.append('duration_ms', String(Math.round(durationMs)));
    const res = await fetch(`/api/entries/${entryId}/voice-memos`, {
      method: 'POST',
      headers: token ? { 'Authorization': `Bearer ${token}` } : {},
      body: fd,
    });
    if (!res.ok) throw new Error('Voice memo upload failed');
    return res.json();
  },
  deleteVoiceMemo: (memoId) => req(`/voice-memos/${memoId}`, 'DELETE'),
};
