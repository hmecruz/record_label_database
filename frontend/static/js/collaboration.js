import {
  listCollaborations,
  getCollaboration,
  createCollaboration,
  updateCollaboration,
  deleteCollaboration
} from './endpoints/collaboration_api.js';

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
  const listSection     = document.getElementById("collab-list-section");
  const detailsSection  = document.getElementById("collab-details-section");
  const modal           = document.getElementById("collab-form-modal");
  const form            = document.getElementById("collab-form");
  const addBtn          = document.getElementById("add-collab-btn");
  const cancelBtn       = document.getElementById("collab-cancel-btn");

  // Filter inputs
  const filters = {
    name:         document.getElementById("filter-name"),
    start:        document.getElementById("filter-start"),
    end:          document.getElementById("filter-end"),
    song:         document.getElementById("filter-song"),
    labels:       document.getElementById("filter-labels"),
    contributors: document.getElementById("filter-contributors")
  };

  let collabs = [];

  // Render list table
  function renderTable(data) {
    const tbody = document.querySelector("#collab-list-table tbody");
    tbody.innerHTML = data.map(c => `
      <tr data-id="${c.CollaborationID}">
        <td>${c.CollaborationID}</td>
        <td>${c.CollaborationName}</td>
        <td>${c.StartDate}</td>
        <td>${c.EndDate || ""}</td>
        <td>${c.SongTitle || ""}</td>
        <td>${c.RecordLabels.join(", ")}</td>
        <td>${c.Contributors.join(", ")}</td>
        <td>${c.Description || ""}</td>
      </tr>
    `).join("");
    document.querySelectorAll("#collab-list-table tbody tr")
      .forEach(row => row.onclick = () => showDetails(+row.dataset.id));
  }

  // Fetch & render with current filters
  let fetchCounter = 0;
  async function fetchAndRender() {
    const myFetch = ++fetchCounter;
    const params = {};
    if (filters.name.value)         params.name         = filters.name.value;
    if (filters.start.value)        params.start        = filters.start.value;
    if (filters.end.value)          params.end          = filters.end.value;
    if (filters.song.value)         params.song         = filters.song.value;
    if (filters.labels.value)       params.labels       = filters.labels.value;
    if (filters.contributors.value) params.contributors = filters.contributors.value;

    try {
      const data = await listCollaborations(params);
      if (myFetch !== fetchCounter) return; // stale
      collabs = data;
      renderTable(collabs);
    } catch (err) {
      console.error("[API] listCollaborations failed", err);
      alert("Failed to load collaborations.");
    }
  }

  // Show details view
  async function showDetails(id) {
    listSection.classList.add("hidden");
    detailsSection.classList.remove("hidden");
    modal.classList.add("hidden");

    let c;
    try {
      c = await getCollaboration(id);
    } catch (err) {
      console.error("[API] getCollaboration failed", err);
      alert("Failed to load collaboration details.");
      backToList();
      return;
    }

    document.getElementById("collab-details").innerHTML = `
      <p><strong>ID:</strong> ${c.CollaborationID}</p>
      <p><strong>Name:</strong> ${c.CollaborationName}</p>
      <p><strong>Start Date:</strong> ${c.StartDate}</p>
      <p><strong>End Date:</strong> ${c.EndDate || "-"}</p>
      <p><strong>Song Title:</strong> ${c.SongTitle || "-"}</p>
      <p><strong>Record Labels:</strong> ${c.RecordLabels.join(", ")}</p>
      <p><strong>Contributors:</strong> ${c.Contributors.join(", ")}</p>
      <p><strong>Description:</strong> ${c.Description || "-"}</p>
    `;

    document.getElementById("edit-collab-btn").onclick = () => openForm("Edit Collaboration", c);
    document.getElementById("delete-collab-btn").onclick = async () => {
      if (!confirm(`Delete collaboration "${c.CollaborationName}"?`)) return;
      try {
        await deleteCollaboration(c.CollaborationID);
        await fetchAndRender();
        backToList();
      } catch (err) {
        console.error("[API] deleteCollaboration failed", err);
        alert("Failed to delete collaboration.");
      }
    };
    document.getElementById("back-collab-list-btn").onclick = backToList;
  }

  function backToList() {
    detailsSection.classList.add("hidden");
    listSection.classList.remove("hidden");
    modal.classList.add("hidden");
    renderTable(collabs);
  }

  // Open add/edit form
  function openForm(title, c = {}) {
    document.getElementById("collab-modal-title").textContent = title;
    form.reset();
    form.elements["CollaborationID"].value    = c.CollaborationID || "";
    form.elements["CollaborationName"].value  = c.CollaborationName || "";
    form.elements["StartDate"].value          = c.StartDate || "";
    form.elements["EndDate"].value            = c.EndDate || "";
    form.elements["SongTitle"].value          = c.SongTitle || "";
    form.elements["RecordLabels"].value       = (c.RecordLabels || []).join(", ");
    form.elements["Contributors"].value       = (c.Contributors  || []).join(", ");
    form.elements["Description"].value        = c.Description || "";
    modal.classList.remove("hidden");
  }

  // Handlers
  addBtn.onclick = e => { e.preventDefault(); openForm("Add Collaboration"); };
  cancelBtn.onclick = e => { e.preventDefault(); modal.classList.add("hidden"); };

  form.onsubmit = async e => {
    e.preventDefault();
    const data = Object.fromEntries(new FormData(form));
    // normalize arrays
    data.RecordLabels  = data.RecordLabels  ? data.RecordLabels.split(",").map(s=>s.trim()).filter(Boolean) : [];
    data.Contributors  = data.Contributors  ? data.Contributors.split(",").map(s=>s.trim()).filter(Boolean) : [];

    try {
      if (data.CollaborationID) {
        await updateCollaboration(data.CollaborationID, data);
      } else {
        await createCollaboration(data);
      }
      modal.classList.add("hidden");
      await fetchAndRender();
      backToList();
    } catch (err) {
      console.error("[API] save collaboration failed", err);
      alert("Failed to save collaboration.");
    }
  };

  // Wire filters with debounce
  const debouncedFetch = debounce(fetchAndRender, 300);
  Object.values(filters).forEach(inp => { if (inp) inp.oninput = debouncedFetch; });

  // Initial load
  await fetchAndRender();
  console.log("[collaborationInit] done");
}

// Expose to main loader
window.collaborationInit = collaborationInit;
