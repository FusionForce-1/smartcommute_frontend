// js/admin/adminRouter.js
//
// Hash router for the admin portal (#/dashboard, #/users, ...).
// Each view registers { title, mount(el) }. mount() may return a cleanup
// function (e.g. to stop a polling timer) that runs before the next view.

const AdminRouter = (() => {
  const views = {};
  const DEFAULT_VIEW = 'dashboard';
  let cleanup = null;
  let onChange = () => {};

  function register(name, view) {
    views[name] = view;
  }

  function currentName() {
    const name = location.hash.replace(/^#\/?/, '');
    return views[name] ? name : DEFAULT_VIEW;
  }

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

  /** @param {(name: string) => void} onRouteChange — e.g. highlight the nav */
  function start(onRouteChange) {
    onChange = onRouteChange || onChange;
    window.addEventListener('hashchange', render);
    render();
  }

  return { register, start, refresh: render };
})();
