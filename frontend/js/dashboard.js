function dashboardInit() {
  // Simulate fetching from backend
  const labelData = [
    { name: "Universal Music", employees: 10, collaborations: 3 },
    { name: "Sony Music", employees: 7, collaborations: 1 },
    { name: "Warner Music", employees: 5, collaborations: 2 },
  ];

  const contributorData = [
    { name: "Alice Jones", roles: "Artist", songs: 12, collaborations: 4 },
    { name: "Bob Smith", roles: "Producer, Songwriter", songs: 8, collaborations: 5 },
  ];

  const labelTable = document.getElementById("label-summary-table").querySelector("tbody");
  labelTable.innerHTML = labelData.map(
    l => `<tr><td>${l.name}</td><td>${l.employees}</td><td>${l.collaborations}</td></tr>`
  ).join("");

  const contribTable = document.getElementById("top-contributors-table").querySelector("tbody");
  contribTable.innerHTML = contributorData.map(
    c => `<tr><td>${c.name}</td><td>${c.roles}</td><td>${c.songs}</td><td>${c.collaborations}</td></tr>`
  ).join("");
}
