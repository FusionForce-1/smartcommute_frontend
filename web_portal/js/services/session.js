// Services session
// Session session
const Session = (() => {
  const KEY = 'smartcommute.session';

  // Read session
  function read() {
    try {
      return JSON.parse(localStorage.getItem(KEY) || sessionStorage.getItem(KEY));
    } catch {
      return null;
    }
  }

  // Storage in use
  function storageInUse() {
    return localStorage.getItem(KEY) ? localStorage : sessionStorage;
  }

  // Clear session
  function clear() {
    localStorage.removeItem(KEY);
    sessionStorage.removeItem(KEY);
  }

  // Save session
  function save(data, remember = false) {
    clear();
    (remember ? localStorage : sessionStorage).setItem(KEY, JSON.stringify(data));
  }

  // Update session
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
