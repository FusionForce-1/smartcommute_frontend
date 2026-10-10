// js/operator/views/settings.js
//
// Settings: email notifications, two-factor authentication and language
// (GET/PATCH /users/me/settings). Turning two-factor on emails a code
// that must be confirmed first, so a broken mailbox can't lock anyone out.

OperatorRouter.register('settings', {
  title: 'Settings',
  heading: 'Settings',

  mount(el) {
    const esc = AdminUi.escapeHtml;
    const LANGUAGES = { 'en-PH': 'English (Philippines)' };
    let settings = null;
    let saving = false;

    el.innerHTML = `
      <div class="op-narrow">
        <div class="op-page-head"><div><h2>Settings</h2></div></div>
        <section class="op-card op-card--flush" id="settings-card"></section>
      </div>`;

    const cardEl = el.querySelector('#settings-card');

    function toggle(id, checked) {
      return `
        <label class="op-switch">
          <input type="checkbox" role="switch" id="${id}" ${checked ? 'checked' : ''} ${saving ? 'disabled' : ''} />
          <span class="op-switch__track"></span>
        </label>`;
    }

    function render() {
      const s = settings;
      cardEl.innerHTML = `
        <div class="op-setting">
          <div>
            <strong>Email Notifications</strong>
            <span>Receive alerts and updates via email</span>
          </div>
          ${toggle('set-email', s.email_notifications)}
        </div>
        <div class="op-setting">
          <div>
            <strong>Two-Factor Authentication</strong>
            <span>${s.two_factor_enabled ? 'On — a code is emailed each time you sign in' : 'Extra security for your account'}</span>
          </div>
          ${toggle('set-2fa', s.two_factor_enabled)}
        </div>
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

    // ---------- Two-factor ----------

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

    function confirmDisableTwoFactor() {
      AdminModal.confirm({
        title: 'Turn off two-factor authentication?',
        message: 'You will sign in with just your password. Your account will be less protected if your password is ever leaked.',
        confirmLabel: 'Turn Off',
        onConfirm: async () => {
          settings = await OperatorApi.updateSettings({ two_factor_enabled: false });
          render();
          AdminUi.toast('Two-factor authentication is off.');
        },
      });
    }

    // ---------- Events ----------

    cardEl.addEventListener('change', (e) => {
      if (!settings || saving) return;
      const { id } = e.target;
      if (id === 'set-email') {
        const on = e.target.checked;
        save(() => OperatorApi.updateSettings({ email_notifications: on }),
          on ? 'Email notifications turned on.' : 'Email notifications turned off.');
      } else if (id === 'set-2fa') {
        // The switch only flips once the change is confirmed.
        e.target.checked = settings.two_factor_enabled;
        if (settings.two_factor_enabled) confirmDisableTwoFactor();
        else openEnableTwoFactor();
      } else if (id === 'set-language') {
        const language = e.target.value;
        save(() => OperatorApi.updateSettings({ language }), 'Language updated.');
      }
    });

    AdminUi.loadInto(cardEl, OperatorApi.settings, (s) => {
      settings = s;
      render();
    });
  },
});
