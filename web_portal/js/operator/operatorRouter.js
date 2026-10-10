// js/operator/operatorRouter.js
//
// Hash router for the operator portal (#/fleet, #/routes, ...).
// Each view registers { title, mount(el) }. mount() may return a cleanup
// function (e.g. to stop polling or close a socket) that runs before the
// next view mounts.

const OperatorRouter = (() => {
  const views = {};
  const DEFAULT_VIEW = 'fleet';
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
    const container = document.getElementById('op-view');

    container.innerHTML = '';
    document.title = `${view.title} — Smart Commute Operator`;
    onChange(name, view);
    cleanup = view.mount(container) || null;
    window.scrollTo(0, 0);
  }

  /** @param {(name: string, view: object) => void} onRouteChange — e.g. highlight the nav */
  function start(onRouteChange) {
    onChange = onRouteChange || onChange;
    window.addEventListener('hashchange', render);
    render();
  }

  return { register, start, refresh: render };
})();
