const BASE = ''; // same-origin

/**
 * List employees, with optional filters.
 * Supported filter keys: nif, name, jobtitle, department, email, phone, label
 */
export async function listEmployees(filters = {}) {
  const params = new URLSearchParams(filters);
  const res = await fetch(`${BASE}/api/employees?${params}`);
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
 */
export async function createEmployee(data) {
  const res = await fetch(`${BASE}/api/employees`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  if (!res.ok) throw res;
  return res.json();
}

/**
 * Update an existing employee.
 * `id` is the EmployeeID, `data` same shape as for createEmployee.
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
