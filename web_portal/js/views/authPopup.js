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

      // TODO: Velez — AuthModule.resetPassword → POST /auth/reset-password
      // Collect new_password in a follow-up field if the backend requires it.
      try {
        await AuthModule.resetPassword(email, otp, '');
        AuthModal.close();
        Router.go('login');
      } catch (err) {
        const banner = document.querySelector('#otp-error .error-banner__text');
        if (banner) banner.textContent = err.message || 'Incorrect or expired code. Try again.';
        showError('otp-error');
      }
    });

    document.getElementById('otp-back').addEventListener('click', () => {
      AuthPopup.openForgotPassword();
    });

    document.querySelector('.bottom-link-row a')?.addEventListener('click', () => {
      AuthModal.close();
    });
  }

  function openForgotPassword() {
    AuthModal.setContent(forgotPasswordContent(), { onMount: initForgotPassword });
  }

  function openVerifyOtp(email) {
    AuthModal.setContent(verifyOtpContent(email), { onMount: () => initVerifyOtp(email) });
  }

  return { openForgotPassword, openVerifyOtp };
})();
