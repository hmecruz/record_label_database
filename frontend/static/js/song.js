// frontend/static/js/song.js
// Load as an ES module: <script type="module" src="/static/js/song.js"></script>

import {
  listSongs,
  getSong,
  createSong,
  updateSong,
  deleteSong
} from './endpoints/song_api.js';

function debounce(fn, delay = 300) {
  let timer;
  return (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), delay);
  };
}

async function songInit() {
  console.log('[songInit] start');

  // Sections & controls
  const listSection    = document.getElementById('song-list-section');
  const detailsSection = document.getElementById('song-details-section');
  const modal          = document.getElementById('song-form-modal');
  const form           = document.getElementById('song-form');
  const addBtn         = document.getElementById('add-song-btn');
  const cancelBtn      = document.getElementById('song-cancel-btn');

  // Filter inputs
  const filters = {
    title:         document.getElementById('filter-title'),
    minDuration:   document.getElementById('filter-duration'),
    releaseDate:   document.getElementById('filter-release'),
    genre:         document.getElementById('filter-genre'),
    contributor:   document.getElementById('filter-contributor'),
    collaboration: document.getElementById('filter-collaboration')
  };

  // State
  let songs = [];

  // Render table rows
  function renderTable(data) {
    const tbody = document.querySelector('#song-list-table tbody');
    tbody.innerHTML = data.map(s => `
      <tr data-id="${s.SongID}">
        <td>${s.SongID}</td>
        <td>${s.Title}</td>
        <td>${s.Duration}</td>
        <td>${s.ReleaseDate}</td>
        <td>${s.Genres}</td>
        <td>${s.Contributors}</td>
        <td>${s.CollaborationName || ''}</td>
      </tr>
    `).join('');
    document.querySelectorAll('#song-list-table tbody tr')
      .forEach(row => row.onclick = () => showDetails(+row.dataset.id));
  }

  // Fetch from server with current filters
  let fetchId = 0;
  async function fetchAndRender() {
    const myFetch = ++fetchId;
    const params = {};
    if (filters.title.value)         params.title = filters.title.value;
    if (filters.minDuration.value)   params.minDuration = filters.minDuration.value;
    if (filters.releaseDate.value)   params.releaseDate = filters.releaseDate.value;
    if (filters.genre.value)         params.genre = filters.genre.value;
    if (filters.contributor.value)   params.contributor = filters.contributor.value;
    if (filters.collaboration.value) params.collaboration = filters.collaboration.value;

    try {
      const data = await listSongs(params);
      if (myFetch !== fetchId) return; // stale
      songs = data;
      renderTable(songs);
    } catch (err) {
      console.error('[API] listSongs failed', err);
      alert('Failed to load songs.');
    }
  }

  // Show details view
  async function showDetails(id) {
    listSection.classList.add('hidden');
    detailsSection.classList.remove('hidden');
    modal.classList.add('hidden');

    let s;
    try {
      s = await getSong(id);
    } catch (err) {
      console.error('[API] getSong failed', err);
      alert('Failed to load song details.');
      return;
    }

    document.getElementById('song-details').innerHTML = `
      <p><strong>ID:</strong> ${s.SongID}</p>
      <p><strong>Title:</strong> ${s.Title}</p>
      <p><strong>Duration:</strong> ${s.Duration} sec</p>
      <p><strong>Release Date:</strong> ${s.ReleaseDate}</p>
      <p><strong>Genres:</strong> ${s.Genres || '-'}</p>
      <p><strong>Contributors:</strong> ${s.Contributors || '-'}</p>
      <p><strong>Collaboration:</strong> ${s.CollaborationName || '-'}</p>
    `;

    document.getElementById('edit-song-btn').onclick = () => openForm('Edit Song', s);
    document.getElementById('delete-song-btn').onclick = async () => {
      if (!confirm(`Delete song "${s.Title}"?`)) return;
      try {
        await deleteSong(s.SongID);
        await fetchAndRender();
        backToList();
      } catch (err) {
        console.error('[API] deleteSong failed', err);
        alert('Failed to delete song.');
      }
    };
    document.getElementById('back-song-list-btn').onclick = backToList;
  }

  function backToList() {
    detailsSection.classList.add('hidden');
    listSection.classList.remove('hidden');
    modal.classList.add('hidden');
    renderTable(songs);
  }

  // Open Add/Edit form
  function openForm(title, s = {}) {
    document.getElementById('song-modal-title').textContent = title;
    form.reset();
    form.elements['SongID'].value              = s.SongID || '';
    form.elements['Title'].value               = s.Title || '';
    form.elements['Duration'].value            = s.Duration || '';
    form.elements['ReleaseDate'].value         = s.ReleaseDate || '';
    form.elements['Genres'].value              = s.Genres || '';
    form.elements['Contributors'].value        = s.Contributors || '';
    form.elements['CollaborationName'].value   = s.CollaborationName || '';
    modal.classList.remove('hidden');
  }

  // Add new song
  addBtn.onclick = e => { e.preventDefault(); openForm('Add Song'); };
  cancelBtn.onclick = e => { e.preventDefault(); modal.classList.add('hidden'); };

  // Form submit → create/update
  form.onsubmit = async e => {
    e.preventDefault();
    const data = Object.fromEntries(new FormData(form));
    try {
      if (data.SongID) {
        await updateSong(data.SongID, data);
      } else {
        await createSong(data);
      }
      modal.classList.add('hidden');
      await fetchAndRender();
      backToList();
    } catch (err) {
      console.error('[API] save song failed', err);
      alert('Failed to save song.');
    }
  };

  // Wire filters
  const deb = debounce(fetchAndRender, 300);
  Object.values(filters).forEach(inp => { if (inp) inp.oninput = deb; });

  // Initial load
  await fetchAndRender();
  console.log('[songInit] done');
}

// Expose for your main loader
window.songInit = songInit;
