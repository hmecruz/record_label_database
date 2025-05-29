document.addEventListener("DOMContentLoaded", () => {
  const content = document.getElementById("content");

  const loadPage = (page) => {
    fetch(`/pages/${page}.html`) // Use absolute path to fetch from Flask
      .then((res) => {
        if (!res.ok) throw new Error("Page not found");
        return res.text();
      })
      .then((html) => {
        content.innerHTML = html;
        if (typeof window[`${page}Init`] === "function") {
          window[`${page}Init`](); // call page-specific init function if exists
        }
      })
      .catch((err) => {
        content.innerHTML = `<p>Error loading page: ${err.message}</p>`;
      });
  };

  document.querySelectorAll("a[data-page]").forEach((link) => {
    link.addEventListener("click", (e) => {
      e.preventDefault();
      const page = link.getAttribute("data-page");
      loadPage(page);
      window.history.pushState(null, "", `#${page}`);
    });
  });

  // Load the page based on URL hash if present
  const initialPage = window.location.hash.substring(1) || "dashboard";
  loadPage(initialPage);
});
