// Admin router
// Admin router
const AdminRouter = (() => {
  const views = {};
  const DEFAULT_VIEW = 'dashboard';
  let cleanup = null;
  // On change
  let onChange = () => {};

  // Register admin
  function register(name, view) {
    views[name] = view;
  }

  // Current name
  function currentName() {
    const name = location.hash.replace(/^#\/?/, '');
    return views[name] ? name : DEFAULT_VIEW;
  }

  // Render the view
  function render() {
    if (typeof cleanup === 'function') cleanup();
    const name = currentName();
    const view = views[name];
    const container = document.getElementById('admin-view');

    container.innerHTML = '';
    document.title = `${view.title} — Smart Commute Admin`;
    onChange(name);
    cleanup = view.mount(container) || null;
    window.scrollTo(0, 0);
  }

  // Start admin
  function start(onRouteChange) {
    onChange = onRouteChange || onChange;
    window.addEventListener('hashchange', render);
    render();
  }

  return { register, start, refresh: render };
})();
