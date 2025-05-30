// dashboard.js
function dashboardInit() {
  // Replace with real API calls as needed
  const stats = {
    record_label: { label: "Record Labels", count: 5 },
    employee:     { label: "Employees",     count: 42 },
    song:         { label: "Songs",         count: 128 },
    contributor:  { label: "Contributors",  count: 17 },
    collaboration:{ label: "Collaborations",count: 23 },
  };

  // Populate cards
  Object.entries(stats).forEach(([key, { label, count }]) => {
    const countEl = document.getElementById(`count-${key}`);
    if (countEl) countEl.textContent = count;
  });

  // Card click navigation
  document.querySelectorAll(".card").forEach(card => {
    card.addEventListener("click", e => {
      e.preventDefault();
      const page = card.getAttribute("data-page");
      window.loadPage(page);
    });
  });
}

// Expose init to the global loader
window.dashboardInit = dashboardInit;
