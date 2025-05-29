document.addEventListener("DOMContentLoaded", () => {
  const content = document.getElementById("content");

  const loadPage = (page) => {
    fetch(`pages/${page}.html`)
      .then((res) => res.text())
      .then((html) => {
        content.innerHTML = html;
        if (window[`${page}Init`]) {
          window[`${page}Init`](); // call page init script
        }
      })
      .catch(() => {
        content.innerHTML = "<p>Page not found.</p>";
      });
  };

  document.querySelectorAll("a[data-page]").forEach((link) => {
    link.addEventListener("click", (e) => {
      e.preventDefault();
      const page = link.getAttribute("data-page");
      loadPage(page);
    });
  });

  loadPage("dashboard"); // default page
});
