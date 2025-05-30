// frontend/static/js/record_label.js

function record_labelInit() {
  console.log("record_labelInit running");

  // Grab our elements
  const listSection    = document.getElementById("label-list-section");
  const detailsSection = document.getElementById("label-details-section");
  const modal          = document.getElementById("label-form-modal");
  const form           = document.getElementById("label-form");
  const addBtn         = document.getElementById("add-label-btn");
  const cancelBtn      = document.getElementById("cancel-form-btn");

  // Ensure all sections start in the correct state
  listSection.classList.remove("hidden");
  detailsSection.classList.add("hidden");
  modal.classList.add("hidden");

  // Hardcoded sample data
  let labels = [
    { RecordLabelID: 1, Name: "Universal Music", Location: "Los Angeles", Website: "https://universal.com", Email: "contact@universal.com", PhoneNumber: "123-456-7890" },
    { RecordLabelID: 2, Name: "Sony Music",      Location: "New York",   Website: "https://sonymusic.com", Email: "info@sonymusic.com",    PhoneNumber: "234-567-8901" },
    { RecordLabelID: 3, Name: "Warner Music",    Location: "London",     Website: "https://warnermusic.com", Email: "hello@warnermusic.com",PhoneNumber: "345-678-9012" }
  ];

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

    // Attach click to each row
    document.querySelectorAll("#label-list-table tbody tr").forEach(row => {
      row.addEventListener("click", () => showDetails(+row.dataset.id));
    });
  }

  // Filtering
  ["name", "location", "website", "email"].forEach(key => {
    const input = document.getElementById(`filter-${key}`);
    if (!input) return;
    input.addEventListener("input", e => {
      const term = e.target.value.toLowerCase();
      renderTable(
        labels.filter(l =>
          String(l[key.charAt(0).toUpperCase() + key.slice(1)])
            .toLowerCase()
            .includes(term)
        )
      );
    });
  });

  // Show details view
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
    `;

    document.getElementById("edit-label-btn").onclick = () => openForm("Edit Label", label);
    document.getElementById("delete-label-btn").onclick = () => {
      if (confirm(`Delete "${label.Name}"?`)) {
        labels = labels.filter(l => l.RecordLabelID !== id);
        backToList();
      }
    };
    document.getElementById("back-to-list-btn").onclick = backToList;
  }

  // Back to list
  function backToList() {
    detailsSection.classList.add("hidden");
    listSection.classList.remove("hidden");
    modal.classList.add("hidden");
    renderTable(labels);
  }

  // Open modal for add/edit
  function openForm(title, label = null) {
    document.getElementById("modal-title").textContent = title;
    form.reset();
    if (label) {
      Object.entries(label).forEach(([k, v]) => {
        if (form.elements[k]) form.elements[k].value = v;
      });
    }
    modal.classList.remove("hidden");
  }

  // Add New Label button
  addBtn.onclick = () => openForm("Add New Label");

  // Cancel button
  cancelBtn.onclick = () => {
    modal.classList.add("hidden");
  };

  // Form submission
  form.onsubmit = e => {
    e.preventDefault();
    const fd = new FormData(form);
    const obj = {};
    fd.forEach((v, k) => obj[k] = v);

    if (obj.RecordLabelID) {
      labels = labels.map(l => l.RecordLabelID == obj.RecordLabelID ? { ...l, ...obj } : l);
    } else {
      obj.RecordLabelID = Math.max(0, ...labels.map(l => l.RecordLabelID)) + 1;
      labels.push(obj);
    }

    modal.classList.add("hidden");
    backToList();
  };

  // Initial table population
  renderTable(labels);
}

// Expose init for loader
window.record_labelInit = record_labelInit;
