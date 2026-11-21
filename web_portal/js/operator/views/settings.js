// Operator settings view
OperatorRouter.register('settings', {
  title: 'Settings',
  heading: 'Settings',

  // Mount the view
  mount(el) {
    const esc = AdminUi.escapeHtml;
    const LANGUAGES = { 'en-PH': 'English (Philippines)' };
    let settings = null;
    let security = null;
    let saving = false;

    el.innerHTML = `
      <div class="op-narrow">
        <div class="op-page-head"><div><h2>Settings</h2></div></div>
        <section class="op-card op-card--flush" id="settings-card"></section>
      </div>`;

    const cardEl = el.querySelector('#settings-card');

    // Toggle settings
    function toggle(id, checked) {
      return `
        <label class="op-switch">
          <input type="checkbox" role="switch" id="${id}" ${checked ? 'checked' : ''} ${saving ? 'disabled' : ''} />
          <span class="op-switch__track"></span>
        </label>`;
    }

    // Password row
    function passwordRow() {
      if (!security.has_password) {
        return `
          <div class="op-setting">
            <div>
              <strong>Password</strong>
              <span>You sign in with Google. To set a password, sign out and use Forgot Password on the sign-in page.</span>
            </div>
          </div>`;
      }
      return `
        <div class="op-setting">
          <div>
            <strong>Password</strong>
            <span>Change the password you sign in with</span>
          </div>
          <button type="button" class="op-btn op-btn--outline" id="set-password" ${saving ? 'disabled' : ''}>Change</button>
        </div>`;
    }

    // Two factor row
    function twoFactorRow(s) {
      if (security.two_factor_blocked && !s.two_factor_enabled) {
        return `
          <div class="op-setting">
            <div>
              <strong>Two-Factor Authentication</strong>
              <span>${esc(security.two_factor_blocked)}</span>
            </div>
          </div>`;
      }
      return `
        <div class="op-setting">
          <div>
            <strong>Two-Factor Authentication</strong>
            <span>${s.two_factor_enabled ? 'On — a code is emailed when you sign in with your password' : 'Extra security for your account'}</span>
          </div>
          ${toggle('set-2fa', s.two_factor_enabled)}
        </div>`;
    }

    // Render the view
    function render() {
      const s = settings;
      cardEl.innerHTML = `
        <div class="op-setting">
          <div>
            <strong>Email Notifications</strong>
            <span>Emails about driver emergencies, suspended vehicles and your account</span>
          </div>
          ${toggle('set-email', s.email_notifications)}
        </div>
        ${passwordRow()}
        ${twoFactorRow(s)}
        <div class="op-setting">
          <div>
            <strong>Language</strong>
            <span>${esc(LANGUAGES[s.language] || s.language)}</span>
          </div>
          <select id="set-language" aria-label="Language" ${saving ? 'disabled' : ''}>
            ${Object.entries(LANGUAGES).map(([code, label]) => `
              <option value="${esc(code)}"${code === s.language ? ' selected' : ''}>${esc(label)}</option>`).join('')}
          </select>
        </div>`;
    }

    // Save settings
    async function save(request, doneMessage) {
      saving = true;
      render();
      try {
        settings = await request();
        AdminUi.toast(doneMessage);
      } catch (err) {
        AdminUi.toast(err.message || 'Unable to save your settings.', { error: true });
      } finally {
        saving = false;
        render();
      }
    }


    // Open change password
    function openChangePassword() {
      // Settings field
      const field = (id, label, autocomplete) => `
        <div class="form-field">
          <label for="${id}">${label}</label>
          <input id="${id}" type="password" autocomplete="${autocomplete}" />
        </div>`;
      AdminModal.open({
        title: 'Change password',
        size: 'sm',
        body: `
          ${field('pw-current', 'Current password', 'current-password')}
          ${field('pw-new', 'New password', 'new-password')}
          ${field('pw-repeat', 'Repeat new password', 'new-password')}`,
        actions: [
          { label: 'Cancel', variant: 'ghost', onClick: AdminModal.close },
          {
            label: 'Change Password',
            variant: 'primary',
            onClick: async (m) => {
              const current = m.querySelector('#pw-current').value;
              const next = m.querySelector('#pw-new').value;
              if (!current || !next) throw new Error('Fill in your current and new password.');
              const problem = PasswordRule.problem(next);
              if (problem) throw new Error(`New password: ${problem}`);
              if (next !== m.querySelector('#pw-repeat').value) throw new Error('New passwords do not match.');
              await OperatorApi.changePassword(current, next);
              AdminModal.close();
              AdminUi.toast('Your password was changed.');
            },
          },
        ],
      });
    }


    // Open enable two factor
    function openEnableTwoFactor() {
      const modal = AdminModal.open({
        title: 'Turn on two-factor authentication',
        size: 'sm',
        body: `
          <p class="modal-text" id="tf-text">Sending a code to your email…</p>
          <input class="op-code-input" id="tf-code" inputmode="numeric" maxlength="6" placeholder="000000"
            autocomplete="one-time-code" disabled style="margin-top:14px;" />
          <button type="button" class="op-text-btn op-text-btn--blue" id="tf-resend" style="margin-top:8px;padding-left:0;" disabled>
            Send a new code
          </button>`,
        actions: [
          { label: 'Cancel', variant: 'ghost', onClick: AdminModal.close },
          {
            label: 'Turn On',
            variant: 'primary',
            onClick: async (m) => {
              const otp = m.querySelector('#tf-code').value.trim();
              if (!/^\d{6}$/.test(otp)) throw new Error('Enter the 6-digit code from your email.');
              settings = await OperatorApi.confirmTwoFactor(otp);
              AdminModal.close();
              render();
              AdminUi.toast('Two-factor authentication is on.');
            },
          },
        ],
      });

      const textEl = modal.querySelector('#tf-text');
      const codeEl = modal.querySelector('#tf-code');
      const resendBtn = modal.querySelector('#tf-resend');
      const errorEl = modal.querySelector('.admin-modal__error');

      codeEl.addEventListener('input', () => {
        codeEl.value = codeEl.value.replace(/\D/g, '').slice(0, 6);
      });

      // Send code
      async function sendCode() {
        resendBtn.disabled = true;
        codeEl.disabled = true;
        errorEl.hidden = true;
        textEl.textContent = 'Sending a code to your email…';
        try {
          const { email } = await OperatorApi.startTwoFactor();
          textEl.textContent = `Enter the 6-digit code we sent to ${email}. You will also need a code like this each time you sign in.`;
          codeEl.disabled = false;
          codeEl.focus();
        } catch (err) {
          textEl.textContent = 'We need to email you a code to confirm this change.';
          errorEl.textContent = err.message || 'Unable to send the code.';
          errorEl.hidden = false;
        } finally {
          resendBtn.disabled = false;
        }
      }

      resendBtn.addEventListener('click', sendCode);
      sendCode();
    }

    // Confirm disable two factor
    function confirmDisableTwoFactor() {
      const withPassword = security.has_password;
      AdminModal.open({
        title: 'Turn off two-factor authentication?',
        size: 'sm',
        body: `
          <p class="modal-text">You will sign in with just your password. Your account will be less protected if your password is ever leaked.</p>
          <p id="tf-off-help">${withPassword ? 'Enter your current password to confirm.'
            : 'You sign in with Google, so we will email you a code to confirm.'}</p>
          <div class="form-field">
            <label for="tf-off-secret">${withPassword ? 'Current password' : '6-digit code'}</label>
            <input id="tf-off-secret" type="${withPassword ? 'password' : 'text'}"
              autocomplete="${withPassword ? 'current-password' : 'one-time-code'}" ${withPassword ? '' : 'inputmode="numeric" maxlength="6" disabled'} />
          </div>
          ${withPassword ? '' : '<button type="button" class="op-btn op-btn--outline" id="tf-off-send">Email me a code</button>'}`,
        actions: [
          { label: 'Cancel', variant: 'ghost', onClick: AdminModal.close },
          {
            label: 'Turn Off',
            variant: 'decline',
            onClick: async (m) => {
              const value = m.querySelector('#tf-off-secret').value.trim();
              if (!value) throw new Error(withPassword ? 'Enter your current password.' : 'Enter the code we emailed you.');
              settings = await OperatorApi.updateSettings(withPassword
                ? { two_factor_enabled: false, current_password: m.querySelector('#tf-off-secret').value }
                : { two_factor_enabled: false, otp: value });
              AdminModal.close();
              render();
              AdminUi.toast('Two-factor authentication is off.');
            },
          },
        ],
      });
      const sendBtn = document.getElementById('tf-off-send');
      if (sendBtn) {
        sendBtn.addEventListener('click', async () => {
          sendBtn.disabled = true;
          try {
            const { email } = await OperatorApi.sendTwoFactorOffCode();
            document.getElementById('tf-off-help').textContent = `Enter the code we sent to ${email}.`;
            const input = document.getElementById('tf-off-secret');
            input.disabled = false;
            input.focus();
          } catch (err) {
            AdminUi.toast(err.message || 'Unable to send the code.', { error: true });
          } finally {
            sendBtn.disabled = false;
          }
        });
      }
    }


    cardEl.addEventListener('change', (e) => {
      if (!settings || saving) return;
      const { id } = e.target;
      if (id === 'set-email') {
        const on = e.target.checked;
        save(() => OperatorApi.updateSettings({ email_notifications: on }),
          on ? 'Email notifications turned on.' : 'Email notifications turned off.');
      } else if (id === 'set-2fa') {
        e.target.checked = settings.two_factor_enabled;
        if (settings.two_factor_enabled) confirmDisableTwoFactor();
        else openEnableTwoFactor();
      } else if (id === 'set-language') {
        const language = e.target.value;
        save(() => OperatorApi.updateSettings({ language }), 'Language updated.');
      }
    });

    cardEl.addEventListener('click', (e) => {
      if (e.target.id === 'set-password') openChangePassword();
    });

    // Load settings
    const load = () => Promise.all([OperatorApi.settings(), OperatorApi.security()]);
    AdminUi.loadInto(cardEl, load, ([s, info]) => {
      settings = s;
      security = info;
      render();
    });
  },
});
