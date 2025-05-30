const BASE = ''; // same-origin

/**
 * List songs with optional filters.
 * Supported filter keys (all optional):
 *   title, minDuration, maxDuration, releaseDate,
 *   genre, contributor, collaboration
 */
export async function listSongs(filters = {}) {
  const params = new URLSearchParams();
  if (filters.title)       params.set('title', filters.title);
  if (filters.minDuration) params.set('minDuration', filters.minDuration);
  if (filters.maxDuration) params.set('maxDuration', filters.maxDuration);
  if (filters.releaseDate) params.set('releaseDate', filters.releaseDate);
  if (filters.genre)       params.set('genre', filters.genre);
  if (filters.contributor) params.set('contributor', filters.contributor);
  if (filters.collaboration) params.set('collaboration', filters.collaboration);

  const res = await fetch(`${BASE}/api/songs?${params.toString()}`);
  if (!res.ok) throw res;
  return res.json();
}

/** Get a single song by ID */
export async function getSong(id) {
  const res = await fetch(`${BASE}/api/songs/${id}`);
  if (!res.ok) throw res;
  return res.json();
}

/**
 * Create a new song.
 * Expects an object with keys:
 *   Title, Duration, ReleaseDate, Genres, Contributors, CollaborationName
 */
export async function createSong(data) {
  const res = await fetch(`${BASE}/api/songs`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  if (!res.ok) throw res;
  return res.json();
}

/**
 * Update an existing song.
 * `id` is the SongID, `data` same shape as createSong.
 */
export async function updateSong(id, data) {
  const res = await fetch(`${BASE}/api/songs/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  if (!res.ok) throw res;
  return res.json();
}

/** Delete a song by ID */
export async function deleteSong(id) {
  const res = await fetch(`${BASE}/api/songs/${id}`, {
    method: 'DELETE',
  });
  if (!res.ok) throw res;
  // 204 No Content
  return;
}
