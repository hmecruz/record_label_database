// frontend/static/js/employee.js

import {
  listEmployees,
  getEmployee,
  createEmployee,
  updateEmployee,
  deleteEmployee
} from './endpoints/employee_api.js';

import { listLabels } from './endpoints/record_label_api.js';

function debounce(fn, delay = 300) {
  let timer;
  return (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), delay);
  };
}

async function employeeInit() {
  console.log('[employeeInit] start');

  // Sections & controls
  const listSection    = document.getElementById('emp-list-section');
  const detailsSection = document.getElementById('emp-details-section');
  const modal          = document.getElementById('emp-form-modal');
  const form           = document.getElementById('emp-form');
  const addBtn         = document.getElementById('add-emp-btn');
  const cancelBtn      = document.getElementById('emp-cancel-btn');

  // Conflict‐resolution modal elements (reuse same IDs as contributor.js conflict modal)
  const conflictModal     = document.getElementById('conflict-modal');
  const conflictNifSpan   = document.getElementById('conflict-nif');
  const existingNameSpan  = document.getElementById('existing-name');
  const existingDobSpan   = document.getElementById('existing-dob');
  const existingEmailSpan = document.getElementById('existing-email');
  const existingPhoneSpan = document.getElementById('existing-phone');
  const incomingNameSpan  = document.getElementById('incoming-name');
  const incomingDobSpan   = document.getElementById('incoming-dob');
  const incomingEmailSpan = document.getElementById('incoming-email');
  const incomingPhoneSpan = document.getElementById('incoming-phone');
  const keepBtn           = document.getElementById('conflict-keep-btn');
  const overwriteBtn      = document.getElementById('conflict-overwrite-btn');
  const conflictCancelBtn = document.getElementById('conflict-cancel-btn');

  // Filter inputs (matching employee.html)
  const filters = {
    name:       document.getElementById('filter-name'),
    label:      document.getElementById('filter-label'),
    jobtitle:   document.getElementById('filter-jobtitle'),
    department: document.getElementById('filter-department'),
    salary:     document.getElementById('filter-salary'),
    email:      document.getElementById('filter-email'),
    phone:      document.getElementById('filter-phone'),
    nif:        document.getElementById('filter-nif'),
  };

  // Keys that go to server‐side filtering
  const serverKeys = ['name', 'jobtitle', 'department', 'email', 'phone', 'nif'];

  let employees = [];
  let labels = [];

  // Populate Record Label <select> inside form
  async function populateLabelDropdown() {
    labels = await listLabels();
    const select = form.elements['RecordLabelID'];
    labels.forEach(lbl => {
      const opt = document.createElement('option');
      opt.value = lbl.RecordLabelID;
      opt.textContent = lbl.Name;
      select.appendChild(opt);
    });
  }

  // Render employees into table
  function renderTable(data) {
    const tbody = document.querySelector('#emp-list-table tbody');
    tbody.innerHTML = data.map(e => `
      <tr data-id="${e.EmployeeID}">
        <td>${e.EmployeeID}</td>
        <td>${e.Name}</td>
        <td>${e.RecordLabelName || ''}</td>
        <td>${e.JobTitle}</td>
        <td>${e.Department || ''}</td>
        <td>${e.Salary.toFixed(2)}</td>
        <td>${e.HireDate}</td>
        <td>${e.Email || ''}</td>
        <td>${e.PhoneNumber || ''}</td>
        <td>${e.DateOfBirth || ''}</td>
        <td>${e.NIF}</td>
      </tr>
    `).join('');
    document
      .querySelectorAll('#emp-list-table tbody tr')
      .forEach(row => row.onclick = () => showDetails(+row.dataset.id));
  }

  let fetchId = 0;
  async function fetchAndRender() {
    const myFetch = ++fetchId;
    const params = {};
    serverKeys.forEach(k => {
      const v = filters[k].value.trim();
      if (v) params[k] = v;
    });

    try {
      let data = await listEmployees(params);
      if (myFetch !== fetchId) return; // stale

      // Client‐side filter: minimum salary
      const minSalary = parseFloat(filters.salary.value) || 0;
      // Client‐side filter: record label substring
      const labelTerm = filters.label.value.trim().toLowerCase();

      data = data.filter(e => {
        if (filters.salary.value && e.Salary < minSalary) return false;
        if (labelTerm && !(e.RecordLabelName || '').toLowerCase().includes(labelTerm)) return false;
        return true;
      });

      employees = data;
      renderTable(employees);
    } catch (err) {
      console.error('[API] listEmployees failed', err);
      alert('Failed to load employees.');
    }
  }

  // Show Details view
  async function showDetails(id) {
    listSection.classList.add('hidden');
    detailsSection.classList.remove('hidden');
    modal.classList.add('hidden');
    if (conflictModal) conflictModal.classList.add('hidden');

    let emp;
    try {
      emp = await getEmployee(id);
    } catch (err) {
      console.error('[API] getEmployee failed', err);
      alert('Failed to load employee details.');
      return;
    }

    document.getElementById('emp-details').innerHTML = `
      <p><strong>ID:</strong> ${emp.EmployeeID}</p>
      <p><strong>NIF:</strong> ${emp.NIF}</p>
      <p><strong>Name:</strong> ${emp.Name}</p>
      <p><strong>Date of Birth:</strong> ${emp.DateOfBirth || '-'}</p>
      <p><strong>Job Title:</strong> ${emp.JobTitle}</p>
      <p><strong>Department:</strong> ${emp.Department || '-'}</p>
      <p><strong>Salary:</strong> ${emp.Salary.toFixed(2)}</p>
      <p><strong>Hire Date:</strong> ${emp.HireDate}</p>
      <p><strong>Email:</strong> ${emp.Email || '-'}</p>
      <p><strong>Phone:</strong> ${emp.PhoneNumber || '-'}</p>
      <p><strong>Record Label:</strong> ${emp.RecordLabelName || '-'}</p>
    `;

    document.getElementById('edit-emp-btn').onclick = () => openForm('Edit Employee', emp);
    document.getElementById('delete-emp-btn').onclick = async () => {
      if (!confirm(`Delete employee “${emp.Name}”?`)) return;
      try {
        await deleteEmployee(emp.EmployeeID);
        await fetchAndRender();
        backToList();
      } catch (err) {
        console.error('[API] deleteEmployee failed', err);
        alert('Failed to delete employee.');
      }
    };
    document.getElementById('back-emp-list-btn').onclick = backToList;
  }

  function backToList() {
    detailsSection.classList.add('hidden');
    listSection.classList.remove('hidden');
    modal.classList.add('hidden');
    renderTable(employees);
  }

  // Open “Add/Edit Employee” modal
  function openForm(title, emp = {}) {
    document.getElementById('emp-modal-title').textContent = title;
    form.reset();
    if (conflictModal) conflictModal.classList.add('hidden');

    // Pre-fill fields if editing
    form.elements['EmployeeID'].value     = emp.EmployeeID || '';
    form.elements['NIF'].value            = emp.NIF || '';
    form.elements['Name'].value           = emp.Name || '';
    form.elements['DateOfBirth'].value    = emp.DateOfBirth || '';
    form.elements['JobTitle'].value       = emp.JobTitle || '';
    form.elements['Department'].value     = emp.Department || '';
    form.elements['Salary'].value         = emp.Salary != null ? emp.Salary : '';
    form.elements['HireDate'].value       = emp.HireDate || '';
    form.elements['Email'].value          = emp.Email || '';
    form.elements['PhoneNumber'].value    = emp.PhoneNumber || '';
    form.elements['RecordLabelID'].value  = emp.RecordLabelID || '';

    modal.classList.remove('hidden');
  }

  addBtn.onclick = e => { e.preventDefault(); openForm('Add Employee'); };
  cancelBtn.onclick = e => { e.preventDefault(); modal.classList.add('hidden'); };

  form.onsubmit = async e => {
    e.preventDefault();
    const data = Object.fromEntries(new FormData(form));

    // Validate required fields
    if (!data.NIF.trim()) {
      alert("Field 'NIF' is required");
      return;
    }
    if (!data.Name.trim()) {
      alert("Field 'Name' is required");
      return;
    }
    if (!data.JobTitle.trim()) {
      alert("Field 'JobTitle' is required");
      return;
    }
    if (!data.Salary) {
      alert("Field 'Salary' is required");
      return;
    }
    if (!data.HireDate) {
      alert("Field 'HireDate' is required");
      return;
    }
    if (!data.RecordLabelID) {
      alert("Field 'RecordLabelID' is required");
      return;
    }

    try {
      // 1) If editing, just call updateEmployee
      if (data.EmployeeID) {
        await updateEmployee(data.EmployeeID, data);
        modal.classList.add('hidden');
        await fetchAndRender();
        backToList();
        return;
      }

      // 2) Otherwise, attempt to create a new Employee
      try {
        await createEmployee(data);
        modal.classList.add('hidden');
        await fetchAndRender();
        backToList();
      } catch (res) {
        // If server returns 409 Conflict, show conflict modal
        if (res instanceof Response && res.status === 409) {
          let payload;
          try {
            payload = await res.json();
          } catch {
            alert("Unexpected server response. Please try again.");
            return;
          }

          const existingPerson = payload.existingPerson;
          const incomingData   = payload.incomingData;

          // Populate conflict modal fields
          conflictNifSpan.textContent   = existingPerson.NIF;
          existingNameSpan.textContent  = existingPerson.Name;
          existingDobSpan.textContent   = existingPerson.DateOfBirth || '(none)';
          existingEmailSpan.textContent = existingPerson.Email || '(none)';
          existingPhoneSpan.textContent = existingPerson.PhoneNumber || '(none)';

          incomingNameSpan.textContent  = incomingData.Name;
          incomingDobSpan.textContent   = incomingData.DateOfBirth || '(none)';
          incomingEmailSpan.textContent = incomingData.Email || '(none)';
          incomingPhoneSpan.textContent = incomingData.PhoneNumber || '(none)';

          // Show conflict modal, hide form modal
          conflictModal.classList.remove('hidden');
          modal.classList.add('hidden');

          // Button handlers inside conflict modal

          // Choice A: Keep existing Person, just add Employee under that NIF
          keepBtn.onclick = async () => {
            conflictModal.classList.add('hidden');
            try {
              await createEmployee(incomingData, '?useOldPerson=true');
              await fetchAndRender();
              backToList();
            } catch (err2) {
              console.error('[API] keep-old-person failed', err2);
              alert("Failed to add Employee under existing Person.");
            }
          };

          // Choice B: Overwrite Person fields, then add Employee under that NIF
          overwriteBtn.onclick = async () => {
            try {
              // 1) Update Person via PUT /api/persons/:nif
              const updatePersonRes = await fetch(
                `/api/persons/${existingPerson.NIF}`,
                {
                  method: 'PUT',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({
                    Name:         incomingData.Name,
                    DateOfBirth:  incomingData.DateOfBirth,
                    Email:        incomingData.Email,
                    PhoneNumber:  incomingData.PhoneNumber
                  })
                }
              );
              if (!updatePersonRes.ok) {
                throw updatePersonRes;
              }

              // 2) Now add Employee under that same NIF
              await createEmployee(incomingData, '?useOldPerson=true');
              conflictModal.classList.add('hidden');
              await fetchAndRender();
              backToList();
            } catch (err3) {
              console.error('[API] overwrite failed', err3);
              alert("Failed to overwrite Person or add Employee.");
            }
          };

          // Choice C: Cancel
          conflictCancelBtn.onclick = () => {
            conflictModal.classList.add('hidden');
          };
        }
        else {
          // Some other HTTP error
          console.error('[API] createEmployee failed', res);
          alert('Failed to save employee.');
        }
      }
    } catch (err) {
      console.error('[API] saveEmployee failed (unexpected)', err);
      alert('Failed to save employee.');
    }
  };

  // Wire up filter inputs with debounce
  const deb = debounce(fetchAndRender, 300);
  Object.values(filters).forEach(inp => { if (inp) inp.oninput = deb; });

  // Initial population
  await populateLabelDropdown();
  await fetchAndRender();
  console.log('[employeeInit] done');
}

// Expose for main loader
window.employeeInit = employeeInit;
