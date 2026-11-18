// Services Google auth
// Google auth
const GoogleAuth = (() => {
  const SCRIPT_SRC = 'https://accounts.google.com/gsi/client';
  const GSI_BUTTON_WIDTH = 400;
  const GSI_BUTTON_HEIGHT = 44;

  let scriptPromise = null;
  let initialized = false;
  let credentialHandler = null;

  // Load script
  function loadScript() {
    if (window.google?.accounts?.id) return Promise.resolve();
    scriptPromise ??= new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = SCRIPT_SRC;
      script.async = true;
      script.onload = resolve;
      script.onerror = () => {
        scriptPromise = null;
        reject(new Error('Could not load Google Sign-In. Check your internet connection.'));
      };
      document.head.appendChild(script);
    });
    return scriptPromise;
  }

  // Google auth initialize
  function initialize() {
    if (initialized) return;
    google.accounts.id.initialize({
      client_id: GOOGLE_CLIENT_ID,
      ux_mode: 'popup',
      callback: (response) => credentialHandler?.(response.credential),
    });
    initialized = true;
  }

  // Fit overlay
  function fitOverlay(wrapper, overlay) {
    const { width, height } = wrapper.getBoundingClientRect();
    if (!width || !height) return;
    overlay.style.transform = `scale(${width / GSI_BUTTON_WIDTH}, ${height / GSI_BUTTON_HEIGHT})`;
  }

  // Attach Google auth
  async function attach(button, { onCredential, onError }) {
    credentialHandler = onCredential;

    try {
      await loadScript();
      initialize();
    } catch (err) {
      button.addEventListener('click', () => onError(err));
      return;
    }

    const wrapper = document.createElement('div');
    wrapper.className = 'google-signin';
    button.replaceWith(wrapper);
    wrapper.appendChild(button);

    const overlay = document.createElement('div');
    overlay.className = 'google-signin__overlay';
    overlay.setAttribute('aria-hidden', 'true');
    wrapper.appendChild(overlay);
    button.tabIndex = -1;

    google.accounts.id.renderButton(overlay, {
      type: 'standard',
      size: 'large',
      text: 'continue_with',
      width: GSI_BUTTON_WIDTH,
    });

    fitOverlay(wrapper, overlay);
    new ResizeObserver(() => fitOverlay(wrapper, overlay)).observe(wrapper);
  }

  // Email from
  function emailFrom(credential) {
    try {
      const payload = credential.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
      return JSON.parse(atob(payload)).email || '';
    } catch {
      return '';
    }
  }

  // Forget account
  function forgetAccount() {
    window.google?.accounts?.id?.disableAutoSelect();
  }

  return { attach, emailFrom, forgetAccount };
})();
