const BASE = ''; // same-origin

/**
 * List all record labels with optional filters.
 * Supported filter keys: name, location, website, email, phone
 */
export async function listLabels(filters = {}) {
  const params = new URLSearchParams(filters);
  const res = await fetch(`${BASE}/api/record_labels?${params.toString()}`);
  if (!res.ok) throw res;
  return res.json();
}

/** Get a single record label by ID */
export async function getLabel(id) {
  const res = await fetch(`${BASE}/api/record_labels/${id}`);
  if (!res.ok) throw res;
  return res.json();
}

/**
 * Create a new record label.
 * Expects an object with keys: Name, Location, Website, Email, PhoneNumber
 */
export async function createLabel(data) {
  const res = await fetch(`${BASE}/api/record_labels`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  });
  if (!res.ok) throw res;
  return res.json();
}

/**
 * Update an existing record label.
 * `id` is the RecordLabelID; `data` has keys Name, Location, Website, Email, PhoneNumber
 */
export async function updateLabel(id, data) {
  const res = await fetch(`${BASE}/api/record_labels/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  });
  if (!res.ok) throw res;
  return res.json();
}

/**
 * Delete a record label by ID.
 * If `cascade` is true, we append ?cascade=true so the server runs sp_DeleteRecordLabel_Cascade.
 * Otherwise, it runs the simple sp_DeleteRecordLabel (which first checks for dependencies via sp_CheckRecordLabelDependencies).
 */
export async function deleteLabel(id, { cascade = false } = {}) {
  const url = cascade
    ? `${BASE}/api/record_labels/${id}?cascade=true`
    : `${BASE}/api/record_labels/${id}`;

  const res = await fetch(url, {
    method: 'DELETE'
  });

  // If there are still dependencies and cascade=false, server will return 409 Conflict + JSON { employeeCount, collaborationCount }.
  if (!res.ok) {
    // Propagate the response to the caller so they can inspect status 409 and parse JSON.
    throw res;
  }

  // 204 No Content on a successful delete
  return;
}
