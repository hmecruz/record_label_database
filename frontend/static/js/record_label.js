// frontend/static/js/record_label.js

function record_labelInit() {
  console.log("[record_labelInit] Init");

  // Elements
  const listSection    = document.getElementById("label-list-section");
  const detailsSection = document.getElementById("label-details-section");
  const modal          = document.getElementById("label-form-modal");
  const form           = document.getElementById("label-form");
  const addBtn         = document.getElementById("add-label-btn");
  const cancelBtn      = document.getElementById("cancel-form-btn");

  // Ensure initial state
  listSection.classList.remove("hidden");
  detailsSection.classList.add("hidden");
  modal.classList.add("hidden");

  // Sample data
  let labels = [
    { RecordLabelID: 1, Name: "Universal Music", Location: "Los Angeles", Website: "https://universal.com", Email: "contact@universal.com", PhoneNumber: "123-456-7890" },
    { RecordLabelID: 2, Name: "Sony Music",      Location: "New York",   Website: "https://sonymusic.com", Email: "info@sonymusic.com",    PhoneNumber: "234-567-8901" },
    { RecordLabelID: 3, Name: "Warner Music",    Location: "London",     Website: "https://warnermusic.com", Email: "hello@warnermusic.com",PhoneNumber: "345-678-9012" }
  ];

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
      row.onclick = () => {
        console.log("[row] click id=", row.dataset.id);
        showDetails(+row.dataset.id);
      };
    });
  }

  // Filters: name, location, website, email, phone
  ["name","location","website","email","phone"].forEach(key => {
    const input = document.getElementById(`filter-${key}`);
    if (!input) return console.warn("[filter] no input for", key);
    input.oninput = e => {
      const term = e.target.value.toLowerCase();
      console.log("[filter]", key, term);
      renderTable(
        labels.filter(l => {
          const field = key === "phone" ? l.PhoneNumber : l[key.charAt(0).toUpperCase()+key.slice(1)];
          return String(field).toLowerCase().includes(term);
        })
      );
    };
  });

  // Show details
  function showDetails(id) {
    const label = labels.find(l => l.RecordLabelID===id);
    if (!label) return;
    console.log("[showDetails]", label);

    listSection.classList.add("hidden");
    detailsSection.classList.remove("hidden");
    modal.classList.add("hidden");

    // Populate details
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
    document.getElementById("delete-label-btn").onclick = () => {
      console.log("[delete] clicked", label.Name);
      if (confirm(`Permanently remove "${label.Name}" and all related data?`)) {
        labels = labels.filter(l => l.RecordLabelID!==id);
        backToList();
      }
    };
    document.getElementById("back-to-list-btn").onclick = () => backToList();
  }

  // Back to list
  function backToList() {
    console.log("[backToList]");
    detailsSection.classList.add("hidden");
    listSection.classList.remove("hidden");
    modal.classList.add("hidden");
    renderTable(labels);
  }

  // Open modal
  function openForm(title, label=null) {
    console.log("[openForm]", title, label);
    document.getElementById("modal-title").textContent = title;
    form.reset();

    // Populate hidden ID (will be empty string for “Add”)
    form.elements["RecordLabelID"].value = label ? label.RecordLabelID : "";

    if (label) {
      Object.entries(label).forEach(([k,v])=>{
        if (form.elements[k]) form.elements[k].value = v;
      });
    }
    modal.classList.remove("hidden");
  }

  // Add New Label
  addBtn.onclick = e => {
    e.preventDefault();
    console.log("[addBtn] clicked");
    openForm("Add New Label");
  };

  // Cancel
  cancelBtn.onclick = e => {
    e.preventDefault();
    console.log("[cancelBtn] clicked hide modal");
    modal.classList.add("hidden");
  };

  // Form submit
  form.onsubmit = e => {
    e.preventDefault();
    const fd = new FormData(form), obj={};
    fd.forEach((v,k)=>obj[k]=v);
    console.log("[form submit]", obj);
    if (obj.RecordLabelID) {
      labels = labels.map(l=>l.RecordLabelID==obj.RecordLabelID?{...l,...obj}:l);
      console.log("[form] updated", obj.RecordLabelID);
    } else {
      obj.RecordLabelID = Math.max(0,...labels.map(l=>l.RecordLabelID))+1;
      labels.push(obj);
      console.log("[form] added", obj.RecordLabelID);
    }
    modal.classList.add("hidden");
    backToList();
  };

  // Initial table
  renderTable(labels);
  console.log("[record_labelInit] Done");
}

// expose
window.record_labelInit = record_labelInit;
