// js/views/login.js
//
// Operator / Admin web login. UI by Emae; HTTP by Velez (AuthModule).

Router.register('login', {
  render() {
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

    document.getElementById('login-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      hideError('login-error');
      const email = document.getElementById('login-email').value.trim();
      const password = document.getElementById('login-password').value;
      const rememberMe = document.getElementById('login-remember').checked;

      // TODO [Velez]: AuthModule.login → POST /auth/login, persist session
      try {
        const result = await AuthModule.login(email, password, rememberMe);
        const role = result?.role || 'operator';
        if (role === 'admin') {
          window.location.href = '../admin/index.html';
        } else {
          window.location.href = '../operator/index.html';
        }
      } catch (err) {
        const banner = document.querySelector('#login-error span');
        if (banner) banner.textContent = err.message || 'Invalid email or password.';
        showError('login-error');
      }
    });

    document.getElementById('login-google').addEventListener('click', async () => {
      // TODO [Velez]: GIS id_token, then AuthModule.loginWithGoogle → POST /auth/google
      try {
        const result = await AuthModule.loginWithGoogle();
        const role = result?.role || 'operator';
        window.location.href = role === 'admin'
          ? '../admin/index.html'
          : '../operator/index.html';
      } catch (err) {
        alert(err.message || 'Google sign-in failed.');
      }
    });
  },
});
