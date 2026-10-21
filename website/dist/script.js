(() => {
  const toggle = document.querySelector("[data-menu-toggle]");
  const navigation = document.querySelector("[data-navigation]");

  if (toggle && navigation) {
    toggle.addEventListener("click", () => {
      const expanded = toggle.getAttribute("aria-expanded") === "true";
      toggle.setAttribute("aria-expanded", String(!expanded));
      navigation.dataset.open = String(!expanded);
    });

    navigation.addEventListener("click", (event) => {
      if (event.target instanceof HTMLAnchorElement) {
        toggle.setAttribute("aria-expanded", "false");
        navigation.dataset.open = "false";
      }
    });
  }

  document.querySelectorAll("[data-current-year]").forEach((element) => {
    element.textContent = String(new Date().getFullYear());
  });
})();
