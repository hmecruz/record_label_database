// frontend/static/js/record_label.js

import {
  listLabels,
  createLabel,
  updateLabel,
  deleteLabel
} from './endpoints/record_label_api.js';

async function record_labelInit() {
  console.log("[record_labelInit] Init");

  // Elements
  const listSection    = document.getElementById("label-list-section");
  const detailsSection = document.getElementById("label-details-section");
  const modal          = document.getElementById("label-form-modal");
  const form           = document.getElementById("label-form");
  const addBtn         = document.getElementById("add-label-btn");
  const cancelBtn      = document.getElementById("cancel-form-btn");

  // Filter inputs
  const filters = {
    name:     document.getElementById("filter-name"),
    location: document.getElementById("filter-location"),
    website:  document.getElementById("filter-website"),
    email:    document.getElementById("filter-email"),
    phone:    document.getElementById("filter-phone"),
  };

  // Ensure initial state
  listSection.classList.remove("hidden");
  detailsSection.classList.add("hidden");
  modal.classList.add("hidden");

  let labels = [];

  // Render table helper
  function renderTable(data) {
    console.log("[renderTable] rows:", data.length);
    const tbody = document.querySelector("#label-list-table tbody");
    tbody.innerHTML = data.map(l => `
      <tr data-id="${l.RecordLabelID}">
        <td>${l.RecordLabelID}</td>
        <td>${l.Name}</td>
        <td>${l.Location}</td>
        <td><a href="${l.Website}" target="_blank">${l.Website}</a></td>
        <td>${l.Email}</td>
        <td>${l.PhoneNumber}</td>
      </tr>
    `).join("");
    document.querySelectorAll("#label-list-table tbody tr").forEach(row => {
      row.onclick = () => showDetails(+row.dataset.id);
    });
  }

  // Fetch & render with current filter values
  async function fetchAndRender() {
    const params = {};
    for (let key in filters) {
      const val = filters[key].value.trim();
      if (val) params[key] = val;
    }
    try {
      labels = await listLabels(params);
      renderTable(labels);
    } catch (err) {
      console.error("[API] fetch failed", err);
      alert("Failed to fetch record labels.");
    }
  }

  // Attach filter handlers
  Object.values(filters).forEach(input => {
    if (!input) return;
    input.oninput = () => {
      // debounce if needed; for now call immediately
      fetchAndRender();
    };
  });

  // Show details
  function showDetails(id) {
    const label = labels.find(l => l.RecordLabelID === id);
    if (!label) return;
    listSection.classList.add("hidden");
    detailsSection.classList.remove("hidden");
    modal.classList.add("hidden");

    document.getElementById("label-details").innerHTML = `
      <p><strong>ID:</strong> ${label.RecordLabelID}</p>
      <p><strong>Name:</strong> ${label.Name}</p>
      <p><strong>Location:</strong> ${label.Location}</p>
      <p><strong>Website:</strong> <a href="${label.Website}" target="_blank">${label.Website}</a></p>
      <p><strong>Email:</strong> ${label.Email}</p>
      <p><strong>Phone:</strong> ${label.PhoneNumber}</p>
      <p><em>Removing this label will also remove its employees & collaborations.</em></p>
    `;

    document.getElementById("edit-label-btn").onclick = () => openForm("Edit Label", label);
    document.getElementById("delete-label-btn").onclick = async () => {
      if (!confirm(`Permanently remove "${label.Name}" and all related data?`)) return;
      try {
        await deleteLabel(label.RecordLabelID);
        await fetchAndRender();
        backToList();
      } catch (err) {
        console.error("[API] delete failed", err);
        alert("Failed to delete label.");
      }
    };
    document.getElementById("back-to-list-btn").onclick = backToList;
  }

  // Back to list
  function backToList() {
    listSection.classList.remove("hidden");
    detailsSection.classList.add("hidden");
    modal.classList.add("hidden");
    renderTable(labels);
  }

  // Open modal
  function openForm(title, label = null) {
    document.getElementById("modal-title").textContent = title;
    form.reset();
    form.elements["RecordLabelID"].value = label ? label.RecordLabelID : "";
    if (label) {
      Object.entries(label).forEach(([k, v]) => {
        if (form.elements[k]) form.elements[k].value = v;
      });
    }
    modal.classList.remove("hidden");
  }

  // Add New Label
  addBtn.onclick = e => {
    e.preventDefault();
    openForm("Add New Label");
  };

  // Cancel
  cancelBtn.onclick = e => {
    e.preventDefault();
    modal.classList.add("hidden");
  };

  // Form submit
  form.onsubmit = async e => {
    e.preventDefault();
    const obj = Object.fromEntries(new FormData(form));
    const isEdit = Boolean(obj.RecordLabelID);
    try {
      if (isEdit) {
        await updateLabel(obj.RecordLabelID, obj);
      } else {
        await createLabel(obj);
      }
      modal.classList.add("hidden");
      await fetchAndRender();
      backToList();
    } catch (err) {
      console.error("[API] save failed", err);
      alert("Failed to save label.");
    }
  };

  // Initial load
  await fetchAndRender();
  console.log("[record_labelInit] Done");
}

// Expose for your main loader
window.record_labelInit = record_labelInit;
