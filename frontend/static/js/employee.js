// frontend/static/js/employee.js
// Load as an ES module: <script type="module" src="/static/js/employee.js"></script>

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

  // Elements
  const listSection    = document.getElementById('emp-list-section');
  const detailsSection = document.getElementById('emp-details-section');
  const modal          = document.getElementById('emp-form-modal');
  const form           = document.getElementById('emp-form');
  const addBtn         = document.getElementById('add-emp-btn');
  const cancelBtn      = document.getElementById('emp-cancel-btn');

  // Filter inputs
  const filters = {
    nif:        document.getElementById('filter-nif'),
    name:       document.getElementById('filter-name'),
    dob:        document.getElementById('filter-dob'),
    jobtitle:   document.getElementById('filter-jobtitle'),
    department: document.getElementById('filter-department'),
    email:      document.getElementById('filter-email'),
    phone:      document.getElementById('filter-phone'),
    label:      document.getElementById('filter-label')
  };

  // Ensure initial state
  listSection.classList.remove('hidden');
  detailsSection.classList.add('hidden');
  modal.classList.add('hidden');

  let employees = [];
  let labels = [];

  // Build the record‐label dropdown
  async function populateLabelDropdown() {
    try {
      labels = await listLabels();
      const select = form.elements['RecordLabelID'];
      labels.forEach(lbl => {
        const opt = document.createElement('option');
        opt.value = lbl.RecordLabelID;
        opt.textContent = lbl.Name;
        select.appendChild(opt);
      });
    } catch (err) {
      console.error('[API] failed to load labels for dropdown', err);
    }
  }

  // Render table helper
  function renderTable(data) {
    const tbody = document.querySelector('#emp-list-table tbody');
    tbody.innerHTML = data.map(e => `
      <tr data-id="${e.EmployeeID}">
        <td>${e.EmployeeID}</td>
        <td>${e.NIF}</td>
        <td>${e.Name}</td>
        <td>${e.DateOfBirth || ''}</td>
        <td>${e.JobTitle}</td>
        <td>${e.Department || ''}</td>
        <td>${e.Salary.toFixed(2)}</td>
        <td>${e.HireDate}</td>
        <td>${e.Email || ''}</td>
        <td>${e.PhoneNumber || ''}</td>
        <td>${e.RecordLabelName || ''}</td>
      </tr>
    `).join('');
    document.querySelectorAll('#emp-list-table tbody tr').forEach(row => {
      row.onclick = () => showDetails(+row.dataset.id);
    });
  }

  // Fetch & render with current filter values
  let fetchId = 0;
  async function fetchAndRender() {
    const thisFetch = ++fetchId;
    const params = {};
    Object.entries(filters).forEach(([key, inp]) => {
      const val = inp.value.trim();
      if (val) params[key] = val;
    });
    try {
      const data = await listEmployees(params);
      if (thisFetch !== fetchId) return; // stale
      employees = data;
      renderTable(employees);
    } catch (err) {
      console.error('[API] fetch employees failed', err);
      alert('Failed to load employees.');
    }
  }

  // Show details (with fresh fetch)
  async function showDetails(id) {
    listSection.classList.add('hidden');
    detailsSection.classList.remove('hidden');
    modal.classList.add('hidden');

    let e;
    try {
      e = await getEmployee(id);
    } catch (err) {
      console.error('[API] getEmployee failed', err);
      alert('Failed to load employee details.');
      return;
    }

    document.getElementById('emp-details').innerHTML = `
      <p><strong>ID:</strong> ${e.EmployeeID}</p>
      <p><strong>NIF:</strong> ${e.NIF}</p>
      <p><strong>Name:</strong> ${e.Name}</p>
      <p><strong>DOB:</strong> ${e.DateOfBirth || '-'}</p>
      <p><strong>Job Title:</strong> ${e.JobTitle}</p>
      <p><strong>Dept:</strong> ${e.Department || '-'}</p>
      <p><strong>Salary:</strong> ${e.Salary.toFixed(2)}</p>
      <p><strong>Hired:</strong> ${e.HireDate}</p>
      <p><strong>Email:</strong> ${e.Email || '-'}</p>
      <p><strong>Phone:</strong> ${e.PhoneNumber || '-'}</p>
      <p><strong>Label:</strong> ${e.RecordLabelName || '-'}</p>
    `;

    document.getElementById('edit-emp-btn').onclick = () => openForm('Edit Employee', e);
    document.getElementById('delete-emp-btn').onclick = async () => {
      if (!confirm(`Delete employee "${e.Name}"?`)) return;
      try {
        await deleteEmployee(e.EmployeeID);
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

  function openForm(title, emp = {}) {
    document.getElementById('emp-modal-title').textContent = title;
    form.reset();
    form.elements['EmployeeID'].value = emp.EmployeeID || '';
    form.elements['NIF'].value       = emp.NIF || '';
    form.elements['Name'].value      = emp.Name || '';
    form.elements['DateOfBirth'].value = emp.DateOfBirth || '';
    form.elements['JobTitle'].value  = emp.JobTitle || '';
    form.elements['Department'].value = emp.Department || '';
    form.elements['Salary'].value    = emp.Salary != null ? emp.Salary : '';
    form.elements['HireDate'].value  = emp.HireDate || '';
    form.elements['Email'].value     = emp.Email || '';
    form.elements['PhoneNumber'].value = emp.PhoneNumber || '';
    form.elements['RecordLabelID'].value = emp.RecordLabelID || '';
    modal.classList.remove('hidden');
  }

  addBtn.onclick = e => {
    e.preventDefault();
    openForm('Add Employee');
  };

  cancelBtn.onclick = e => {
    e.preventDefault();
    modal.classList.add('hidden');
  };

  form.onsubmit = async e => {
    e.preventDefault();
    const obj = Object.fromEntries(new FormData(form));
    const isEdit = Boolean(obj.EmployeeID);
    try {
      if (isEdit) {
        await updateEmployee(obj.EmployeeID, obj);
      } else {
        await createEmployee(obj);
      }
      modal.classList.add('hidden');
      await fetchAndRender();
      backToList();
    } catch (err) {
      console.error('[API] save employee failed', err);
      alert('Failed to save employee.');
    }
  };

  // Wire filters
  const debouncedFetch = debounce(fetchAndRender, 300);
  Object.values(filters).forEach(inp => {
    if (inp) inp.oninput = debouncedFetch;
  });

  // Initial data load
  await populateLabelDropdown();
  await fetchAndRender();

  console.log('[employeeInit] done');
}

// Expose for your main loader
window.employeeInit = employeeInit;
