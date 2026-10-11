// js/views/register.js
//
// Operator registration. Collects Full Name, Email, Contact Number,
// Company Name, Franchise Number, Password. Google complete-profile overlay
// matches OPERATOR_GOOGLE.png.

Router.register('register', {
  render() {
    return `
      <div class="auth-page">
        <div class="split-bg">
          <div class="split-bg__top"></div>
          <div class="split-bg__content">
            ${Components.brandHeader({ tagline: "Operator's Registration" })}
            <div class="split-bg__center">
              <div class="auth-card auth-card--register">
                <h1 class="auth-card__title">Register Now</h1>
                <p class="auth-card__subtitle">Create your account to get started.</p>

                ${Components.errorBanner({ id: 'register-error', message: 'Passwords do not match.' })}

                ${Components.button({ id: 'register-google', label: 'Continue with Google', variant: 'google' })}
                ${Components.orDivider()}

                <form id="register-form" novalidate>
                  ${Components.field({ id: 'register-full-name', label: 'Full name', placeholder: 'Enter your firstname' })}
                  ${Components.field({ id: 'register-email', label: 'Email Address', type: 'email', placeholder: 'Enter your email' })}
                  ${Components.field({ id: 'register-contact', label: 'Contact Number', type: 'tel', placeholder: 'Enter contact number' })}
                  ${Components.field({ id: 'register-company', label: 'Company Name', placeholder: 'Enter the company name' })}
                  ${Components.field({ id: 'register-franchise', label: 'Franchise Number', placeholder: 'Enter franchise number' })}
                  ${Components.field({ id: 'register-password', label: 'Password', type: 'password', placeholder: 'Enter your password', withToggle: true })}
                  ${Components.field({ id: 'register-repeat-password', label: 'Repeat Password', type: 'password', placeholder: 'Enter your repeat password', withToggle: true })}

                  ${Components.button({ id: 'register-submit', label: 'Register', variant: 'primary', type: 'submit' })}
                </form>

                ${Components.bottomLinkRow({ prompt: 'Have an account?', linkText: 'Login', href: '#/login' })}
              </div>
            </div>
          </div>
        </div>
      </div>`;
  },

  init() {
    wirePasswordToggle('register-password');
    wirePasswordToggle('register-repeat-password');

    function showRegisterError(message) {
      const banner = document.querySelector('#register-error .error-banner__text');
      if (banner) banner.textContent = message;
      showError('register-error');
    }

    const value = (id) => document.getElementById(id).value.trim();

    document.getElementById('register-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      hideError('register-error');

      const name = value('register-full-name');
      const email = value('register-email');
      const password = document.getElementById('register-password').value;
      const repeatPassword = document.getElementById('register-repeat-password').value;
      const profile = {
        company_name: value('register-company'),
        franchise_number: value('register-franchise'),
        contact_number: value('register-contact'),
      };

      const problem = validateRegistration({ name, email, password, repeatPassword, profile });
      if (problem) {
        showRegisterError(problem);
        return;
      }

      const submit = document.getElementById('register-submit');
      submit.disabled = true;
      try {
        await AuthModule.registerOperator({ name, email, password, profile });
        Router.go('login', { registered: '1' });
      } catch (err) {
        showRegisterError(err.message || 'Registration failed.');
      } finally {
        submit.disabled = false;
      }
    });

    GoogleAuth.attach(document.getElementById('register-google'), {
      onError: (err) => showRegisterError(err.message),
      onCredential: async (idToken) => {
        hideError('register-error');
        try {
          const result = await AuthModule.loginWithGoogle(idToken, {
            role: 'operator',
            email: GoogleAuth.emailFrom(idToken),
          });
          if (result.role !== 'operator') {
            Session.clear();
            throw new Error(`This Google account is already registered as ${result.role}. Use a different account.`);
          }
          // Opens "Complete your Profile" for new operators; returning ones go straight in.
          await PortalRedirect.afterLogin(result.role);
        } catch (err) {
          GoogleAuth.forgetAccount();
          showRegisterError(err.message || 'Google sign-up failed.');
        }
      },
    });
  },
});

/** Returns the first problem with the form, or '' if it is valid. */
function validateRegistration({ name, email, password, repeatPassword, profile }) {
  if (!name || !email || !password || !profile.company_name) {
    return 'Please fill in your name, email, company name and password.';
  }
  if (name.length < 2) return 'Full name must be at least 2 characters.';
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return 'Please enter a valid email address.';
  if (profile.company_name.length < 2) return 'Company name must be at least 2 characters.';
  if (password.length < 6) return 'Password must be at least 6 characters.';
  if (password !== repeatPassword) return 'Passwords do not match.';
  return '';
}

// "Complete your Profile" popup (OPERATOR_GOOGLE.png). Shown to a signed-in
// operator who has no company profile yet: after Google sign-up, or on
// login if the profile step was never finished.
const OperatorProfilePopup = {
  open(email) {
    const html = `
      <button type="button" class="modal-close" id="profile-close" aria-label="Close">
        ${Components.icon('close')}
      </button>
      <h1 class="auth-card__title" style="font-size:28px;text-align:left;">Complete your Profile</h1>
      <p class="auth-card__subtitle" style="text-align:left;">A few more details are needed to register as an Operator.</p>

      <div class="google-account-chip">
        <img src="${GOOGLE_LOGO_SRC}" alt="" width="22" height="22" />
        <div class="google-account-chip__text">
          <span>Signed in as</span>
          <strong>${escapeHtml(email)}</strong>
        </div>
        <button type="button" class="link-inline" id="profile-change">Change</button>
      </div>

      <form id="profile-form" novalidate style="text-align:left;">
        ${Components.field({ id: 'profile-company', label: 'Company Name', placeholder: 'Enter your company name' })}
        ${Components.field({ id: 'profile-franchise', label: 'Franchise Number', placeholder: 'Enter your franchise number' })}
        ${Components.field({ id: 'profile-contact', label: 'Contact Number', type: 'tel', placeholder: 'Enter your contact number' })}
        ${Components.errorBanner({ id: 'profile-error', message: 'Please complete all fields.' })}
        ${Components.button({ id: 'profile-submit', label: 'Register', variant: 'primary', type: 'submit' })}
      </form>
    `;

    // Leaving without finishing signs the user out again.
    const cancel = () => {
      Session.clear();
      GoogleAuth.forgetAccount();
      AuthModal.close();
    };

    function showProfileError(message) {
      document.querySelector('#profile-error .error-banner__text').textContent = message;
      showError('profile-error');
    }

    AuthModal.setContent(html, {
      centered: false,
      onMount: () => {
        document.getElementById('profile-close').addEventListener('click', cancel);
        document.getElementById('profile-change').addEventListener('click', cancel);
        document.getElementById('profile-form').addEventListener('submit', async (e) => {
          e.preventDefault();
          const profile = {
            company_name: document.getElementById('profile-company').value.trim(),
            franchise_number: document.getElementById('profile-franchise').value.trim(),
            contact_number: document.getElementById('profile-contact').value.trim(),
          };
          if (!profile.company_name || !profile.franchise_number || !profile.contact_number) {
            showProfileError('Please complete all fields.');
            return;
          }
          if (profile.company_name.length < 2) {
            showProfileError('Company name must be at least 2 characters.');
            return;
          }
          hideError('profile-error');

          const submit = document.getElementById('profile-submit');
          submit.disabled = true;
          try {
            await AuthModule.createOperatorProfile(profile);
            window.location.href = 'operator/operator.html';
          } catch (err) {
            showProfileError(err.message || 'Registration failed.');
            submit.disabled = false;
          }
        });
      },
    });
  },
};
