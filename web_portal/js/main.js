// Portal entry point
// Wire password toggle
function wirePasswordToggle(fieldId) {
  const input = document.getElementById(fieldId);
  const toggle = document.querySelector(`[data-toggle-for="${fieldId}"]`);
  if (!input || !toggle) return;

  toggle.addEventListener('click', () => {
    const isPassword = input.type === 'password';
    input.type = isPassword ? 'text' : 'password';
    toggle.innerHTML = isPassword ? iconMarkup('passwordHidden') : iconMarkup('passwordVisible');
    toggle.setAttribute('aria-label', isPassword ? 'Hide password' : 'Show password');
  });
}

// Show error
function showError(id) {
  const el = document.getElementById(id);
  if (el) el.hidden = false;
}

// Hide error
function hideError(id) {
  const el = document.getElementById(id);
  if (el) el.hidden = true;
}

// Escape HTML
function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

Router.start();
