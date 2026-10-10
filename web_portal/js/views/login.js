// js/views/login.js
//
// Operator / Admin web login. UI by Emae; HTTP by Velez (AuthModule).

Router.register('login', {
  render(params = {}) {
    return `
      <div class="auth-page">
        <div class="split-bg">
          <div class="split-bg__top"></div>
          <div class="split-bg__content">
            ${Components.brandHeader()}
            <div class="split-bg__center">
              <div class="auth-card">
                <h1 class="auth-card__title">Login Now</h1>
                <p class="auth-card__subtitle">Welcome back — enter your credentials to continue</p>

                ${params.registered ? `
                  <div class="error-banner error-banner--success">
                    ${iconMarkup('circle-check')}<span>Registration complete. An admin will review your operator account — you can log in now.</span>
                  </div>` : ''}
                ${Components.errorBanner({ id: 'login-error', message: 'Invalid email or password.' })}

                ${Components.button({ id: 'login-google', label: 'Continue with Google', variant: 'google' })}
                ${Components.orDivider()}

                <form id="login-form" novalidate>
                  ${Components.field({ id: 'login-email', label: 'Email', type: 'email', placeholder: 'Enter your email' })}
                  ${Components.field({ id: 'login-password', label: 'Password', type: 'password', placeholder: 'Enter your password', withToggle: true })}

                  <div class="options-row">
                    <label class="checkbox-label">
                      <input type="checkbox" id="login-remember" />
                      Remember Me
                    </label>
                    <a href="#" id="login-forgot-link" class="link-inline">Forgot Password?</a>
                  </div>

                  ${Components.button({ id: 'login-submit', label: 'Login', variant: 'primary', type: 'submit' })}
                </form>

                ${Components.bottomLinkRow({
                  prompt: "Don't have an account?",
                  linkText: 'Register as Operator',
                  href: '#/register',
                })}
              </div>
            </div>
          </div>
        </div>
      </div>`;
  },

  init() {
    wirePasswordToggle('login-password');

    document.getElementById('login-forgot-link').addEventListener('click', (e) => {
      e.preventDefault();
      AuthPopup.openForgotPassword();
    });

    function showLoginError(message) {
      const banner = document.querySelector('#login-error .error-banner__text');
      if (banner) banner.textContent = message || 'Invalid email or password.';
      showError('login-error');
    }

    document.getElementById('login-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      hideError('login-error');
      const email = document.getElementById('login-email').value.trim();
      const password = document.getElementById('login-password').value;
      const rememberMe = document.getElementById('login-remember').checked;

      if (!email || !password) {
        showLoginError('Please enter your email and password.');
        return;
      }

      try {
        const result = await AuthModule.login(email, password, rememberMe);
        if (result.two_factor_required) {
          AuthPopup.openSignInCode({ email, sentTo: result.email, rememberMe });
          return;
        }
        await PortalRedirect.afterLogin(result.role);
      } catch (err) {
        showLoginError(err.message);
      }
    });

    GoogleAuth.attach(document.getElementById('login-google'), {
      onError: (err) => showLoginError(err.message),
      onCredential: async (idToken) => {
        hideError('login-error');
        try {
          const result = await AuthModule.loginWithGoogle(idToken, {
            email: GoogleAuth.emailFrom(idToken),
            rememberMe: document.getElementById('login-remember').checked,
          });
          await PortalRedirect.afterLogin(result.role);
        } catch (err) {
          GoogleAuth.forgetAccount();
          showLoginError(err.message || 'Google sign-in failed.');
        }
      },
    });
  },
});

// Sends a signed-in user to the right portal. Shared by Login and Register.
const PortalRedirect = {
  /**
   * Admin → admin portal. Operator → operator portal, after collecting the
   * company profile if it was never saved. Anyone else is signed back out:
   * commuters and drivers use the mobile app.
   */
  async afterLogin(role) {
    if (role === 'admin') {
      window.location.href = 'admin/index.html';
      return;
    }
    if (role !== 'operator') {
      Session.clear();
      throw new Error('This portal is for operators and admins. Please use the Smart Commute mobile app.');
    }

    const profile = await AuthModule.getMyOperatorProfile();
    if (profile) {
      window.location.href = 'operator/index.html';
    } else {
      OperatorProfilePopup.open(Session.email);
    }
  },
};
