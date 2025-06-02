// File: frontend/static/js/endpoints/collaboration_api.js

const BASE = ''; // same-origin

/**
 * List collaborations, with optional filters.
 * Supported filter keys:
 *   name, start, end, song, labels, contributors
 */
export async function listCollaborations(filters = {}) {
  const params = new URLSearchParams(filters);
  const res = await fetch(`${BASE}/api/collaborations?${params.toString()}`);
  if (!res.ok) throw res;
  return res.json();
}

/** Get a single collaboration by ID */
export async function getCollaboration(id) {
  const res = await fetch(`${BASE}/api/collaborations/${id}`);
  if (!res.ok) throw res;
  return res.json();
}

/**
 * Create a new collaboration.
 * Expects an object with keys:
 *   CollaborationName, StartDate, EndDate,
 *   Description, SongID, RecordLabels, Contributors
 */
export async function createCollaboration(data) {
  const res = await fetch(`${BASE}/api/collaborations`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  if (!res.ok) throw res;
  return res.json();
}

/**
 * Update an existing collaboration.
 * `id` is the CollaborationID; `data` same shape as for createCollaboration.
 */
export async function updateCollaboration(id, data) {
  const res = await fetch(`${BASE}/api/collaborations/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  if (!res.ok) throw res;
  return res.json();
}

/** Delete a collaboration by ID */
export async function deleteCollaboration(id) {
  const res = await fetch(`${BASE}/api/collaborations/${id}`, {
    method: 'DELETE',
  });
  if (!res.ok) throw res;
  // 204 No Content
  return;
}
