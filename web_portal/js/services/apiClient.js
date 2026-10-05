// js/services/apiClient.js
//
// Thin fetch() wrapper for the FastAPI backend:
//   - sends the Bearer token from Session
//   - on 401, refreshes the access token once and retries
//   - turns FastAPI error bodies into Error(message) with .statusCode
// If the session cannot be refreshed it is cleared and a
// `session:expired` event fires on window so the page can redirect.

const ApiClient = (() => {
  let refreshInFlight = null;

  function apiError(message, statusCode) {
    const err = new Error(message);
    err.statusCode = statusCode;
    return err;
  }

  /** FastAPI sends `detail` as a string, or as a list for 422 validation errors. */
  function messageFrom(data, response) {
    const detail = data?.detail;
    if (typeof detail === 'string') return detail;
    if (Array.isArray(detail) && detail[0]?.msg) return detail[0].msg;
    return `Request failed (${response.status} ${response.statusText}).`;
  }

  async function refreshSession() {
    const refreshToken = Session.refreshToken;
    if (!refreshToken) return false;

    // Several requests can 401 at once; share a single refresh call.
    refreshInFlight ??= send('POST', '/auth/refresh', { refresh_token: refreshToken }, { auth: false })
      .then((tokens) => {
        Session.update({
          access_token: tokens.access_token,
          refresh_token: tokens.refresh_token,
          role: tokens.role,
        });
        return true;
      })
      .catch(() => false)
      .finally(() => { refreshInFlight = null; });

    return refreshInFlight;
  }

  async function send(method, path, body, { auth = true, retry = true } = {}) {
    const headers = { 'Content-Type': 'application/json' };
    if (auth && Session.accessToken) headers.Authorization = `Bearer ${Session.accessToken}`;

    let response;
    try {
      response = await fetch(`${API_BASE_URL}${path}`, {
        method,
        headers,
        body: body === undefined ? undefined : JSON.stringify(body),
      });
    } catch {
      throw apiError('Cannot reach the server. Check that the backend is running.', 0);
    }

    if (response.status === 401 && auth && retry && (await refreshSession())) {
      return send(method, path, body, { auth, retry: false });
    }

    const data = response.status === 204 ? null : await response.json().catch(() => null);

    if (!response.ok) {
      if (response.status === 401 && auth) {
        Session.clear();
        window.dispatchEvent(new CustomEvent('session:expired'));
      }
      throw apiError(messageFrom(data, response), response.status);
    }
    return data;
  }

  /** Builds "?a=1&b=2", skipping empty values. */
  function query(params = {}) {
    const entries = Object.entries(params).filter(([, v]) => v !== undefined && v !== null && v !== '');
    return entries.length ? `?${new URLSearchParams(entries)}` : '';
  }

  return {
    request: send,
    query,
    get: (path, params) => send('GET', `${path}${query(params)}`),
    post: (path, body) => send('POST', path, body),
    patch: (path, body) => send('PATCH', path, body),
    delete: (path) => send('DELETE', path),
  };
})();
