// js/services/googleAuth.js
//
// Google Identity Services (GIS) sign-in for the web portal.
//
// GIS only hands out ID tokens through Google's own rendered button, so
// attach() lays an invisible copy of that button exactly over our styled
// "Continue with Google" button. The user sees our design; the click lands
// on Google's button, which opens the account picker popup.

const GoogleAuth = (() => {
  const SCRIPT_SRC = 'https://accounts.google.com/gsi/client';
  const GSI_BUTTON_WIDTH = 400; // GIS maximum
  const GSI_BUTTON_HEIGHT = 44; // size: 'large'

  let scriptPromise = null;
  let initialized = false;
  let credentialHandler = null;

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

  function initialize() {
    if (initialized) return;
    google.accounts.id.initialize({
      client_id: GOOGLE_CLIENT_ID,
      ux_mode: 'popup',
      callback: (response) => credentialHandler?.(response.credential),
    });
    initialized = true;
  }

  /** Stretches Google's fixed-size button to cover the wrapper exactly. */
  function fitOverlay(wrapper, overlay) {
    const { width, height } = wrapper.getBoundingClientRect();
    if (!width || !height) return;
    overlay.style.transform = `scale(${width / GSI_BUTTON_WIDTH}, ${height / GSI_BUTTON_HEIGHT})`;
  }

  /**
   * Makes `button` start Google sign-in. `onCredential(idToken)` receives
   * the Google ID token to send to POST /auth/google.
   * If GIS can't load, clicking the button calls `onError(err)` instead.
   */
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
    button.tabIndex = -1; // keyboard users reach Google's real button instead

    google.accounts.id.renderButton(overlay, {
      type: 'standard',
      size: 'large',
      text: 'continue_with',
      width: GSI_BUTTON_WIDTH,
    });

    fitOverlay(wrapper, overlay);
    new ResizeObserver(() => fitOverlay(wrapper, overlay)).observe(wrapper);
  }

  /** Reads the email out of a Google ID token (display only — the backend verifies it). */
  function emailFrom(credential) {
    try {
      const payload = credential.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
      return JSON.parse(atob(payload)).email || '';
    } catch {
      return '';
    }
  }

  /** Stops GIS from silently re-selecting the same account next time. */
  function forgetAccount() {
    window.google?.accounts?.id?.disableAutoSelect();
  }

  return { attach, emailFrom, forgetAccount };
})();
