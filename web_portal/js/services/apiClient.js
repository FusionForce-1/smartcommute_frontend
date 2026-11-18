// Services API client
// API client
const ApiClient = (() => {
  let refreshInFlight = null;

  // API error
  function apiError(message, statusCode) {
    const err = new Error(message);
    err.statusCode = statusCode;
    return err;
  }

  // Message from
  function messageFrom(data, response) {
    const detail = data?.detail;
    if (typeof detail === 'string') return detail;
    if (Array.isArray(detail) && detail[0]?.msg) return detail[0].msg;
    return `Request failed (${response.status} ${response.statusText}).`;
  }

  // Refresh session
  async function refreshSession() {
    const refreshToken = Session.refreshToken;
    if (!refreshToken) return false;

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

  // Send client
  async function send(method, path, body, { auth = true, retry = true } = {}) {
    const isForm = body instanceof FormData;
    const headers = isForm ? {} : { 'Content-Type': 'application/json' };
    if (auth && Session.accessToken) headers.Authorization = `Bearer ${Session.accessToken}`;

    let response;
    try {
      response = await fetch(`${API_BASE_URL}${path}`, {
        method,
        headers,
        body: body === undefined || isForm ? body : JSON.stringify(body),
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

  // Client query
  function query(params = {}) {
    const entries = Object.entries(params).filter(([, v]) => v !== undefined && v !== null && v !== '');
    return entries.length ? `?${new URLSearchParams(entries)}` : '';
  }

  return {
    request: send,
    query,
    get: (path, params) => send('GET', `${path}${query(params)}`),
    // Client post
    post: (path, body) => send('POST', path, body),
    // Upload client
    upload: (path, formData) => send('POST', path, formData),
    // Client put
    put: (path, body) => send('PUT', path, body),
    // Client patch
    patch: (path, body) => send('PATCH', path, body),
    // Delete client
    delete: (path) => send('DELETE', path),
  };
})();
