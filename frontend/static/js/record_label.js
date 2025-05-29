let labels = [];      // in-memory store
let selectedLabel = null;

function record_labelInit() {
  // Cache DOM
  const tbody = document.querySelector("#label-list-table tbody");
  const filterName = document.getElementById("filter-name");
  const filterLoc = document.getElementById("filter-location");
  const filterEmail = document.getElementById("filter-email");
  const applyBtn = document.getElementById("apply-filters");
  const clearBtn = document.getElementById("clear-filters");

  const detailsSection = document.getElementById("label-details-section");
  const detailsDiv = document.getElementById("label-details");
  const empTbody = document.querySelector("#label-employees-table tbody");
  const collTbody = document.querySelector("#label-collabs-table tbody");
  const editBtn = document.getElementById("edit-label");
  const deleteBtn = document.getElementById("delete-label");
  const editForm = document.getElementById("edit-label-form");
  const cancelEdit = document.getElementById("cancel-edit");
  const addForm = document.getElementById("add-label-form");

  // Fetch initial data (replace with real API calls)
  fetchLabels().then(data => {
    labels = data;
    renderList(labels);
  });

  // Filters
  applyBtn.onclick = () => {
    const filtered = labels.filter(l =>
      l.Name.toLowerCase().includes(filterName.value.toLowerCase()) &&
      l.Location.toLowerCase().includes(filterLoc.value.toLowerCase()) &&
      l.Email.toLowerCase().includes(filterEmail.value.toLowerCase())
    );
    renderList(filtered);
  };
  clearBtn.onclick = () => {
    filterName.value = filterLoc.value = filterEmail.value = "";
    renderList(labels);
  };

  function renderList(list) {
    tbody.innerHTML = list.map(l => `
      <tr>
        <td>${l.RecordLabelID}</td>
        <td>${l.Name}</td>
        <td>${l.Location||""}</td>
        <td>${l.Email||""}</td>
        <td>${l.PhoneNumber||""}</td>
        <td><button data-id="${l.RecordLabelID}" class="view-btn">View</button></td>
      </tr>
    `).join("");
    document.querySelectorAll(".view-btn").forEach(btn =>
      btn.onclick = () => showDetails(btn.dataset.id)
    );
  }

  function showDetails(id) {
    selectedLabel = labels.find(l => l.RecordLabelID == id);
    // Render contact info
    detailsDiv.innerHTML = `
      <p><strong>${selectedLabel.Name}</strong></p>
      <p>Location: ${selectedLabel.Location||"—"}</p>
      <p>Website: ${selectedLabel.Website||"—"}</p>
      <p>Email: ${selectedLabel.Email||"—"}</p>
      <p>Phone: ${selectedLabel.PhoneNumber||"—"}</p>
    `;
    // Fetch and render employees & collabs
    fetchLabelEmployees(id).then(emps => {
      empTbody.innerHTML = emps.map(e => `
        <tr>
          <td>${e.EmployeeID}</td>
          <td>${e.Name}</td>
          <td>${e.JobTitle}</td>
          <td>${e.Department}</td>
          <td>${e.HireDate}</td>
        </tr>
      `).join("");
    });
    fetchLabelCollaborations(id).then(cols => {
      collTbody.innerHTML = cols.map(c => `
        <tr>
          <td>${c.CollaborationID}</td>
          <td>${c.CollaborationName}</td>
          <td>${c.StartDate}</td>
          <td>${c.EndDate||""}</td>
        </tr>
      `).join("");
    });
    detailsSection.classList.remove("hidden");
    editForm.classList.add("hidden");
  }

  // Edit
  editBtn.onclick = () => {
    editForm.classList.remove("hidden");
    document.getElementById("edit-name").value = selectedLabel.Name;
    document.getElementById("edit-location").value = selectedLabel.Location||"";
    document.getElementById("edit-website").value = selectedLabel.Website||"";
    document.getElementById("edit-email").value = selectedLabel.Email||"";
    document.getElementById("edit-phone").value = selectedLabel.PhoneNumber||"";
  };
  cancelEdit.onclick = () => editForm.classList.add("hidden");
  editForm.onsubmit = e => {
    e.preventDefault();
    // Gather updated values
    const updated = {
      ...selectedLabel,
      Location: document.getElementById("edit-location").value,
      Website: document.getElementById("edit-website").value,
      Email: document.getElementById("edit-email").value,
      PhoneNumber: document.getElementById("edit-phone").value,
    };
    // Call API to update then refresh list
    updateLabel(updated).then(() => {
      Object.assign(selectedLabel, updated);
      renderList(labels);
      showDetails(updated.RecordLabelID);
    });
  };

  // Delete
  deleteBtn.onclick = () => {
    if (!confirm("Delete this label? This will remove employees & collaborations.")) return;
    deleteLabel(selectedLabel.RecordLabelID).then(() => {
      labels = labels.filter(l => l.RecordLabelID !== selectedLabel.RecordLabelID);
      renderList(labels);
      detailsSection.classList.add("hidden");
    });
  };

  // Add New
  addForm.onsubmit = e => {
    e.preventDefault();
    const newLabel = {
      Name: document.getElementById("new-name").value,
      Location: document.getElementById("new-location").value,
      Website: document.getElementById("new-website").value,
      Email: document.getElementById("new-email").value,
      PhoneNumber: document.getElementById("new-phone").value,
    };
    createLabel(newLabel).then(created => {
      labels.push(created);
      renderList(labels);
      addForm.reset();
    });
  };
}

// --- Mock API functions (replace with real AJAX calls) ---
function fetchLabels() {
  return Promise.resolve([
    { RecordLabelID:1,Name:"Harmony Records",Location:"Los Angeles, USA",Website:"https://harmonyrecords.com",Email:"contact@harmonyrecords.com",PhoneNumber:"+1-310-555-1234" },
    { RecordLabelID:2,Name:"Nova Tunes",Location:"London, UK",Website:"https://novatunes.co.uk",Email:"info@novatunes.co.uk",PhoneNumber:"+44-20-7946-1111" },
    { RecordLabelID:3,Name:"Sunset Beats",Location:"Sydney, Australia",Website:"https://sunsetbeats.au",Email:"support@sunsetbeats.au",PhoneNumber:"+61-2-8000-1234" }
  ]);
}
function fetchLabelEmployees(labelId) {
  // should call vw_LabelEmployeeList? Mock:
  return Promise.resolve([
    { EmployeeID: 1, Name:"Alice Johnson", JobTitle:"Marketing Manager", Department:"Marketing", HireDate:"2023-01-15" }
  ]);
}
function fetchLabelCollaborations(labelId) {
  // mock:
  return Promise.resolve([
    { CollaborationID:1,CollaborationName:"Summer Vibes Project",StartDate:"2024-05-01",EndDate:"2024-06-15" }
  ]);
}
function createLabel(data) {
  // mock assign ID
  data.RecordLabelID = Math.floor(Math.random()*1000) + 4;
  return Promise.resolve(data);
}
function updateLabel(data) {
  return Promise.resolve();
}
function deleteLabel(id) {
  return Promise.resolve();
}
