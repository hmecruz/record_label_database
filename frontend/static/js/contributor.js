// frontend/static/js/contributor.js

function contributorInit() {
  console.log("[contributorInit] start");

  const listSection    = document.getElementById("contrib-list-section");
  const detailsSection = document.getElementById("contrib-details-section");
  const modal          = document.getElementById("contrib-form-modal");
  const form           = document.getElementById("contrib-form");
  const addBtn         = document.getElementById("add-contrib-btn");
  const cancelBtn      = document.getElementById("contrib-cancel-btn");

  // initial visibility
  listSection.classList.remove("hidden");
  detailsSection.classList.add("hidden");
  modal.classList.add("hidden");

  // sample data with hard-coded isEmployee flag
  let contributors = [
    {
      ContributorID: 1,
      NIF: "111111111",
      Name: "Alice Jones",
      DateOfBirth: "1990-01-05",
      Email: "alice@music.com",
      PhoneNumber: "555-1234",
      Roles: ["Artist"],
      isEmployee: true
    },
    {
      ContributorID: 2,
      NIF: "222222222",
      Name: "Bob Smith",
      DateOfBirth: "1985-07-20",
      Email: "bob@music.com",
      PhoneNumber: "555-5678",
      Roles: ["Producer","Songwriter"],
      isEmployee: false
    }
  ];

  // render table
  function renderTable(data) {
    console.log("[renderTable] contributors:", data.length);
    const tbody = document.querySelector("#contrib-list-table tbody");
    tbody.innerHTML = data.map(c => `
      <tr data-id="${c.ContributorID}">
        <td>${c.ContributorID}</td>
        <td>${c.isEmployee ? "Yes" : "No"}</td>
        <td>${c.Name}</td>
        <td>${c.DateOfBirth || ""}</td>
        <td>${c.Email || ""}</td>
        <td>${c.PhoneNumber || ""}</td>
        <td>${c.Roles.join(", ")}</td>
      </tr>
    `).join("");
    document.querySelectorAll("#contrib-list-table tbody tr").forEach(row => {
      row.onclick = () => showDetails(+row.dataset.id);
    });
  }

  // filters: name, roles, email, phone
  [
    { key: "name",  field: c => c.Name },
    { key: "roles", field: c => c.Roles.join(" ") },
    { key: "email", field: c => c.Email || "" },
    { key: "phone", field: c => c.PhoneNumber || "" }
  ].forEach(({ key, field }) => {
    const input = document.getElementById(`filter-${key}`);
    if (!input) return;
    input.oninput = e => {
      const term = e.target.value.toLowerCase();
      console.log("[filter]", key, term);
      renderTable(contributors.filter(c => field(c).toLowerCase().includes(term)));
    };
  });

  // show details
  function showDetails(id) {
    const c = contributors.find(x => x.ContributorID === id);
    if (!c) return;
    console.log("[showDetails]", c);

    listSection.classList.add("hidden");
    detailsSection.classList.remove("hidden");
    modal.classList.add("hidden");

    document.getElementById("contrib-details").innerHTML = `
      <p><strong>ID:</strong> ${c.ContributorID}</p>
      <p><strong>Employee:</strong> ${c.isEmployee ? "Yes" : "No"}</p>
      <p><strong>Name:</strong> ${c.Name}</p>
      <p><strong>DOB:</strong> ${c.DateOfBirth || "-"}</p>
      <p><strong>Email:</strong> ${c.Email || "-"}</p>
      <p><strong>Phone:</strong> ${c.PhoneNumber || "-"}</p>
      <p><strong>Roles:</strong> ${c.Roles.join(", ")}</p>
    `;
    document.getElementById("edit-contrib-btn").onclick = () => openForm("Edit Contributor", c);
    document.getElementById("delete-contrib-btn").onclick = () => {
      console.log("[delete]", c.ContributorID);
      if (confirm(`Delete contributor "${c.Name}"?`)) {
        contributors = contributors.filter(x => x.ContributorID !== id);
        backToList();
      }
    };
    document.getElementById("back-contrib-list-btn").onclick = backToList;
  }

  // back to list
  function backToList() {
    console.log("[backToList]");
    detailsSection.classList.add("hidden");
    listSection.classList.remove("hidden");
    modal.classList.add("hidden");
    renderTable(contributors);
  }

  // open modal
  function openForm(title, c = null) {
    console.log("[openForm]", title, c);
    document.getElementById("contrib-modal-title").textContent = title;
    form.reset();
    form.elements["ContributorID"].value = c ? c.ContributorID : "";
    form.elements["NIF"].value           = c ? c.NIF : "";
    form.elements["Name"].value          = c ? c.Name : "";
    form.elements["DateOfBirth"].value   = c ? c.DateOfBirth : "";
    form.elements["Email"].value         = c ? c.Email : "";
    form.elements["PhoneNumber"].value   = c ? c.PhoneNumber : "";
    form.elements["Roles"].value         = c ? c.Roles.join(", ") : "";
    // Note: isEmployee is not editable here
    modal.classList.remove("hidden");
  }

  // add
  addBtn.onclick = e => {
    e.preventDefault();
    openForm("Add Contributor");
  };

  // cancel
  cancelBtn.onclick = e => {
    e.preventDefault();
    console.log("[cancel]");
    modal.classList.add("hidden");
  };

  // submit
  form.onsubmit = e => {
    e.preventDefault();
    const fd = new FormData(form), obj = {};
    fd.forEach((v, k) => obj[k] = v);
    console.log("[submit]", obj);
    obj.Roles = obj.Roles.split(",").map(s => s.trim()).filter(Boolean);
    if (obj.ContributorID) {
      contributors = contributors.map(x =>
        x.ContributorID == obj.ContributorID ? { ...x, ...obj } : x
      );
    } else {
      obj.ContributorID = Math.max(0, ...contributors.map(x => x.ContributorID)) + 1;
      obj.NIF = obj.NIF || String(100000000 + obj.ContributorID);
      obj.isEmployee = false;  // default for new
      contributors.push(obj);
    }
    modal.classList.add("hidden");
    backToList();
  };

  // initial
  renderTable(contributors);
  console.log("[contributorInit] done");
}

// expose
window.contributorInit = contributorInit;
