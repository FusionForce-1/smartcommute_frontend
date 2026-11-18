// Operator router
// Operator router
const OperatorRouter = (() => {
  const views = {};
  const DEFAULT_VIEW = 'fleet';
  let cleanup = null;
  // On change
  let onChange = () => {};

  // Register operator
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
    const container = document.getElementById('op-view');

    container.innerHTML = '';
    document.title = `${view.title} — Smart Commute Operator`;
    onChange(name, view);
    cleanup = view.mount(container) || null;
    window.scrollTo(0, 0);
  }

  // Start operator
  function start(onRouteChange) {
    onChange = onRouteChange || onChange;
    window.addEventListener('hashchange', render);
    render();
  }

  return { register, start, refresh: render };
})();
