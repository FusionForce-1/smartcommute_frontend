// Page router
// Router router
const Router = (() => {
  const routes = {};
  let current = null;

  // Register router
  function register(name, { render, init }) {
    routes[name] = { render, init };
  }

  // Parse hash
  function parseHash() {
    const hash = location.hash.replace(/^#\/?/, '');
    const [name, queryString] = hash.split('?');
    const params = {};
    if (queryString) {
      new URLSearchParams(queryString).forEach((v, k) => (params[k] = v));
    }
    return { name: name || 'login', params };
  }

  // Render current
  function renderCurrent() {
    const { name, params } = parseHash();
    const route = routes[name] || routes['login'];
    current = name in routes ? name : 'login';

    const app = document.getElementById('app');
    app.innerHTML = route.render(params);
    if (typeof route.init === 'function') route.init(params);
    window.scrollTo(0, 0);
  }

  // Go router
  function go(name, params = {}) {
    const qs = new URLSearchParams(params).toString();
    location.hash = `#/${name}${qs ? `?${qs}` : ''}`;
  }

  // Start router
  function start() {
    window.addEventListener('hashchange', renderCurrent);
    renderCurrent();
  }

  return { register, go, start, get current() { return current; } };
})();
