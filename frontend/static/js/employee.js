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

  const listSection    = document.getElementById('emp-list-section');
  const detailsSection = document.getElementById('emp-details-section');
  const modal          = document.getElementById('emp-form-modal');
  const form           = document.getElementById('emp-form');
  const addBtn         = document.getElementById('add-emp-btn');
  const cancelBtn      = document.getElementById('emp-cancel-btn');

  // Updated order of filters
  const filterElems = {
    name:       document.getElementById('filter-name'),
    label:      document.getElementById('filter-label'),
    jobtitle:   document.getElementById('filter-jobtitle'),
    department: document.getElementById('filter-department'),
    salary:     document.getElementById('filter-salary'),
    email:      document.getElementById('filter-email'),
    phone:      document.getElementById('filter-phone'),
    nif:        document.getElementById('filter-nif'),
  };

  const serverKeys = ['name', 'jobtitle', 'department', 'email', 'phone', 'nif'];

  let employees = [];
  let labels = [];

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

  // Updated column order to match the table
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
    document.querySelectorAll('#emp-list-table tbody tr')
      .forEach(row => row.onclick = () => showDetails(+row.dataset.id));
  }

  let fetchId = 0;
  async function fetchAndRender() {
    const myFetch = ++fetchId;
    const params = {};
    serverKeys.forEach(k => {
      const v = filterElems[k].value.trim();
      if (v) params[k] = v;
    });

    try {
      const srvRows = await listEmployees(params);
      if (myFetch !== fetchId) return;

      const minSalary = parseFloat(filterElems.salary.value) || 0;
      const labelTerm = filterElems.label.value.trim().toLowerCase();

      employees = srvRows.filter(e => {
        if (filterElems.salary.value && e.Salary < minSalary) return false;
        if (labelTerm && !e.RecordLabelName.toLowerCase().includes(labelTerm)) return false;
        return true;
      });

      renderTable(employees);
    } catch (err) {
      console.error('[API] fetch employees failed', err);
      alert('Failed to load employees.');
    }
  }

  async function showDetails(id) {
    listSection.classList.add('hidden');
    detailsSection.classList.remove('hidden');
    modal.classList.add('hidden');

    let e;
    try {
      e = await getEmployee(id);
    } catch (err) {
      console.error('[API] getEmployee failed', err);
      alert('Failed to load details.');
      return;
    }

    document.getElementById('emp-details').innerHTML = `
      <p><strong>ID:</strong> ${e.EmployeeID}</p>
      <p><strong>NIF:</strong> ${e.NIF}</p>
      <p><strong>Name:</strong> ${e.Name}</p>
      <p><strong>Date of Birth:</strong> ${e.DateOfBirth || '-'}</p>
      <p><strong>Job Title:</strong> ${e.JobTitle}</p>
      <p><strong>Department:</strong> ${e.Department || '-'}</p>
      <p><strong>Salary:</strong> ${e.Salary.toFixed(2)}</p>
      <p><strong>Hired:</strong> ${e.HireDate}</p>
      <p><strong>Email:</strong> ${e.Email || '-'}</p>
      <p><strong>Phone:</strong> ${e.PhoneNumber || '-'}</p>
      <p><strong>Record Label:</strong> ${e.RecordLabelName || '-'}</p>
    `;

    document.getElementById('edit-emp-btn').onclick = () => openForm('Edit Employee', e);
    document.getElementById('delete-emp-btn').onclick = async () => {
      if (!confirm(`Delete "${e.Name}"?`)) return;
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
    const obj = Object.fromEntries(new FormData(form));
    try {
      if (obj.EmployeeID) {
        await updateEmployee(obj.EmployeeID, obj);
      } else {
        await createEmployee(obj);
      }
      modal.classList.add('hidden');
      await fetchAndRender();
      backToList();
    } catch (err) {
      console.error('[API] save employee failed', err);
      alert('Failed to save.');
    }
  };

  const deb = debounce(fetchAndRender, 300);
  Object.values(filterElems).forEach(inp => { if (inp) inp.oninput = deb; });

  await populateLabelDropdown();
  await fetchAndRender();
  console.log('[employeeInit] done');
}

window.employeeInit = employeeInit;