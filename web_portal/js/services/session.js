// js/services/session.js
//
// Stores the logged-in user's tokens, role and email.
// "Remember Me" keeps the session in localStorage; otherwise it lives in
// sessionStorage and ends when the tab closes.

const Session = (() => {
  const KEY = 'smartcommute.session';

  function read() {
    try {
      return JSON.parse(localStorage.getItem(KEY) || sessionStorage.getItem(KEY));
    } catch {
      return null;
    }
  }

  function storageInUse() {
    return localStorage.getItem(KEY) ? localStorage : sessionStorage;
  }

  function clear() {
    localStorage.removeItem(KEY);
    sessionStorage.removeItem(KEY);
  }

  /** @param {{access_token, refresh_token, role, email}} data */
  function save(data, remember = false) {
    clear();
    (remember ? localStorage : sessionStorage).setItem(KEY, JSON.stringify(data));
  }

  function update(patch) {
    const current = read();
    if (!current) return;
    storageInUse().setItem(KEY, JSON.stringify({ ...current, ...patch }));
  }

  return {
    save,
    update,
    clear,
    get: read,
    get accessToken() { return read()?.access_token || null; },
    get refreshToken() { return read()?.refresh_token || null; },
    get role() { return read()?.role || null; },
    get email() { return read()?.email || ''; },
  };
})();
