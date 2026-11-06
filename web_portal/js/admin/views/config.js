// js/admin/views/config.js
//
// Config: the settings an administrator can change (GET/PATCH /system/config),
// which apply as soon as they are saved, and a read-only summary of how the
// server is set up. Secrets are never sent here, only whether they are set.

AdminRouter.register('config', {
  title: 'Config',

  mount(el) {
    const esc = AdminUi.escapeHtml;
    let config = null;
    let saving = false;

    el.innerHTML = '<div id="config-root"></div>';
    const rootEl = el.querySelector('#config-root');

    const allSettings = () => config.groups.flatMap((g) => g.settings);

    function settingRow(s) {
      const changedFromDefault = s.value !== s.default;
      return `
        <div class="config-row">
          <label class="config-row__text" for="cfg-${esc(s.key)}">
            <strong>${esc(s.label)}</strong>
            <span>${esc(s.help)}</span>
            <span class="config-row__default">
              ${changedFromDefault ? `Default: ${s.default} ${esc(s.unit)}` : 'Using the default'}
            </span>
          </label>
          <div class="config-row__control">
            <input id="cfg-${esc(s.key)}" type="number" inputmode="numeric" step="1"
              min="${s.min}" max="${s.max}" value="${s.value}" data-key="${esc(s.key)}" />
            <span class="config-row__unit">${esc(s.unit)}</span>
          </div>
        </div>`;
    }

    function infoPanel() {
      const changed = config.updated_at
        ? `<p class="panel__meta">Settings last changed ${esc(AdminUi.formatDateTime(config.updated_at))}${
          config.updated_by ? ` by ${esc(config.updated_by)}` : ''}.</p>`
        : '';
      return `
        <section class="panel">
          <header class="panel__head">
            <h2 class="panel__title">Server Setup</h2>
            <p class="panel__subtitle">Set on the server, so these can't be changed here.</p>
          </header>
          <div class="panel__body">
            <dl class="config-info">
              ${config.info.map((i) => `
                <div class="config-info__row">
                  <dt>${esc(i.label)}</dt>
                  <dd>${esc(i.value)}</dd>
                </div>`).join('')}
            </dl>
            <div class="config-email">
              <button type="button" class="btn-sm btn-sm--teal" id="config-test-email">Send test email</button>
              <span>Sends a message to your own email, to prove this server can deliver mail.</span>
            </div>
            ${changed}
          </div>
        </section>`;
    }

    function render() {
      rootEl.innerHTML = `
        <form class="panel-stack" id="config-form" novalidate>
          ${config.groups.map((group) => `
            <section class="panel">
              <header class="panel__head">
                <h2 class="panel__title">${esc(group.title)}</h2>
              </header>
              <div class="panel__body panel__body--flush">
                ${group.settings.map(settingRow).join('')}
              </div>
            </section>`).join('')}
          <div class="config-actions">
            <span id="config-dirty" aria-live="polite"></span>
            <button type="button" class="btn-lg btn-lg--ghost" id="config-discard" disabled>Discard</button>
            <button type="submit" class="btn-lg btn-lg--primary" id="config-save" disabled>Save Changes</button>
          </div>
          ${infoPanel()}
        </form>`;
    }

    /** The settings whose field differs from the saved value, as { key: number }. */
    function changes() {
      const changed = {};
      allSettings().forEach((s) => {
        const raw = rootEl.querySelector(`[data-key="${s.key}"]`).value.trim();
        if (raw !== String(s.value)) changed[s.key] = raw === '' ? NaN : Number(raw);
      });
      return changed;
    }

    function refreshActions() {
      const count = Object.keys(changes()).length;
      rootEl.querySelector('#config-save').disabled = saving || count === 0;
      rootEl.querySelector('#config-discard').disabled = saving || count === 0;
      rootEl.querySelector('#config-dirty').textContent = count
        ? `${count} unsaved ${count === 1 ? 'change' : 'changes'}`
        : '';
    }

    /** The first change that is outside its limits, or null. */
    function firstProblem(changed) {
      return allSettings().find((s) => {
        if (!(s.key in changed)) return false;
        const value = changed[s.key];
        return !Number.isInteger(value) || value < s.min || value > s.max;
      }) || null;
    }

    async function save() {
      const changed = changes();
      const problem = firstProblem(changed);
      if (problem) {
        AdminUi.toast(`${problem.label} must be a whole number from ${problem.min} to ${problem.max}.`, { error: true });
        rootEl.querySelector(`[data-key="${problem.key}"]`).focus();
        return;
      }
      saving = true;
      refreshActions();
      try {
        config = await AdminApi.updateSystemConfig(changed);
        render();
        AdminUi.toast('Settings saved. They apply right away.');
      } catch (err) {
        AdminUi.toast(err.message || 'Unable to save the settings.', { error: true });
      } finally {
        saving = false;
        refreshActions();
      }
    }

    async function sendTestEmail(button) {
      button.disabled = true;
      button.textContent = 'Sending…';
      try {
        const { sent_to: sentTo } = await AdminApi.sendTestEmail();
        AdminUi.toast(`Test email sent to ${sentTo}. Check that it arrives.`);
      } catch (err) {
        AdminUi.toast(err.message || 'The test email could not be sent.', { error: true, sticky: true });
      } finally {
        button.disabled = false;
        button.textContent = 'Send test email';
      }
    }

    rootEl.addEventListener('input', (e) => {
      if (e.target.matches('[data-key]')) refreshActions();
    });
    rootEl.addEventListener('submit', (e) => {
      e.preventDefault();
      if (!saving) save();
    });
    rootEl.addEventListener('click', (e) => {
      if (e.target.id === 'config-discard') {
        render();
      } else if (e.target.id === 'config-test-email') {
        sendTestEmail(e.target);
      }
    });

    AdminUi.loadInto(rootEl, AdminApi.systemConfig, (data) => {
      config = data;
      render();
    });
  },
});
