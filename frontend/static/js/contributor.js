// frontend/static/js/contributor.js

import {
  listContributors,
  getContributor,
  createContributor,
  updateContributor,
  deleteContributor
} from './endpoints/contributor_api.js';

function debounce(fn, delay = 300) {
  let timer;
  return (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), delay);
  };
}

async function contributorInit() {
  console.log('[contributorInit] start');

  // Sections & controls
  const listSection    = document.getElementById('contrib-list-section');
  const detailsSection = document.getElementById('contrib-details-section');
  const modal          = document.getElementById('contrib-form-modal');
  const form           = document.getElementById('contrib-form');
  const addBtn         = document.getElementById('add-contrib-btn');
  const cancelBtn      = document.getElementById('contrib-cancel-btn');

  // Filter inputs
  const filters = {
    name:  document.getElementById('filter-name'),
    roles: document.getElementById('filter-roles'),
    label: document.getElementById('filter-label'),
    email: document.getElementById('filter-email'),
    phone: document.getElementById('filter-phone'),
    nif:   document.getElementById('filter-nif')
  };

  let contributors = [];

  // Render table rows in the new order:
  // ID | Name | Roles | Record Label | Email | Phone | Date of Birth | NIF
  function renderTable(data) {
    const tbody = document.querySelector('#contrib-list-table tbody');
    tbody.innerHTML = data.map(c => `
      <tr data-id="${c.ContributorID}">
        <td>${c.ContributorID}</td>
        <td>${c.Name}</td>
        <td>${c.Roles}</td>
        <td>${c.RecordLabelName || ''}</td>
        <td>${c.Email || ''}</td>
        <td>${c.PhoneNumber || ''}</td>
        <td>${c.DateOfBirth || ''}</td>
        <td>${c.NIF}</td>
      </tr>
    `).join('');

    document.querySelectorAll('#contrib-list-table tbody tr')
      .forEach(row => row.onclick = () => showDetails(+row.dataset.id));
  }

  // Fetch from API, then apply client‐side Record Label + NIF filters
  let fetchId = 0;
  async function fetchAndRender() {
    const myFetch = ++fetchId;
    const params = {};
    if (filters.name.value)  params.name  = filters.name.value;
    if (filters.roles.value) params.role  = filters.roles.value;
    if (filters.email.value) params.email = filters.email.value;
    if (filters.phone.value) params.phone = filters.phone.value;
    // (We do not send `filter.label` or `filter.nif` to the SP—those get applied below.)

    try {
      let data = await listContributors(params);
      if (myFetch !== fetchId) return; // stale

      // Client-side filter by RecordLabelName
      const labelTerm = filters.label.value.trim().toLowerCase();
      if (labelTerm) {
        data = data.filter(c =>
          (c.RecordLabelName || '').toLowerCase().includes(labelTerm)
        );
      }
      // Client-side filter by NIF
      const nifTerm = filters.nif.value.trim().toLowerCase();
      if (nifTerm) {
        data = data.filter(c =>
          (c.NIF || '').toLowerCase().includes(nifTerm)
        );
      }

      contributors = data;
      renderTable(contributors);
    } catch (err) {
      console.error('[API] listContributors failed', err);
      alert('Failed to load contributors.');
    }
  }

  // Show details view (fetch fresh)
  async function showDetails(id) {
    listSection.classList.add('hidden');
    detailsSection.classList.remove('hidden');
    modal.classList.add('hidden');

    let c;
    try {
      c = await getContributor(id);
    } catch (err) {
      console.error('[API] getContributor failed', err);
      alert('Failed to load contributor details.');
      return;
    }

    document.getElementById('contrib-details').innerHTML = `
      <p><strong>ID:</strong> ${c.ContributorID}</p>
      <p><strong>NIF:</strong> ${c.NIF}</p>
      <p><strong>Name:</strong> ${c.Name}</p>
      <p><strong>Roles:</strong> ${c.Roles}</p>
      <p><strong>Record Label:</strong> ${c.RecordLabelName || '-'}</p>
      <p><strong>Email:</strong> ${c.Email || '-'}</p>
      <p><strong>Phone:</strong> ${c.PhoneNumber || '-'}</p>
      <p><strong>Date of Birth:</strong> ${c.DateOfBirth || '-'}</p>
    `;

    document.getElementById('edit-contrib-btn').onclick = () => openForm('Edit Contributor', c);
    document.getElementById('delete-contrib-btn').onclick = async () => {
      if (!confirm(`Delete contributor "${c.Name}"?`)) return;
      try {
        await deleteContributor(c.ContributorID);
        await fetchAndRender();
        backToList();
      } catch (err) {
        console.error('[API] deleteContributor failed', err);
        alert('Failed to delete contributor.');
      }
    };
    document.getElementById('back-contrib-list-btn').onclick = backToList;
  }

  function backToList() {
    detailsSection.classList.add('hidden');
    listSection.classList.remove('hidden');
    modal.classList.add('hidden');
    renderTable(contributors);
  }

  // Open Add/Edit modal. Required fields are now NIF, Name, Roles.
  function openForm(title, c = {}) {
    document.getElementById('contrib-modal-title').textContent = title;
    form.reset();

    // Hidden ContributorID (used for update)
    form.elements['ContributorID'].value = c.ContributorID || '';

    form.elements['NIF'].value           = c.NIF || '';
    form.elements['Name'].value          = c.Name || '';
    form.elements['DateOfBirth'].value   = c.DateOfBirth || '';
    form.elements['Email'].value         = c.Email || '';
    form.elements['PhoneNumber'].value   = c.PhoneNumber || '';
    form.elements['Roles'].value         = c.Roles || '';
    // No RecordLabelID field in the form anymore

    modal.classList.remove('hidden');
  }

  // Handlers
  addBtn.onclick = e => { e.preventDefault(); openForm('Add Contributor'); };
  cancelBtn.onclick = e => { e.preventDefault(); modal.classList.add('hidden'); };

  form.onsubmit = async e => {
    e.preventDefault();
    const data = Object.fromEntries(new FormData(form));

    // Validate required fields: NIF, Name, Roles
    if (!data.NIF.trim()) {
      alert("Field 'NIF' is required");
      return;
    }
    if (!data.Name.trim()) {
      alert("Field 'Name' is required");
      return;
    }
    if (!data.Roles.trim()) {
      alert("Field 'Roles' is required");
      return;
    }

    try {
      if (data.ContributorID) {
        // Update existing contributor
        await updateContributor(data.ContributorID, data);
      } else {
        // Create new contributor
        await createContributor(data);
      }
      modal.classList.add('hidden');
      await fetchAndRender();
      backToList();
    } catch (err) {
      console.error('[API] saveContributor failed', err);
      alert('Failed to save contributor.');
    }
  };

  // Wire up all filters with debounce
  const deb = debounce(fetchAndRender, 300);
  Object.values(filters).forEach(inp => { if (inp) inp.oninput = deb; });

  // Initial load
  await fetchAndRender();
  console.log('[contributorInit] done');
}

// expose to main loader
window.contributorInit = contributorInit;
