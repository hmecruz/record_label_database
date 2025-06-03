const BASE = ''; // same-origin

/**
 * List employees, with optional filters.
 * Supported filter keys: nif, name, jobtitle, department, email, phone
 * (Record-label filtering can be done client-side if desired.)
 */
export async function listEmployees(filters = {}) {
  const params = new URLSearchParams();
  if (filters.nif)        params.set('nif', filters.nif);
  if (filters.name)       params.set('name', filters.name);
  if (filters.jobtitle)   params.set('jobtitle', filters.jobtitle);
  if (filters.department) params.set('department', filters.department);
  if (filters.email)      params.set('email', filters.email);
  if (filters.phone)      params.set('phone', filters.phone);

  const res = await fetch(`${BASE}/api/employees?${params.toString()}`);
  if (!res.ok) throw res;
  return res.json();
}

/** Get a single employee by ID */
export async function getEmployee(id) {
  const res = await fetch(`${BASE}/api/employees/${id}`);
  if (!res.ok) throw res;
  return res.json();
}

/**
 * Create a new employee.
 * Expects an object with keys:
 *   NIF, Name, DateOfBirth, Email, PhoneNumber,
 *   JobTitle, Department, Salary, HireDate, RecordLabelID
 *
 * Optionally append a query string (e.g. '?useOldPerson=true' or '?overwritePerson=true')
 * to handle the “existing Person” workflows.
 *
 * If the server finds a conflicting Person (same NIF but different fields),
 * it will return HTTP 409 Conflict with JSON describing:
 *   { message, existingPerson, incomingData }
 */
export async function createEmployee(data, queryString = '') {
  const url = `${BASE}/api/employees${queryString}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  if (!res.ok) throw res;
  return res.json();
}

/**
 * Update an existing employee.
 * `id` is the EmployeeID.
 * `data` has the same shape as for createEmployee, including a (possibly new) NIF.
 *
 * If you attempt to change NIF to one that already exists, the server returns 409.
 */
export async function updateEmployee(id, data) {
  const res = await fetch(`${BASE}/api/employees/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  if (!res.ok) throw res;
  return res.json();
}

/** Delete an employee by ID */
export async function deleteEmployee(id) {
  const res = await fetch(`${BASE}/api/employees/${id}`, {
    method: 'DELETE',
  });
  if (!res.ok) throw res;
  // 204 No Content
  return;
}

/**
 * (Optional) Fetch dependency counts for a given employee.
 * Returns { CollaborationCount, SongCount } for that Employee’s Person.
 */
export async function getEmployeeDependencies(id) {
  const res = await fetch(`${BASE}/api/employees/${id}/dependencies`);
  if (!res.ok) throw res;
  return res.json();
}
