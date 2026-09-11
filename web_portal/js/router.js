// js/router.js
//
// MOCK ROUTER. This is NOT the real F7 Web Portal JS API Client / router
// from the system layout doc (js/api_client.js, js/auth.js). It exists so
// the four auth screens can be clicked through and previewed with no
// backend and no build step — just open index.html.
//
// TODO(Francis): replace this with the real router + authModule.checkAuth()
// gate described in F7, and swap the `// TODO(Francis)` callbacks in each
// view file for real fetch() calls to the FastAPI backend (see F7's
// apiClient.post / authModule.login / authModule.loginWithGoogle). Nothing
// in js/components.js or the view templates needs to change to do that —
// they only call plain callback functions, they don't know about fetch,
// sessionStorage, or this router's internals.

const Router = (() => {
  const routes = {};
  let current = null;

  function register(name, { render, init }) {
    routes[name] = { render, init };
  }

  /** Parse "#/verify-otp?email=a%40b.com" into { name: 'verify-otp', params: { email: 'a@b.com' } } */
  function parseHash() {
    const hash = location.hash.replace(/^#\/?/, '');
    const [name, queryString] = hash.split('?');
    const params = {};
    if (queryString) {
      new URLSearchParams(queryString).forEach((v, k) => (params[k] = v));
    }
    return { name: name || 'login', params };
  }

  function renderCurrent() {
    const { name, params } = parseHash();
    const route = routes[name] || routes['login'];
    current = name in routes ? name : 'login';

    const app = document.getElementById('app');
    app.innerHTML = route.render(params);
    if (typeof route.init === 'function') route.init(params);
    window.scrollTo(0, 0);
  }

  /** Navigate to a registered route, optionally carrying query params
   *  (e.g. Router.go('verify-otp', { email })). */
  function go(name, params = {}) {
    const qs = new URLSearchParams(params).toString();
    location.hash = `#/${name}${qs ? `?${qs}` : ''}`;
  }

  function start() {
    window.addEventListener('hashchange', renderCurrent);
    renderCurrent(); // initial paint
  }

  return { register, go, start, get current() { return current; } };
})();
