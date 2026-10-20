// js/views/authPopup.js
//
// Forgot Password + Verify OTP popup flow launched from Login.

const AuthPopup = (() => {
  function forgotPasswordContent() {
    return `
      ${Components.popupIcon('forgotKey')}
      <h1 class="auth-card__title" style="font-size:28px;">Forgot Password?</h1>
      <p class="auth-card__subtitle">Enter your email and we'll send you an OTP code.</p>

      <form id="forgot-form" novalidate style="text-align:left;">
        ${Components.field({ id: 'forgot-email', label: 'Email Address', type: 'email', placeholder: 'Enter your email address' })}

        ${Components.errorBanner({ id: 'forgot-error', message: 'This email is not registered' })}

        <div class="btn-stack mt-sm">
          ${Components.button({ id: 'forgot-submit', label: 'Send OTP', variant: 'primary', type: 'submit' })}
          ${Components.button({ id: 'forgot-cancel', label: 'Cancel', variant: 'outline', type: 'button' })}
        </div>
      </form>
      ${Components.bottomLinkRow({ prompt: "Don't have an account?", linkText: 'Register', href: '#/register' })}`;
  }

  function initForgotPassword() {
    document.getElementById('forgot-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const email = document.getElementById('forgot-email').value.trim();
      hideError('forgot-error');

      // TODO: Velez — AuthModule.forgotPassword(email) → POST /auth/forgot-password
      // Mock adapter (Francis) already returns 404 for test@account.com.
      try {
        await AuthModule.forgotPassword(email);
        AuthPopup.openVerifyOtp(email);
      } catch (err) {
        const banner = document.querySelector('#forgot-error .error-banner__text');
        if (banner) banner.textContent = err.message || 'This email is not registered';
        showError('forgot-error');
      }
    });

    document.getElementById('forgot-cancel').addEventListener('click', () => {
      AuthModal.close();
    });

    document.querySelector('.bottom-link-row a')?.addEventListener('click', () => {
      AuthModal.close();
    });
  }

  function verifyOtpContent(email) {
    return `
      ${Components.popupIcon('otpEnvelope')}
      <h1 class="auth-card__title" style="font-size:28px;">Enter OTP</h1>
      <p class="auth-card__subtitle">We sent a 6-digit code to <strong>${escapeHtml(email)}</strong></p>

      <form id="otp-form" novalidate style="text-align:left;">
        ${Components.field({ id: 'otp-code', label: 'OTP Code', type: 'text', placeholder: 'Enter 6 - digit code' })}

        ${Components.errorBanner({ id: 'otp-error', message: 'Incorrect or expired code. Try again.' })}

        <div class="btn-stack mt-sm">
          ${Components.button({ id: 'otp-submit', label: 'Verify OTP', variant: 'primary', type: 'submit' })}
          ${Components.button({ id: 'otp-back', label: '← Back', variant: 'outline', type: 'button' })}
        </div>
      </form>
      ${Components.bottomLinkRow({ prompt: "Don't have an account?", linkText: 'Register', href: '#/register' })}`;
  }

  function initVerifyOtp(email) {
    document.getElementById('otp-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const otp = document.getElementById('otp-code').value.trim();

      if (otp.length !== 6) {
        showError('otp-error');
        return;
      }
      hideError('otp-error');

      // The backend checks the code together with the new password, so the
      // code is carried to the next step rather than sent here.
      AuthPopup.openSetNewPassword(email, otp);
    });

    document.getElementById('otp-back').addEventListener('click', () => {
      AuthPopup.openForgotPassword();
    });

    document.querySelector('.bottom-link-row a')?.addEventListener('click', () => {
      AuthModal.close();
    });
  }

  function setNewPasswordContent() {
    return `
      ${Components.popupIcon('forgotKey')}
      <h1 class="auth-card__title" style="font-size:28px;">Set New Password</h1>
      <p class="auth-card__subtitle">Choose a new password for your account.</p>

      <form id="new-password-form" novalidate style="text-align:left;">
        ${Components.field({ id: 'new-password', label: 'New Password', type: 'password', placeholder: 'Enter your new password', withToggle: true })}
        ${Components.field({ id: 'new-password-repeat', label: 'Repeat Password', type: 'password', placeholder: 'Repeat your new password', withToggle: true })}

        ${Components.errorBanner({ id: 'new-password-error', message: 'Passwords do not match.' })}

        <div class="btn-stack mt-sm">
          ${Components.button({ id: 'new-password-submit', label: 'Reset Password', variant: 'primary', type: 'submit' })}
          ${Components.button({ id: 'new-password-back', label: '← Back', variant: 'outline', type: 'button' })}
        </div>
      </form>`;
  }

  function initSetNewPassword(email, otp) {
    wirePasswordToggle('new-password');
    wirePasswordToggle('new-password-repeat');

    const showPasswordError = (message) => {
      const banner = document.querySelector('#new-password-error .error-banner__text');
      if (banner) banner.textContent = message;
      showError('new-password-error');
    };

    document.getElementById('new-password-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const password = document.getElementById('new-password').value;
      const repeatPassword = document.getElementById('new-password-repeat').value;

      if (password.length < 6) {
        showPasswordError('Password must be at least 6 characters.');
        return;
      }
      if (password !== repeatPassword) {
        showPasswordError('Passwords do not match.');
        return;
      }
      hideError('new-password-error');

      // A wrong or expired code is only caught here, by POST /auth/reset-password.
      try {
        await AuthModule.resetPassword(email, otp, password);
        AuthModal.close();
        Router.go('login');
      } catch (err) {
        showPasswordError(err.message || 'Incorrect or expired code. Go back and request a new one.');
      }
    });

    document.getElementById('new-password-back').addEventListener('click', () => {
      AuthPopup.openVerifyOtp(email);
    });
  }

  // ---------- Two-factor sign-in ----------

  function signInCodeContent(sentTo) {
    return `
      ${Components.popupIcon('otpEnvelope')}
      <h1 class="auth-card__title" style="font-size:28px;">Verify Sign-in</h1>
      <p class="auth-card__subtitle">Two-factor authentication is on. We sent a 6-digit code to <strong>${escapeHtml(sentTo)}</strong></p>

      <form id="signin-code-form" novalidate style="text-align:left;">
        ${Components.field({ id: 'signin-code', label: 'Sign-in Code', type: 'text', placeholder: 'Enter 6 - digit code' })}

        ${Components.errorBanner({ id: 'signin-code-error', message: 'Incorrect or expired code. Try again.' })}

        <div class="btn-stack mt-sm">
          ${Components.button({ id: 'signin-code-submit', label: 'Verify', variant: 'primary', type: 'submit' })}
          ${Components.button({ id: 'signin-code-cancel', label: 'Cancel', variant: 'outline', type: 'button' })}
        </div>
      </form>`;
  }

  function initSignInCode({ email, rememberMe }) {
    const showCodeError = (message) => {
      const banner = document.querySelector('#signin-code-error .error-banner__text');
      if (banner) banner.textContent = message;
      showError('signin-code-error');
    };

    document.getElementById('signin-code-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const otp = document.getElementById('signin-code').value.trim();
      if (!/^\d{6}$/.test(otp)) {
        showCodeError('Enter the 6-digit code from your email.');
        return;
      }
      hideError('signin-code-error');
      try {
        const result = await AuthModule.verifyLoginCode(email, otp, rememberMe);
        AuthModal.close();
        await PortalRedirect.afterLogin(result.role);
      } catch (err) {
        showCodeError(err.message || 'Incorrect or expired code. Try again.');
      }
    });

    document.getElementById('signin-code-cancel').addEventListener('click', () => AuthModal.close());
  }

  /** @param {{email, sentTo, rememberMe}} opts — sentTo is the masked address */
  function openSignInCode(opts) {
    AuthModal.setContent(signInCodeContent(opts.sentTo || opts.email), {
      onMount: () => initSignInCode(opts),
    });
  }

  function openForgotPassword() {
    AuthModal.setContent(forgotPasswordContent(), { onMount: initForgotPassword });
  }

  function openVerifyOtp(email) {
    AuthModal.setContent(verifyOtpContent(email), { onMount: () => initVerifyOtp(email) });
  }

  function openSetNewPassword(email, otp) {
    AuthModal.setContent(setNewPasswordContent(), { onMount: () => initSetNewPassword(email, otp) });
  }

  return { openForgotPassword, openVerifyOtp, openSetNewPassword, openSignInCode };
})();
