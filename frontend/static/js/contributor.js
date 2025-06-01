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
  const listSection       = document.getElementById('contrib-list-section');
  const detailsSection    = document.getElementById('contrib-details-section');
  const modal             = document.getElementById('contrib-form-modal');
  const form              = document.getElementById('contrib-form');
  const addBtn            = document.getElementById('add-contrib-btn');
  const cancelBtn         = document.getElementById('contrib-cancel-btn');

  // Conflict‐resolution modal elements:
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

  // (Re)render table
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

  // Fetch from API, sort by ContributorID, then apply client‐side filters
  let fetchId = 0;
  async function fetchAndRender() {
    const myFetch = ++fetchId;
    const params = {};
    if (filters.name.value)  params.name  = filters.name.value;
    if (filters.roles.value) params.role  = filters.roles.value;
    if (filters.email.value) params.email = filters.email.value;
    if (filters.phone.value) params.phone = filters.phone.value;

    try {
      let data = await listContributors(params);
      if (myFetch !== fetchId) return; // stale

      // Sort ascending by ContributorID so new ones appear at the bottom
      data.sort((a, b) => a.ContributorID - b.ContributorID);

      // Filter by Record Label (client‐side)
      const labelTerm = filters.label.value.trim().toLowerCase();
      if (labelTerm) {
        data = data.filter(c =>
          (c.RecordLabelName || '').toLowerCase().includes(labelTerm)
        );
      }
      // Filter by NIF (client‐side)
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

  // Show details view for a contributor
  async function showDetails(id) {
    listSection.classList.add('hidden');
    detailsSection.classList.remove('hidden');
    modal.classList.add('hidden');
    conflictModal.classList.add('hidden'); // ensure conflict modal is hidden

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
    conflictModal.classList.add('hidden');
    renderTable(contributors);
  }

  // Open “Add/Edit Contributor” modal
  function openForm(title, c = {}) {
    document.getElementById('contrib-modal-title').textContent = title;
    form.reset();
    conflictModal.classList.add('hidden');

    // If editing, pre‐fill fields
    form.elements['ContributorID'].value = c.ContributorID || '';
    form.elements['NIF'].value           = c.NIF || '';
    form.elements['Name'].value          = c.Name || '';
    form.elements['DateOfBirth'].value   = c.DateOfBirth || '';
    form.elements['Email'].value         = c.Email || '';
    form.elements['PhoneNumber'].value   = c.PhoneNumber || '';
    form.elements['Roles'].value         = c.Roles || '';

    modal.classList.remove('hidden');
  }

  // Handlers for open/cancel Add/Edit
  addBtn.onclick = e => { e.preventDefault(); openForm('Add Contributor'); };
  cancelBtn.onclick = e => { e.preventDefault(); modal.classList.add('hidden'); };

  // Form submission logic
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
      // 1) If editing, just call updateContributor
      if (data.ContributorID) {
        await updateContributor(data.ContributorID, data);
        modal.classList.add('hidden');
        await fetchAndRender();
        backToList();
        return;
      }

      // 2) Otherwise, attempt to create a new Contributor
      try {
        await createContributor(data);
        modal.classList.add('hidden');
        await fetchAndRender();
        backToList();
      } catch (res) {
        // If the server returned HTTP 409 Conflict, pop up our “Conflict” modal
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

          // Populate the conflict modal fields
          conflictNifSpan.textContent   = existingPerson.NIF;
          existingNameSpan.textContent  = existingPerson.Name;
          existingDobSpan.textContent   = existingPerson.DateOfBirth || '(none)';
          existingEmailSpan.textContent = existingPerson.Email || '(none)';
          existingPhoneSpan.textContent = existingPerson.PhoneNumber || '(none)';

          incomingNameSpan.textContent  = incomingData.Name;
          incomingDobSpan.textContent   = incomingData.DateOfBirth || '(none)';
          incomingEmailSpan.textContent = incomingData.Email || '(none)';
          incomingPhoneSpan.textContent = incomingData.PhoneNumber || '(none)';

          // Show the modal
          conflictModal.classList.remove('hidden');
          modal.classList.add('hidden');

          // ---- Button handlers inside the conflict modal ----

          // Choice A: Keep existing Person, just add Contributor under that NIF
          keepBtn.onclick = async () => {
            conflictModal.classList.add('hidden');
            try {
              await createContributor(incomingData, '?useOldPerson=true');
              await fetchAndRender();
              backToList();
            } catch (err2) {
              console.error('[API] keep-old-person failed', err2);
              alert("Failed to add Contributor under existing Person.");
            }
          };

          // Choice B: Overwrite Person fields, then add Contributor under that NIF
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

              // 2) Now add Contributor under that same NIF
              await createContributor(incomingData, '?useOldPerson=true');
              conflictModal.classList.add('hidden');
              await fetchAndRender();
              backToList();
            } catch (err3) {
              console.error('[API] overwrite failed', err3);
              alert("Failed to overwrite Person or add Contributor.");
            }
          };

          // Choice C: Cancel
          conflictCancelBtn.onclick = () => {
            conflictModal.classList.add('hidden');
          };
        }
        else {
          // Some other HTTP error
          console.error('[API] createContributor failed', res);
          alert('Failed to save contributor.');
        }
      }
    } catch (err) {
      console.error('[API] saveContributor failed (unexpected)', err);
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

// Expose for main loader
window.contributorInit = contributorInit;
