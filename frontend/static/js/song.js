// frontend/static/js/song.js

function songInit() {
  console.log("[songInit] start");

  const listSection     = document.getElementById("song-list-section");
  const detailsSection  = document.getElementById("song-details-section");
  const modal           = document.getElementById("song-form-modal");
  const form            = document.getElementById("song-form");
  const addBtn          = document.getElementById("add-song-btn");
  const cancelBtn       = document.getElementById("song-cancel-btn");

  // Initial visibility
  listSection.classList.remove("hidden");
  detailsSection.classList.add("hidden");
  modal.classList.add("hidden");

  // Sample song data
  let songs = [
    {
      SongID: 1,
      Title: "Hit Record",
      Duration: 210,
      ReleaseDate: "2021-05-20",
      Genres: ["Pop", "Dance"],
      Contributors: ["Alice Jones", "Bob Smith"],
      CollaborationName: "Summer Jam"
    },
    {
      SongID: 2,
      Title: "Deep Melody",
      Duration: 185,
      ReleaseDate: "2020-11-10",
      Genres: ["R&B"],
      Contributors: ["Carol White"],
      CollaborationName: "Soul Sessions"
    }
  ];

  // Render the song list
  function renderTable(data) {
    console.log("[renderTable] songs:", data.length);
    const tbody = document.querySelector("#song-list-table tbody");
    tbody.innerHTML = data.map(s => `
      <tr data-id="${s.SongID}">
        <td>${s.SongID}</td>
        <td>${s.Title}</td>
        <td>${s.Duration}</td>
        <td>${s.ReleaseDate}</td>
        <td>${s.Genres.join(", ")}</td>
        <td>${s.Contributors.join(", ")}</td>
        <td>${s.CollaborationName || ""}</td>
      </tr>
    `).join("");
    document.querySelectorAll("#song-list-table tbody tr").forEach(row => {
      row.onclick = () => showDetails(+row.dataset.id);
    });
  }

  // Filters: title, duration, release, genre, contributor, collaboration
  [
    { key: "title",         field: s => s.Title },
    { key: "duration",      field: s => String(s.Duration) },
    { key: "release",       field: s => s.ReleaseDate },
    { key: "genre",         field: s => s.Genres.join(" ") },
    { key: "contributor",   field: s => s.Contributors.join(" ") },
    { key: "collaboration", field: s => s.CollaborationName }
  ].forEach(({key, field}) => {
    const input = document.getElementById(`filter-${key}`);
    if (!input) return;
    input.oninput = e => {
      const term = e.target.value.toLowerCase();
      console.log("[filter]", key, term);
      renderTable(songs.filter(s => field(s).toLowerCase().includes(term)));
    };
  });

  // Show song details
  function showDetails(id) {
    const s = songs.find(x => x.SongID === id);
    if (!s) return;
    console.log("[showDetails]", s);

    listSection.classList.add("hidden");
    detailsSection.classList.remove("hidden");
    modal.classList.add("hidden");

    document.getElementById("song-details").innerHTML = `
      <p><strong>ID:</strong> ${s.SongID}</p>
      <p><strong>Title:</strong> ${s.Title}</p>
      <p><strong>Duration:</strong> ${s.Duration} sec</p>
      <p><strong>Release Date:</strong> ${s.ReleaseDate}</p>
      <p><strong>Genres:</strong> ${s.Genres.join(", ")}</p>
      <p><strong>Contributors:</strong> ${s.Contributors.join(", ")}</p>
      <p><strong>Collaboration:</strong> ${s.CollaborationName || "-"}</p>
    `;

    document.getElementById("edit-song-btn").onclick = () => openForm("Edit Song", s);
    document.getElementById("delete-song-btn").onclick = () => {
      console.log("[deleteSong]", s.SongID);
      if (confirm(`Delete song "${s.Title}"? This will remove genres, contributions, etc.`)) {
        songs = songs.filter(x => x.SongID !== id);
        backToList();
      }
    };
    document.getElementById("back-song-list-btn").onclick = backToList;
  }

  // Back to list view
  function backToList() {
    console.log("[backToList]");
    detailsSection.classList.add("hidden");
    listSection.classList.remove("hidden");
    modal.classList.add("hidden");
    renderTable(songs);
  }

  // Open Add/Edit form
  function openForm(title, s = null) {
    console.log("[openForm]", title, s);
    document.getElementById("song-modal-title").textContent = title;
    form.reset();
    form.elements["SongID"].value = s ? s.SongID : "";
    form.elements["Title"].value = s ? s.Title : "";
    form.elements["Duration"].value = s ? s.Duration : "";
    form.elements["ReleaseDate"].value = s ? s.ReleaseDate : "";
    form.elements["Genres"].value = s ? s.Genres.join(", ") : "";
    form.elements["Contributors"].value = s ? s.Contributors.join(", ") : "";
    form.elements["CollaborationName"].value = s ? s.CollaborationName : "";
    modal.classList.remove("hidden");
  }

  // Add new song
  document.getElementById("add-song-btn").onclick = e => {
    e.preventDefault();
    openForm("Add Song");
  };

  // Cancel form
  cancelBtn.onclick = e => {
    e.preventDefault();
    console.log("[cancelSong]");
    modal.classList.add("hidden");
  };

  // Form submit
  form.onsubmit = e => {
    e.preventDefault();
    const fd = new FormData(form), obj = {};
    fd.forEach((v, k) => obj[k] = v);
    console.log("[submitSong]", obj);
    if (obj.SongID) {
      songs = songs.map(x => x.SongID == obj.SongID ? {
        ...x,
        Title: obj.Title,
        Duration: +obj.Duration,
        ReleaseDate: obj.ReleaseDate,
        Genres: obj.Genres.split(",").map(s => s.trim()).filter(Boolean),
        Contributors: obj.Contributors.split(",").map(s => s.trim()).filter(Boolean),
        CollaborationName: obj.CollaborationName
      } : x);
    } else {
      obj.SongID = Math.max(0, ...songs.map(x => x.SongID)) + 1;
      songs.push({
        SongID: obj.SongID,
        Title: obj.Title,
        Duration: +obj.Duration,
        ReleaseDate: obj.ReleaseDate,
        Genres: obj.Genres.split(",").map(s => s.trim()).filter(Boolean),
        Contributors: obj.Contributors.split(",").map(s => s.trim()).filter(Boolean),
        CollaborationName: obj.CollaborationName
      });
    }
    modal.classList.add("hidden");
    backToList();
  };

  // Initial render
  renderTable(songs);
  console.log("[songInit] done");
}

// Expose for loader
window.songInit = songInit;
