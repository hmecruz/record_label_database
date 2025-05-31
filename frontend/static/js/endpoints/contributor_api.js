// frontend/static/js/endpoints/contributor_api.js

const BASE = ''; // same-origin

/**
 * List contributors with optional filters.
 * Supported filter keys: name, role, email, phone
 * Each returned object includes:
 *   ContributorID, NIF, Name, DateOfBirth,
 *   Email, PhoneNumber, RecordLabelName, Roles
 */
export async function listContributors(filters = {}) {
  const params = new URLSearchParams();
  if (filters.name)  params.set('name', filters.name);
  if (filters.role)  params.set('role', filters.role);
  if (filters.email) params.set('email', filters.email);
  if (filters.phone) params.set('phone', filters.phone);

  const res = await fetch(`${BASE}/api/contributors?${params.toString()}`);
  if (!res.ok) throw res;
  return res.json();
}

/** Get a single contributor by ID */
export async function getContributor(id) {
  const res = await fetch(`${BASE}/api/contributors/${id}`);
  if (!res.ok) throw res;
  return res.json();
}

/**
 * Create a new contributor.
 * Expects an object with keys:
 *   NIF, Name, DateOfBirth, Email, PhoneNumber, Roles
 *
 * If the server finds a conflicting Person (same NIF but different fields),
 * it will return HTTP 409 Conflict and a JSON payload describing:
 *   { message, existingPerson, attempted, differences }
 * So we simply “throw res” on a non‐2xx; the caller can inspect .status === 409.
 *
 * Returns the newly‐created contributor (with RecordLabelName, etc.)
 */
export async function createContributor(data) {
  const res = await fetch(`${BASE}/api/contributors`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  if (!res.ok) throw res;
  return res.json();
}

/**
 * Update an existing contributor.
 * `id` is the ContributorID; `data` has the same shape as createContributor.
 *
 * Returns the updated contributor record.
 */
export async function updateContributor(id, data) {
  const res = await fetch(`${BASE}/api/contributors/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  if (!res.ok) throw res;
  return res.json();
}

/** Delete a contributor by ID */
export async function deleteContributor(id) {
  const res = await fetch(`${BASE}/api/contributors/${id}`, {
    method: 'DELETE',
  });
  if (!res.ok) throw res;
  // 204 No Content
  return;
}
