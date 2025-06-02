import {
  listCollaborations,
  getCollaboration,
  createCollaboration,
  updateCollaboration,
  deleteCollaboration
} from './endpoints/collaboration_api.js';

import {
  listSongs
} from './endpoints/song_api.js'; // to populate the Song dropdown

function debounce(fn, delay = 300) {
  let timer;
  return (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), delay);
  };
}

async function collaborationInit() {
  console.log("[collaborationInit] start");

  // Sections & controls
  const listSection    = document.getElementById('collab-list-section');
  const detailsSection = document.getElementById('collab-details-section');
  const modal          = document.getElementById('collab-form-modal');
  const form           = document.getElementById('collab-form');
  const addBtn         = document.getElementById('add-collab-btn');
  const cancelBtn      = document.getElementById('collab-cancel-btn');

  // Filter inputs
  const filters = {
    name:         document.getElementById('filter-name'),
    start:        document.getElementById('filter-start'),
    end:          document.getElementById('filter-end'),
    song:         document.getElementById('filter-song'),
    labels:       document.getElementById('filter-labels'),
    contributors: document.getElementById('filter-contributors')
  };

  // “Song” dropdown inside the form (must exist in HTML)
  const songDropdown = document.getElementById('song-dropdown');

  // State arrays
  let collaborations = [];
  let songsList = [];

  // Populate the <select> of existing songs
  async function populateSongDropdown() {
    try {
      const allSongs = await listSongs({});
      songsList = allSongs;
      // Clear existing options (except placeholder)
      songDropdown.innerHTML = `
        <option value="" disabled selected>Select a song</option>
      `;
      allSongs.forEach(s => {
        const opt = document.createElement('option');
        opt.value = s.SongID;
        opt.textContent = s.Title;
        songDropdown.appendChild(opt);
      });
    } catch (err) {
      console.error('[API] listSongs failed while populating dropdown', err);
      alert('Failed to load songs for dropdown.');
    }
  }

  // Render collaborations table
  function renderTable(data) {
    const tbody = document.querySelector('#collab-list-table tbody');
    tbody.innerHTML = data.map(c => `
      <tr data-id="${c.CollaborationID}">
        <td>${c.CollaborationID}</td>
        <td>${c.CollaborationName}</td>
        <td>${c.StartDate}</td>
        <td>${c.EndDate || ''}</td>
        <td>${c.SongTitle || ''}</td>
        <td>${c.RecordLabels.join(', ')}</td>
        <td>${c.Contributors.join(', ')}</td>
        <td>${c.Description || ''}</td>
      </tr>
    `).join('');

    document.querySelectorAll('#collab-list-table tbody tr')
      .forEach(row => row.onclick = () => showDetails(+row.dataset.id));
  }

  // Fetch & render (with current filters)
  let fetchId = 0;
  async function fetchAndRender() {
    const myFetch = ++fetchId;
    const params = {};
    if (filters.name.value)         params.name = filters.name.value;
    if (filters.start.value)        params.start = filters.start.value;
    if (filters.end.value)          params.end = filters.end.value;
    if (filters.song.value)         params.song = filters.song.value;
    if (filters.labels.value)       params.labels = filters.labels.value;
    if (filters.contributors.value) params.contributors = filters.contributors.value;

    try {
      const data = await listCollaborations(params);
      console.log('[collabInit] listCollaborations returned:', data);
      if (myFetch !== fetchId) return; // stale response
      collaborations = data;
      renderTable(collaborations);
    } catch (err) {
      console.error('[API] listCollaborations failed', err);
      alert('Failed to load collaborations.');
    }
  }

  // Show details for one collaboration
  async function showDetails(id) {
    listSection.classList.add('hidden');
    detailsSection.classList.remove('hidden');
    modal.classList.add('hidden');

    let c;
    try {
      c = await getCollaboration(id);
      console.log('[collabInit] getCollaboration returned:', c);
    } catch (err) {
      console.error('[API] getCollaboration failed', err);
      alert('Failed to load collaboration details.');
      return;
    }

    const detailsDiv = document.getElementById('collab-details');
    detailsDiv.innerHTML = `
      <p><strong>ID:</strong> ${c.CollaborationID}</p>
      <p><strong>Name:</strong> ${c.CollaborationName}</p>
      <p><strong>Start Date:</strong> ${c.StartDate}</p>
      <p><strong>End Date:</strong> ${c.EndDate || '-'}</p>
      <p><strong>Song:</strong> ${c.SongTitle || '-'}</p>
      <p><strong>Record Labels:</strong> ${c.RecordLabels.join(', ') || '-'}</p>
      <p><strong>Contributors:</strong> ${c.Contributors.join(', ') || '-'}</p>
      <p><strong>Description:</strong> ${c.Description || '-'}</p>
    `;

    document.getElementById('edit-collab-btn').onclick = () => openForm('Edit Collaboration', c);
    document.getElementById('delete-collab-btn').onclick = async () => {
      if (!confirm(`Delete collaboration "${c.CollaborationName}"?`)) return;
      try {
        await deleteCollaboration(c.CollaborationID);
        await fetchAndRender();
        backToList();
      } catch (err) {
        console.error('[API] deleteCollaboration failed', err);
        alert('Failed to delete collaboration.');
      }
    };
    document.getElementById('back-collab-list-btn').onclick = backToList;
  }

  function backToList() {
    detailsSection.classList.add('hidden');
    listSection.classList.remove('hidden');
    modal.classList.add('hidden');
    renderTable(collaborations);
  }

  // Open Add/Edit form
  function openForm(title, c = {}) {
    document.getElementById('collab-modal-title').textContent = title;
    form.reset();

    form.elements['CollaborationID'].value   = c.CollaborationID || '';
    form.elements['CollaborationName'].value = c.CollaborationName || '';
    form.elements['StartDate'].value         = c.StartDate || '';
    form.elements['EndDate'].value           = c.EndDate || '';
    form.elements['Description'].value       = c.Description || '';
    // Select the matching song in the dropdown
    form.elements['SongID'].value            = c.SongID || '';

    // Turn arrays back into comma‐separated strings:
    form.elements['RecordLabels'].value      = c.RecordLabels.join(', ') || '';
    form.elements['Contributors'].value      = c.Contributors.join(', ') || '';

    modal.classList.remove('hidden');
  }

  // “Add Collaboration” button
  addBtn.onclick = e => {
    e.preventDefault();
    openForm('Add Collaboration');
  };
  cancelBtn.onclick = e => {
    e.preventDefault();
    modal.classList.add('hidden');
  };

  // Form submission: create or update
  form.onsubmit = async e => {
    e.preventDefault();
    const data = Object.fromEntries(new FormData(form));

    // Build payload
    const payload = {
      CollaborationName: data.CollaborationName,
      StartDate:         data.StartDate,
      EndDate:           data.EndDate || null,
      Description:       data.Description || null,
      SongID:            data.SongID ? parseInt(data.SongID, 10) : null,
      RecordLabels:      data.RecordLabels || null,    // comma-separated names
      Contributors:      data.Contributors || null     // comma-separated Person_NIFs
    };

    try {
      if (data.CollaborationID) {
        await updateCollaboration(parseInt(data.CollaborationID, 10), payload);
      } else {
        await createCollaboration(payload);
      }
      modal.classList.add('hidden');
      await fetchAndRender();
      backToList();
    } catch (err) {
      console.error('[API] saveCollaboration failed', err);
      alert('Failed to save collaboration.');
    }
  };

  // Wire up all filters with debounce
  const deb = debounce(fetchAndRender, 300);
  Object.values(filters).forEach(inp => { if (inp) inp.oninput = deb; });

  // Initial load: populate song dropdown, then fetch collaborations
  await populateSongDropdown();
  await fetchAndRender();
  console.log("[collaborationInit] done");
}

// Expose to main loader
window.collaborationInit = collaborationInit;
