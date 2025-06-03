import {
  listLabels,
  getLabel,
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

  // Debounce helper
  function debounce(fn, delay = 300) {
    let timer;
    return (...args) => {
      clearTimeout(timer);
      timer = setTimeout(() => fn(...args), delay);
    };
  }

  // Fetch & render with current filter values
  let currentFetchId = 0;
  async function fetchAndRender() {
    const fetchId = ++currentFetchId;
    const params = {};
    for (let key in filters) {
      const val = filters[key].value.trim();
      if (val) params[key] = val;
    }
    try {
      const data = await listLabels(params);
      // ignore out-of-order responses
      if (fetchId !== currentFetchId) return;
      labels = data;
      renderTable(labels);
    } catch (err) {
      console.error("[API] fetch failed", err);
      alert("Failed to fetch record labels.");
    }
  }

  // Attach debounced filter handlers
  const debouncedFetch = debounce(fetchAndRender, 300);
  Object.values(filters).forEach(input => {
    if (!input) return;
    input.oninput = debouncedFetch;
  });

  // Show details (now fetching fresh data via getLabel)
  async function showDetails(id) {
    listSection.classList.add("hidden");
    detailsSection.classList.remove("hidden");
    modal.classList.add("hidden");

    let label;
    try {
      label = await getLabel(id);
    } catch (err) {
      console.error("[API] getLabel failed", err);
      alert("Failed to load label details.");
      return;
    }

    document.getElementById("label-details").innerHTML = `
      <p><strong>ID:</strong> ${label.RecordLabelID}</p>
      <p><strong>Name:</strong> ${label.Name}</p>
      <p><strong>Location:</strong> ${label.Location}</p>
      <p><strong>Website:</strong> <a href="${label.Website}" target="_blank">${label.Website}</a></p>
      <p><strong>Email:</strong> ${label.Email}</p>
      <p><strong>Phone:</strong> ${label.PhoneNumber}</p>
      <p><em>Deleting this label will also remove its employees & collaboration links if any exist.</em></p>
    `;

    document.getElementById("edit-label-btn").onclick = () => openForm("Edit Label", label);
    document.getElementById("delete-label-btn").onclick = async () => {
      // First attempt: try a normal delete (cascade=false). If dependencies exist, server returns 409 + JSON counts.
      if (!confirm(`Permanently remove "${label.Name}"?`)) return;

      try {
        // Attempt non-cascade delete
        await deleteLabel(label.RecordLabelID, { cascade: false });
        // If successful, just refresh:
        await fetchAndRender();
        backToList();

      } catch (res) {
        // If `res` is not a Response object, rethrow
        if (!(res instanceof Response)) {
          console.error("[API] delete failed", res);
          alert("Failed to delete label.");
          return;
        }

        if (res.status === 409) {
          // The server responded with HTTP 409 Conflict and a JSON payload { employeeCount, collaborationCount }
          let info;
          try {
            info = await res.json();
          } catch (parseErr) {
            console.error("Failed to parse 409 JSON", parseErr);
            alert("Cannot delete—unknown server response.");
            return;
          }
          const { employeeCount, collaborationCount } = info;
          const msg =
            `This label is still used by ${employeeCount} employee${employeeCount===1?'':'s'} ` +
            `and ${collaborationCount} collaboration link${collaborationCount===1?'':'s'}.` +
            `\n\nPress OK to delete the label (and automatically remove those employees and collaboration‐links),\n` +
            `or Cancel to keep everything.`;
          if (confirm(msg)) {
            try {
              await deleteLabel(label.RecordLabelID, { cascade: true });
              await fetchAndRender();
              backToList();
            } catch (err2) {
              console.error("[API] cascade delete failed", err2);
              alert("Failed to force‐delete label and its dependencies.");
            }
          }
        } else {
          // Some other HTTP error (e.g. 404, 500, etc.)
          console.error("[API] delete failed", res);
          alert("Failed to delete label.");
        }
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
