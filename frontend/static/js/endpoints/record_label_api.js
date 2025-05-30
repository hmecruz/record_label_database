const BASE = ''; // same-origin

export async function listLabels(filters = {}) {
  const params = new URLSearchParams(filters);
  const res = await fetch(`${BASE}/api/record_labels?${params}`);
  if (!res.ok) throw res;
  return res.json();
}

export async function getLabel(id) {
  const res = await fetch(`${BASE}/api/record_labels/${id}`);
  if (!res.ok) throw res;
  return res.json();
}

export async function createLabel(data) {
  const res = await fetch(`${BASE}/api/record_labels`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  });
  if (!res.ok) throw res;
  return res.json();
}

export async function updateLabel(id, data) {
  const res = await fetch(`${BASE}/api/record_labels/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  });
  if (!res.ok) throw res;
  return res.json();
}

export async function deleteLabel(id) {
  const res = await fetch(`${BASE}/api/record_labels/${id}`, {
    method: 'DELETE'
  });
  if (!res.ok) throw res;
  // 204 No Content
  return;
}
