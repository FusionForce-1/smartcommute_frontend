// js/main.js
//
// Small shared helpers used by every view's init(), plus the app bootstrap.
// Loaded last (see index.html) so Router.start() only runs once every view
// has registered itself and every helper below is defined.

/** Wires the eye/eye-off toggle button next to a password field with id
 *  `fieldId`. Pure DOM, no state kept outside the input's own type attr. */
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

function showError(id) {
  const el = document.getElementById(id);
  if (el) el.hidden = false;
}

function hideError(id) {
  const el = document.getElementById(id);
  if (el) el.hidden = true;
}

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

// --- Bootstrap ---
// All four views have already called Router.register(...) by this point
// (their <script> tags run before this one — see index.html), so it's safe
// to start the router now.
Router.start();
