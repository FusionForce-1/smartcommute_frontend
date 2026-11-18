// Modal dialog helper
// Auth modal
const AuthModal = (() => {
  let backdropEl = null;

  // Open modal
  function open(html, { onMount, centered = true } = {}) {
    close();
    backdropEl = document.createElement('div');
    backdropEl.className = 'modal-backdrop';
    const extra = centered ? ' auth-card--centered' : '';
    backdropEl.innerHTML = `<div class="modal-shell auth-card${extra}">${html}</div>`;
    document.body.appendChild(backdropEl);

    backdropEl.addEventListener('click', (e) => {
      if (e.target === backdropEl) close();
    });

    if (typeof onMount === 'function') onMount();
  }

  // Set content
  function setContent(html, { onMount, centered = true } = {}) {
    if (!backdropEl) return open(html, { onMount, centered });
    const extra = centered ? ' auth-card--centered' : '';
    const shell = backdropEl.querySelector('.modal-shell');
    shell.className = `modal-shell auth-card${extra}`;
    shell.innerHTML = html;
    if (typeof onMount === 'function') onMount();
  }

  // Close modal
  function close() {
    if (backdropEl) {
      backdropEl.remove();
      backdropEl = null;
    }
  }

  return { open, setContent, close };
})();
