async function dashboardInit() {
  try {
    const res = await fetch('/api/dashboard/counts');
    if (!res.ok) throw res;
    const stats = await res.json();

    // Populate each card’s count
    document.getElementById('count-record_label').textContent   = stats.RecordLabelCount;
    document.getElementById('count-employee').textContent       = stats.EmployeeCount;
    document.getElementById('count-song').textContent           = stats.SongCount;
    document.getElementById('count-contributor').textContent    = stats.ContributorCount;
    document.getElementById('count-collaboration').textContent  = stats.CollaborationCount;
  } catch (err) {
    console.error('[API] fetch dashboard counts failed', err);
    alert('Unable to load dashboard counts.');
  }

  // Card click navigation (unchanged)
  document.querySelectorAll('.card').forEach(card => {
    card.addEventListener('click', e => {
      e.preventDefault();
      const page = card.getAttribute('data-page');
      window.loadPage(page);
    });
  });
}

window.dashboardInit = dashboardInit;
