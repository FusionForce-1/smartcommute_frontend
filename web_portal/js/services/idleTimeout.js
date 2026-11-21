// Idle sign-out
const IdleTimeout = (() => {
  const IDLE_MS = 30 * 60 * 1000;
  const WARN_MS = 60 * 1000;
  const EVENTS = ['mousemove', 'mousedown', 'keydown', 'touchstart', 'scroll', 'wheel'];
  const KEY = 'smartcommute.session';

  let lastActive = Date.now();
  let timer = null;
  let banner = null;
  let onExpire = null;

  // Remembered sign-in?
  function remembered() {
    try {
      return Boolean(localStorage.getItem(KEY));
    } catch {
      return false;
    }
  }

  // Note activity
  function activity() {
    if (banner) return;
    lastActive = Date.now();
  }

  // Hide warning
  function hideWarning() {
    banner?.remove();
    banner = null;
  }

  // Show warning
  function showWarning(secondsLeft) {
    if (!banner) {
      banner = document.createElement('div');
      banner.className = 'toast toast--action';
      banner.setAttribute('role', 'alertdialog');
      banner.style.cssText = 'position:fixed;left:50%;bottom:24px;transform:translateX(-50%);z-index:3000;'
        + 'display:flex;gap:12px;align-items:center;';
      banner.innerHTML = '<span data-idle-text></span><button type="button" class="btn-sm btn-sm--teal" data-idle-stay>Stay signed in</button>';
      banner.querySelector('[data-idle-stay]').addEventListener('click', () => {
        hideWarning();
        lastActive = Date.now();
      });
      document.body.appendChild(banner);
    }
    banner.querySelector('[data-idle-text]').textContent =
      `You will be signed out in ${secondsLeft} s because of no activity.`;
  }

  // Check idle time
  async function tick() {
    const idle = Date.now() - lastActive;
    if (idle >= IDLE_MS) {
      stop();
      hideWarning();
      await onExpire?.();
      return;
    }
    if (idle >= IDLE_MS - WARN_MS) showWarning(Math.ceil((IDLE_MS - idle) / 1000));
    else hideWarning();
  }

  // Stop watching
  function stop() {
    clearInterval(timer);
    timer = null;
    EVENTS.forEach((e) => window.removeEventListener(e, activity, true));
  }

  // Start watching
  function start(expire) {
    if (remembered() || timer) return false;
    onExpire = expire;
    lastActive = Date.now();
    EVENTS.forEach((e) => window.addEventListener(e, activity, { capture: true, passive: true }));
    timer = setInterval(tick, 1000);
    return true;
  }

  return { start, stop, IDLE_MS, WARN_MS, _tick: tick, _idleFor: (ms) => { lastActive = Date.now() - ms; } };
})();
