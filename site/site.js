(() => {
  "use strict";

  const copyText = async (value) => {
    if (navigator.clipboard && window.isSecureContext) {
      await navigator.clipboard.writeText(value);
      return;
    }

    const input = document.createElement("textarea");
    input.value = value;
    input.setAttribute("readonly", "");
    input.className = "copy-buffer";
    document.body.append(input);
    input.select();
    const copied = document.execCommand("copy");
    input.remove();

    if (!copied) {
      throw new Error("Copy command was not available");
    }
  };

  document.querySelectorAll("[data-copy]").forEach((button) => {
    const idleLabel = button.textContent.trim();
    const successLabel = button.dataset.copySuccess || "Copied";
    const failureLabel = button.dataset.copyFailure || "Select and copy";

    button.addEventListener("click", async () => {
      const target = document.querySelector(button.dataset.copy);
      if (!target) return;

      try {
        await copyText(target.textContent.trim());
        button.textContent = successLabel;
      } catch {
        button.textContent = failureLabel;
      }

      window.setTimeout(() => {
        button.textContent = idleLabel;
      }, 2200);
    });
  });

  document.querySelectorAll("[data-year]").forEach((node) => {
    node.textContent = String(new Date().getFullYear());
  });
})();
