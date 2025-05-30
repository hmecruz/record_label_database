document.addEventListener("DOMContentLoaded", () => {
  const content = document.getElementById("content");

  // Expose loadPage globally
  window.loadPage = (page) => {
    fetch(`/pages/${page}.html`)
      .then((res) => {
        if (!res.ok) throw new Error("Page not found");
        return res.text();
      })
      .then((html) => {
        content.innerHTML = html;
        // Call the page's init if defined
        if (typeof window[`${page}Init`] === "function") {
          window[`${page}Init`]();
        }
      })
      .catch((err) => {
        content.innerHTML = `<p>Error loading page: ${err.message}</p>`;
      });
  };

  // Wire up nav and card links
  document.querySelectorAll("a[data-page], .card[data-page]").forEach((el) => {
    el.addEventListener("click", (e) => {
      e.preventDefault();
      const page = el.getAttribute("data-page");
      window.loadPage(page);
      window.history.pushState(null, "", `#${page}`);
    });
  });

  // Load initial page from hash or default
  const initialPage = window.location.hash.substring(1) || "dashboard";
  window.loadPage(initialPage);
});
