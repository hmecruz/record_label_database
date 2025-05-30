// frontend/static/js/collaboration.js

function collaborationInit() {
  console.log("[collaborationInit] start");

  const listSection     = document.getElementById("collab-list-section");
  const detailsSection  = document.getElementById("collab-details-section");
  const modal           = document.getElementById("collab-form-modal");
  const form            = document.getElementById("collab-form");
  const addBtn          = document.getElementById("add-collab-btn");
  const cancelBtn       = document.getElementById("collab-cancel-btn");

  listSection.classList.remove("hidden");
  detailsSection.classList.add("hidden");
  modal.classList.add("hidden");

  // Sample data including related labels & contributors
  let collabs = [
    {
      CollaborationID: 1,
      CollaborationName: "Summer Hit",
      StartDate: "2021-06-01",
      EndDate: "2021-08-31",
      SongTitle: "Sunny Days",
      RecordLabels: ["Universal Music","Sony Music"],
      Contributors: ["Alice Jones","Bob Smith"],
      Description: "Annual summer collaboration"
    },
    {
      CollaborationID: 2,
      CollaborationName: "Winter Ballad",
      StartDate: "2020-12-01",
      EndDate: "2021-02-28",
      SongTitle: "Snowfall",
      RecordLabels: ["Warner Music"],
      Contributors: ["Carol White"],
      Description: "Cozy winter project"
    }
  ];

  function renderTable(data) {
    console.log("[renderTable] collabs:", data.length);
    const tbody = document.querySelector("#collab-list-table tbody");
    tbody.innerHTML = data.map(c => `
      <tr data-id="${c.CollaborationID}">
        <td>${c.CollaborationID}</td>
        <td>${c.CollaborationName}</td>
        <td>${c.StartDate}</td>
        <td>${c.EndDate||""}</td>
        <td>${c.SongTitle||""}</td>
        <td>${c.RecordLabels.join(", ")}</td>
        <td>${c.Contributors.join(", ")}</td>
        <td>${c.Description}</td>
      </tr>
    `).join("");
    document.querySelectorAll("#collab-list-table tbody tr").forEach(row => {
      row.onclick = () => showDetails(+row.dataset.id);
    });
  }

  // filtering by each attribute
  [
    { key:"name",       field: c => c.CollaborationName },
    { key:"start",      field: c => c.StartDate },
    { key:"end",        field: c => c.EndDate||"" },
    { key:"song",       field: c => c.SongTitle||"" },
    { key:"labels",     field: c => c.RecordLabels.join(" ") },
    { key:"contributors",field:c => c.Contributors.join(" ") }
  ].forEach(({key, field}) => {
    const input = document.getElementById(`filter-${key}`);
    if (!input) return;
    input.oninput = e => {
      const term = e.target.value.toLowerCase();
      console.log("[filter]", key, term);
      renderTable(collabs.filter(c => field(c).toLowerCase().includes(term)));
    };
  });

  function showDetails(id) {
    const c = collabs.find(x=>x.CollaborationID===id);
    if (!c) return;
    console.log("[showDetails]", c);

    listSection.classList.add("hidden");
    detailsSection.classList.remove("hidden");
    modal.classList.add("hidden");

    document.getElementById("collab-details").innerHTML = `
      <p><strong>ID:</strong> ${c.CollaborationID}</p>
      <p><strong>Name:</strong> ${c.CollaborationName}</p>
      <p><strong>Start Date:</strong> ${c.StartDate}</p>
      <p><strong>End Date:</strong> ${c.EndDate||"-"}</p>
      <p><strong>Song:</strong> ${c.SongTitle||"-"}</p>
      <p><strong>Record Labels:</strong> ${c.RecordLabels.join(", ")}</p>
      <p><strong>Contributors:</strong> ${c.Contributors.join(", ")}</p>
      <p><strong>Description:</strong> ${c.Description}</p>
    `;

    document.getElementById("edit-collab-btn").onclick = () => openForm("Edit Collaboration", c);
    document.getElementById("delete-collab-btn").onclick = () => {
      console.log("[delete]", c.CollaborationID);
      if (confirm(`Delete "${c.CollaborationName}" and all associations?`)) {
        collabs = collabs.filter(x=>x.CollaborationID!==id);
        backToList();
      }
    };
    document.getElementById("back-collab-list-btn").onclick = backToList;
  }

  function backToList() {
    console.log("[backToList]");
    detailsSection.classList.add("hidden");
    listSection.classList.remove("hidden");
    modal.classList.add("hidden");
    renderTable(collabs);
  }

  function openForm(title, c=null) {
    console.log("[openForm]", title, c);
    document.getElementById("collab-modal-title").textContent = title;
    form.reset();
    form.elements["CollaborationID"].value    = c? c.CollaborationID : "";
    form.elements["CollaborationName"].value  = c? c.CollaborationName : "";
    form.elements["StartDate"].value          = c? c.StartDate : "";
    form.elements["EndDate"].value            = c? c.EndDate || "" : "";
    form.elements["SongTitle"].value          = c? c.SongTitle : "";
    form.elements["RecordLabels"].value       = c? c.RecordLabels.join(", ") : "";
    form.elements["Contributors"].value       = c? c.Contributors.join(", ") : "";
    form.elements["Description"].value        = c? c.Description : "";
    modal.classList.remove("hidden");
  }

  addBtn.onclick = e => {
    e.preventDefault();
    openForm("Add Collaboration");
  };

  cancelBtn.onclick = e => {
    e.preventDefault();
    console.log("[cancel]");
    modal.classList.add("hidden");
  };

  form.onsubmit = e => {
    e.preventDefault();
    const fd = new FormData(form), obj = {};
    fd.forEach((v,k)=> obj[k] = v);
    console.log("[submit]", obj);
    // parse arrays
    obj.RecordLabels = obj.RecordLabels.split(",").map(s=>s.trim()).filter(Boolean);
    obj.Contributors  = obj.Contributors.split(",").map(s=>s.trim()).filter(Boolean);

    if (obj.CollaborationID) {
      collabs = collabs.map(x=>
        x.CollaborationID==obj.CollaborationID
          ? {...x, ...obj}
          : x
      );
    } else {
      obj.CollaborationID = Math.max(0,...collabs.map(x=>x.CollaborationID)) + 1;
      collabs.push(obj);
    }

    modal.classList.add("hidden");
    backToList();
  };

  renderTable(collabs);
  console.log("[collaborationInit] done");
}

// expose for loader
window.collaborationInit = collaborationInit;
