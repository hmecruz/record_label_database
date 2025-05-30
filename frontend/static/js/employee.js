// frontend/static/js/employee.js

function employeeInit() {
  console.log("[employeeInit] start");

  const listSection    = document.getElementById("emp-list-section");
  const detailsSection = document.getElementById("emp-details-section");
  const modal          = document.getElementById("emp-form-modal");
  const form           = document.getElementById("emp-form");
  const addBtn         = document.getElementById("add-emp-btn");
  const cancelBtn      = document.getElementById("emp-cancel-btn");

  // initial state
  listSection.classList.remove("hidden");
  detailsSection.classList.add("hidden");
  modal.classList.add("hidden");

  // Sample data with NIF & DOB
  let emps = [
    { EmployeeID:1, NIF:"123456789", Name:"Alice Smith", DateOfBirth:"1985-04-12", JobTitle:"Manager", Department:"A&R", Salary:55000, HireDate:"2020-06-15", Email:"alice@label.com", PhoneNumber:"111-222-3333" },
    { EmployeeID:2, NIF:"987654321", Name:"Bob Jones",   DateOfBirth:"1990-08-30", JobTitle:"Producer",Department:"Production",Salary:48000, HireDate:"2019-03-20", Email:"bob@label.com",   PhoneNumber:"222-333-4444" }
  ];

  function renderTable(data) {
    console.log("[renderTable] rows:", data.length);
    const tbody = document.querySelector("#emp-list-table tbody");
    tbody.innerHTML = data.map(e=>`
      <tr data-id="${e.EmployeeID}">
        <td>${e.EmployeeID}</td>
        <td>${e.NIF}</td>
        <td>${e.Name}</td>
        <td>${e.DateOfBirth||""}</td>
        <td>${e.JobTitle}</td>
        <td>${e.Department}</td>
        <td>${e.Salary.toFixed(2)}</td>
        <td>${e.HireDate}</td>
        <td>${e.Email||""}</td>
        <td>${e.PhoneNumber||""}</td>
      </tr>
    `).join("");
    document.querySelectorAll("#emp-list-table tbody tr").forEach(row=>{
      row.onclick = ()=> showDetails(+row.dataset.id);
    });
  }

  // Filters: nif, name, dob, jobtitle, department, email, phone
  ["nif","name","dob","jobtitle","department","email","phone"].forEach(key=>{
    const input = document.getElementById(`filter-${key}`);
    if (!input) return;
    input.oninput = e => {
      const term = e.target.value.toLowerCase();
      console.log("[filter]", key, term);
      renderTable(
        emps.filter(emp => {
          let field;
          switch(key) {
            case "nif":        field = emp.NIF; break;
            case "dob":        field = emp.DateOfBirth; break;
            case "jobtitle":   field = emp.JobTitle; break;
            case "department": field = emp.Department; break;
            case "email":      field = emp.Email; break;
            case "phone":      field = emp.PhoneNumber; break;
            default:           field = emp.Name;
          }
          return String(field||"").toLowerCase().includes(term);
        })
      );
    };
  });

  function showDetails(id) {
    const e = emps.find(x=>x.EmployeeID===id);
    if (!e) return;
    console.log("[showDetails]", e);

    listSection.classList.add("hidden");
    detailsSection.classList.remove("hidden");
    modal.classList.add("hidden");

    document.getElementById("emp-details").innerHTML = `
      <p><strong>ID:</strong> ${e.EmployeeID}</p>
      <p><strong>NIF:</strong> ${e.NIF}</p>
      <p><strong>Name:</strong> ${e.Name}</p>
      <p><strong>DOB:</strong> ${e.DateOfBirth||"-"}</p>
      <p><strong>Job Title:</strong> ${e.JobTitle}</p>
      <p><strong>Dept:</strong> ${e.Department}</p>
      <p><strong>Salary:</strong> ${e.Salary.toFixed(2)}</p>
      <p><strong>Hired:</strong> ${e.HireDate}</p>
      <p><strong>Email:</strong> ${e.Email||"-"}</p>
      <p><strong>Phone:</strong> ${e.PhoneNumber||"-"}</p>
      <p><em>Removing this employee will delete only their record.</em></p>
    `;
    document.getElementById("edit-emp-btn").onclick = ()=> openForm("Edit Employee", e);
    document.getElementById("delete-emp-btn").onclick = ()=> {
      console.log("[deleteEmp]", e.EmployeeID);
      if (confirm(`Delete employee "${e.Name}"?`)) {
        emps = emps.filter(x=>x.EmployeeID!==id);
        backToList();
      }
    };
    document.getElementById("back-emp-list-btn").onclick = backToList;
  }

  function backToList(){
    console.log("[backToList]");
    detailsSection.classList.add("hidden");
    listSection.classList.remove("hidden");
    modal.classList.add("hidden");
    renderTable(emps);
  }

  function openForm(title, emp=null) {
    console.log("[openForm]", title, emp);
    document.getElementById("emp-modal-title").textContent = title;
    form.reset();
    form.elements["EmployeeID"].value = emp? emp.EmployeeID : "";
    ["NIF","Name","DateOfBirth","JobTitle","Department","Salary","HireDate","Email","PhoneNumber"].forEach(f=>{
      if (form.elements[f]) form.elements[f].value = emp? emp[f] : "";
    });
    modal.classList.remove("hidden");
  }

  addBtn.onclick = e=>{
    e.preventDefault();
    console.log("[addEmp]");
    openForm("Add Employee");
  };

  cancelBtn.onclick = e=>{
    e.preventDefault();
    console.log("[cancelEmp]");
    modal.classList.add("hidden");
  };

  form.onsubmit = e=>{
    e.preventDefault();
    const fd=new FormData(form), obj={};
    fd.forEach((v,k)=>obj[k]=v);
    console.log("[submitEmp]", obj);
    if (obj.EmployeeID) {
      emps = emps.map(x=>x.EmployeeID==obj.EmployeeID?{...x,...obj}:x);
    } else {
      obj.EmployeeID=Math.max(0,...emps.map(x=>x.EmployeeID))+1;
      emps.push(obj);
    }
    modal.classList.add("hidden");
    backToList();
  };

  renderTable(emps);
  console.log("[employeeInit] done");
}

// Expose init
window.employeeInit = employeeInit;
