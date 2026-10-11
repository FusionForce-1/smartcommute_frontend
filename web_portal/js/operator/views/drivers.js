// js/operator/views/drivers.js
//
// Drivers: the operator's driver roster. New drivers are added by scanning
// both sides of their LTO license (POST /drivers/scan-license), reviewing
// what was read, and saving (POST /drivers) — which also generates their
// app login, shown once. Profiles can be viewed, edited, and removed.

OperatorRouter.register('drivers', {
  title: 'Drivers',
  heading: 'Driver Management',

  mount(el) {
    const esc = AdminUi.escapeHtml;
    const LICENSE_PATTERN = /^[A-Z]\d{2}-\d{2}-\d{6}$/;
    const MAX_IMAGE_MB = 10;
    const EXPIRING_DAYS = 60;

    // Every editable license field: [key, label, input type, options]
    const FIELDS = [
      ['last_name', 'Last Name', 'text', { required: true }],
      ['first_name', 'First Name', 'text', { required: true }],
      ['middle_name', 'Middle Name', 'text'],
      ['license_number', 'License Number', 'text', { required: true, placeholder: 'G06-23-000951' }],
      ['expiration_date', 'License Expiry', 'date', { required: true }],
      ['date_of_birth', 'Date of Birth', 'date'],
      ['sex', 'Sex', 'select', { choices: [['', '—'], ['M', 'Male'], ['F', 'Female']] }],
      ['nationality', 'Nationality', 'text', { placeholder: 'PHL' }],
      ['blood_type', 'Blood Type', 'text', { placeholder: 'O+' }],
      ['height_m', 'Height (m)', 'number', { step: '0.01', min: '0.5', max: '2.9' }],
      ['weight_kg', 'Weight (kg)', 'number', { step: '0.1', min: '1', max: '499' }],
      ['eyes_color', 'Eye Color', 'text'],
      ['agency_code', 'Agency Code', 'text'],
      ['dl_codes', 'DL Codes', 'text', { placeholder: 'A, B, B1' }],
      ['conditions', 'Conditions', 'text', { placeholder: 'NONE' }],
      ['serial_number', 'Serial Number', 'text'],
      ['address', 'Address', 'text', { full: true }],
    ];

    let drivers;          // undefined = loading
    let fleet = [];

    el.innerHTML = `
      <div class="op-page-head">
        <div>
          <h2>Drivers</h2>
          <p>Add drivers by scanning their license, and keep their records and app logins up to date.</p>
        </div>
        <button type="button" class="op-btn" id="drv-add">＋ Add Driver</button>
      </div>
      <div id="drv-stats"></div>
      <section class="op-card op-card--flush">
        <div class="op-card__head">
          <h3>Driver Roster</h3>
          <p class="op-card__sub" id="drv-count" style="margin:0;"></p>
        </div>
        <div id="drv-table"></div>
      </section>`;

    const statsEl = el.querySelector('#drv-stats');
    const tableEl = el.querySelector('#drv-table');
    const countEl = el.querySelector('#drv-count');

    // ---------- Helpers ----------

    const today = () => new Date(new Date().toDateString());
    const parseDay = (iso) => (iso ? new Date(`${iso}T00:00:00`) : null);
    const daysUntil = (iso) => Math.round((parseDay(iso) - today()) / 86400000);
    const formatDay = (iso) => (iso ? parseDay(iso).toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' }) : '—');

    function licenseState(driver) {
      const days = daysUntil(driver.expiration_date);
      if (days < 0) return { label: 'Expired', tone: 'red' };
      if (days <= EXPIRING_DAYS) return { label: `Expires in ${days}d`, tone: 'amber' };
      return { label: 'Valid', tone: 'green' };
    }

    function vehicleFor(driverId) {
      return fleet.find((v) => v.driver_id === driverId);
    }

    // ---------- Roster ----------

    function renderStats() {
      const loaded = Array.isArray(drivers);
      const count = (fn) => (loaded ? drivers.filter(fn).length : undefined);
      statsEl.innerHTML = OperatorUi.stats([
        ['Total Drivers', loaded ? drivers.length : undefined],
        ['On Duty', count((d) => d.status === 'active'), 'green'],
        ['Off Duty', count((d) => d.status !== 'active'), 'blue'],
        ['Licenses Needing Renewal', count((d) => daysUntil(d.expiration_date) <= EXPIRING_DAYS), 'amber'],
      ]);
    }

    function row(d) {
      const lic = licenseState(d);
      const vehicle = vehicleFor(d.id);
      return `
        <tr>
          <td>
            <div class="data-table__name">${esc(OperatorUi.driverName(d))}</div>
            <div style="color:var(--op-muted);font-size:0.8rem;">${esc(d.driver_code)}</div>
          </td>
          <td>
            <div>${d.email ? esc(d.email) : '<span style="color:var(--op-muted)">No login</span>'}</div>
            <div style="color:var(--op-muted);font-size:0.8rem;">${d.has_signed_in ? 'Signed in to the app' : 'Not signed in yet'}</div>
          </td>
          <td style="font-family:Consolas,'Courier New',monospace;">${esc(d.license_number)}</td>
          <td>${esc(formatDay(d.expiration_date))}<br>${OperatorUi.chip(lic.label, lic.tone)}</td>
          <td>${vehicle ? esc(vehicle.plate_number) : '<span style="color:var(--op-muted)">—</span>'}</td>
          <td>${d.status === 'active' ? OperatorUi.chip('On Duty', 'green') : OperatorUi.chip('Off Duty')}</td>
          <td>
            <div class="data-table__actions">
              <button type="button" class="btn-sm" data-action="view" data-id="${d.id}">View</button>
              <button type="button" class="btn-sm btn-sm--teal" data-action="edit" data-id="${d.id}">Edit</button>
              <button type="button" class="btn-sm" data-action="login" data-id="${d.id}"
                ${d.has_signed_in || !d.email ? 'disabled title="The driver already signed in, so only they can change their login."' : ''}>Login</button>
              <button type="button" class="btn-sm btn-sm--danger" data-action="remove" data-id="${d.id}">Remove</button>
            </div>
          </td>
        </tr>`;
    }

    function renderTable() {
      countEl.textContent = `${drivers.length} registered ${drivers.length === 1 ? 'driver' : 'drivers'}`;
      const rows = drivers.length
        ? drivers.map(row).join('')
        : '<tr><td colspan="7" class="data-table__empty">No drivers yet. Click Add Driver and scan their license.</td></tr>';
      tableEl.innerHTML = `
        <div class="table-wrap">
          <table class="data-table">
            <thead>
              <tr><th>Driver</th><th>App Login</th><th>License No.</th><th>Expiry</th><th>Vehicle</th><th>Status</th><th>Actions</th></tr>
            </thead>
            <tbody>${rows}</tbody>
          </table>
        </div>`;
    }

    function load() {
      drivers = undefined;
      countEl.textContent = 'Loading drivers…';
      renderStats();
      AdminUi.loadInto(tableEl, async () => {
        const [d, f] = await Promise.all([OperatorApi.drivers(), OperatorApi.fleet().catch(() => [])]);
        return { d, f };
      }, ({ d, f }) => {
        drivers = d;
        fleet = f;
        renderStats();
        renderTable();
      }).then(() => {
        if (!Array.isArray(drivers)) {
          statsEl.innerHTML = '';
          countEl.textContent = '';
        }
      });
    }

    // ---------- Shared driver form ----------

    /** Value as it goes into an <input>. */
    function inputValue(key, values) {
      const v = values[key];
      if (v === null || v === undefined) return '';
      if (key === 'dl_codes') return Array.isArray(v) ? v.join(', ') : v;
      return v;
    }

    function fieldsHtml(values = {}, missing = []) {
      return `
        <div class="op-form__grid">
          ${FIELDS.map(([key, label, type, opts = {}]) => {
            const id = `df-${key}`;
            const isMissing = missing.includes(key);
            const value = inputValue(key, values);
            const control = type === 'select'
              ? `<select id="${id}">${opts.choices.map(([v, l]) =>
                  `<option value="${v}"${String(value) === v ? ' selected' : ''}>${l}</option>`).join('')}</select>`
              : `<input id="${id}" type="${type}" value="${esc(value)}"
                  ${opts.placeholder ? `placeholder="${esc(opts.placeholder)}"` : ''}
                  ${opts.step ? `step="${opts.step}"` : ''} ${opts.min ? `min="${opts.min}"` : ''} ${opts.max ? `max="${opts.max}"` : ''} />`;
            return `
              <div class="op-field${opts.full ? ' op-field--full' : ''}${isMissing ? ' op-field--missing' : ''}">
                <label for="${id}">${esc(label)}${opts.required ? ' *' : ''}</label>
                ${control}
                ${isMissing ? '<small>Couldn\'t read this from the scan — please fill it in.</small>' : ''}
              </div>`;
          }).join('')}
        </div>`;
    }

    /** Reads the form back into an API body; throws a readable error if invalid. */
    function readForm(modal, { forCreate }) {
      const get = (key) => modal.querySelector(`#df-${key}`).value.trim();
      const body = {};
      FIELDS.forEach(([key, , type]) => {
        const raw = get(key);
        if (key === 'dl_codes') body[key] = raw ? raw.split(/[\s,]+/).filter(Boolean).map((c) => c.toUpperCase()) : [];
        else if (type === 'number') body[key] = raw ? Number(raw) : null;
        else body[key] = raw || null;
      });
      body.license_number = (body.license_number || '').toUpperCase();

      if (!body.last_name || !body.first_name) throw new Error('Enter the driver\'s first and last name.');
      if (!LICENSE_PATTERN.test(body.license_number)) throw new Error('License number must look like G06-23-000951.');
      if (!body.expiration_date) throw new Error('Enter the license expiry date.');
      if (forCreate && daysUntil(body.expiration_date) < 0) {
        throw new Error(`This license expired on ${formatDay(body.expiration_date)}. Only drivers with a valid license can be added.`);
      }
      return body;
    }

    // ---------- Add driver: 1. scan ----------

    function openScan() {
      const files = { front: null, back: null };

      const slot = (side, label) => `
        <label class="op-upload" id="up-${side}">
          <input type="file" accept="image/png,image/jpeg" data-side="${side}" />
          <span class="op-upload__label">${label}</span>
          <span class="op-upload__hint">PNG or JPG, up to ${MAX_IMAGE_MB} MB</span>
          <img alt="" hidden />
        </label>`;

      const modal = AdminModal.open({
        title: 'Add Driver — Scan License',
        size: 'wide',
        body: `
          <p class="modal-text">Upload clear photos of both sides of the driver's LTO license. The details are read automatically for you to review.</p>
          <div class="op-upload-grid">${slot('front', 'Front of license')}${slot('back', 'Back of license')}</div>
          <p class="modal-text" id="scan-status" style="color:var(--op-muted);margin-top:12px;"></p>`,
        actions: [
          { label: 'Enter Manually', variant: 'ghost', onClick: () => openReview({}, []) },
          {
            label: 'Scan License',
            variant: 'primary',
            onClick: async (m) => {
              if (!files.front || !files.back) throw new Error('Add photos of both the front and the back.');
              m.querySelector('#scan-status').textContent = 'Reading the license… this can take up to a minute.';
              try {
                const scan = await OperatorApi.scanLicense(files.front, files.back);
                openReview({ ...scan.front, serial_number: scan.back.serial_number }, scan.missing_fields || []);
              } finally {
                const status = m.querySelector('#scan-status');
                if (status) status.textContent = '';
              }
            },
          },
        ],
      });

      modal.querySelectorAll('input[type="file"]').forEach((input) => {
        input.addEventListener('change', () => {
          const file = input.files[0];
          const box = modal.querySelector(`#up-${input.dataset.side}`);
          const img = box.querySelector('img');
          const errorEl = modal.querySelector('.admin-modal__error');
          errorEl.hidden = true;
          if (!file) return;
          if (!['image/png', 'image/jpeg'].includes(file.type)) {
            errorEl.textContent = 'The license photo must be a PNG or JPG image.';
            errorEl.hidden = false;
            input.value = '';
            return;
          }
          if (file.size > MAX_IMAGE_MB * 1024 * 1024) {
            errorEl.textContent = `Each photo must be ${MAX_IMAGE_MB} MB or smaller.`;
            errorEl.hidden = false;
            input.value = '';
            return;
          }
          files[input.dataset.side] = file;
          if (img.src) URL.revokeObjectURL(img.src);
          img.src = URL.createObjectURL(file);
          img.hidden = false;
          box.classList.add('has-file');
        });
      });
    }

    // ---------- Add driver: 2. review ----------

    function openReview(values, missing) {
      AdminModal.open({
        title: missing.length || Object.keys(values).length ? 'Review License Details' : 'Add Driver — Enter Details',
        size: 'wide',
        body: `
          ${missing.length
            ? `<p class="modal-text" style="color:var(--op-amber);margin-bottom:14px;">${missing.length} ${missing.length === 1 ? 'field' : 'fields'} couldn't be read. Check the highlighted fields against the license.</p>`
            : Object.keys(values).length
              ? '<p class="modal-text" style="margin-bottom:14px;">Check every field against the license before saving.</p>'
              : '<p class="modal-text" style="margin-bottom:14px;">Type the details exactly as printed on the license.</p>'}
          ${fieldsHtml(values, missing)}`,
        actions: [
          { label: 'Back to Scan', variant: 'ghost', onClick: openScan },
          {
            label: 'Save Driver',
            variant: 'primary',
            onClick: async (m) => {
              const created = await OperatorApi.addDriver(readForm(m, { forCreate: true }));
              load();
              openCredentials(created);
            },
          },
        ],
      });
    }

    // ---------- Add driver: 3. credentials ----------

    function openCredentials(created) {
      const { email, password } = created.account;
      const copy = (text, what) => async () => {
        await navigator.clipboard.writeText(text);
        AdminUi.toast(`${what} copied.`);
      };
      AdminModal.open({
        title: 'Driver Added',
        size: 'sm',
        body: `
          <p class="modal-text"><strong>${esc(OperatorUi.driverName(created))}</strong> (${esc(created.driver_code)}) was added. Give them this login for the Smart Commute driver app.</p>
          <p class="modal-text" style="color:var(--op-red);">The password is shown only once. Copy it now.</p>
          <div class="form-field" style="margin-top:12px;"><label>Email</label><div class="op-key">${esc(email)}</div></div>
          <div class="form-field"><label>Password</label><div class="op-key">${esc(password)}</div></div>`,
        actions: [
          { label: 'Copy Email', variant: 'ghost', onClick: copy(email, 'Email') },
          { label: 'Copy Password', variant: 'ghost', onClick: copy(password, 'Password') },
          { label: 'Done', variant: 'primary', onClick: AdminModal.close },
        ],
      });
    }

    // ---------- View / edit / login / remove ----------

    function openView(d) {
      const lic = licenseState(d);
      const rows = [
        ['Driver Code', d.driver_code],
        ['Full Name (license)', d.full_name],
        ['Status', d.status === 'active' ? 'On Duty' : 'Off Duty'],
        ['App Login', d.email || 'No login'],
        ['License Number', d.license_number],
        ['License Expiry', `${formatDay(d.expiration_date)} (${lic.label})`],
        ['Date of Birth', formatDay(d.date_of_birth)],
        ['Sex', { M: 'Male', F: 'Female' }[d.sex]],
        ['Nationality', d.nationality],
        ['Blood Type', d.blood_type],
        ['Height', d.height_m ? `${d.height_m} m` : null],
        ['Weight', d.weight_kg ? `${d.weight_kg} kg` : null],
        ['Eye Color', d.eyes_color],
        ['Agency Code', d.agency_code],
        ['DL Codes', (d.dl_codes || []).join(', ')],
        ['Conditions', d.conditions],
        ['Serial Number', d.serial_number],
        ['Address', d.address],
        ['Assigned Vehicle', vehicleFor(d.id)?.plate_number],
        ['Added On', AdminUi.formatDate(d.created_at)],
      ];
      AdminModal.open({
        title: OperatorUi.driverName(d),
        body: `
          <dl class="detail-list">
            ${rows.map(([label, value]) => `
              <div class="detail-list__row">
                <dt>${esc(label)}</dt>
                <dd>${esc(value || '—')}</dd>
              </div>`).join('')}
          </dl>`,
        actions: [
          { label: 'Close', variant: 'ghost', onClick: AdminModal.close },
          { label: 'Edit Profile', variant: 'primary', onClick: () => openEdit(d) },
        ],
      });
    }

    function openEdit(d) {
      AdminModal.open({
        title: `Edit ${OperatorUi.driverName(d)}`,
        size: 'wide',
        body: `
          <div class="op-field" style="max-width:240px;margin-bottom:16px;">
            <label for="df-status">Duty Status</label>
            <select id="df-status">
              <option value="active"${d.status === 'active' ? ' selected' : ''}>On Duty</option>
              <option value="off_duty"${d.status !== 'active' ? ' selected' : ''}>Off Duty</option>
            </select>
          </div>
          ${fieldsHtml(d)}`,
        actions: [
          { label: 'Cancel', variant: 'ghost', onClick: AdminModal.close },
          {
            label: 'Save Changes',
            variant: 'primary',
            onClick: async (m) => {
              const body = readForm(m, { forCreate: false });
              body.status = m.querySelector('#df-status').value;
              const updated = await OperatorApi.updateDriver(d.id, body);
              drivers = drivers.map((x) => (x.id === d.id ? { ...x, ...updated, email: x.email, has_signed_in: x.has_signed_in } : x));
              AdminModal.close();
              renderStats();
              renderTable();
              AdminUi.toast(`${OperatorUi.driverName(updated)} was updated.`);
            },
          },
        ],
      });
    }

    function openLogin(d) {
      const modal = AdminModal.open({
        title: 'Edit App Login',
        size: 'sm',
        body: `
          <p class="modal-text" style="margin-bottom:12px;">You can change ${esc(OperatorUi.driverName(d))}'s login until they first sign in to the app.</p>
          <div class="form-field">
            <label for="dl-email">Email</label>
            <input id="dl-email" type="email" value="${esc(d.email || '')}" />
          </div>
          <div class="form-field">
            <label for="dl-password">New Password</label>
            <input id="dl-password" type="text" autocomplete="new-password" placeholder="Leave blank to keep the current one" />
            <small style="color:var(--op-muted);">At least 8 characters, with a letter and a number.</small>
          </div>`,
        actions: [
          { label: 'Cancel', variant: 'ghost', onClick: AdminModal.close },
          {
            label: 'Save Login',
            variant: 'primary',
            onClick: async (m) => {
              const email = m.querySelector('#dl-email').value.trim().toLowerCase();
              const password = m.querySelector('#dl-password').value;
              const changes = {};
              if (email && email !== d.email) changes.email = email;
              if (password) {
                if (password.length < 8 || !/[A-Za-z]/.test(password) || !/\d/.test(password)) {
                  throw new Error('Password must be at least 8 characters, with a letter and a number.');
                }
                changes.password = password;
              }
              if (!Object.keys(changes).length) throw new Error('Change the email or enter a new password.');
              const result = await OperatorApi.updateDriverAccount(d.id, changes);
              drivers = drivers.map((x) => (x.id === d.id ? { ...x, email: result.email } : x));
              AdminModal.close();
              renderTable();
              AdminUi.toast(changes.password
                ? `Login updated. Give ${OperatorUi.driverName(d)} their new password.`
                : 'Login email updated.');
            },
          },
        ],
      });
      modal.querySelector('#dl-email').focus();
    }

    function confirmRemove(d) {
      const vehicle = vehicleFor(d.id);
      AdminModal.confirm({
        title: 'Remove driver?',
        message: `${OperatorUi.driverName(d)} (${d.driver_code}) will be removed from your roster and can no longer sign in to the driver app.${vehicle ? ` ${vehicle.plate_number} will have no driver assigned.` : ''} This cannot be undone.`,
        confirmLabel: 'Remove',
        onConfirm: async () => {
          await OperatorApi.deleteDriver(d.id);
          AdminUi.toast(`${OperatorUi.driverName(d)} was removed.`);
          load();
        },
      });
    }

    // ---------- Events ----------

    tableEl.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-action]');
      if (!btn || btn.disabled || !Array.isArray(drivers)) return;
      const driver = drivers.find((d) => d.id === btn.dataset.id);
      if (!driver) return;
      ({ view: openView, edit: openEdit, login: openLogin, remove: confirmRemove })[btn.dataset.action]?.(driver);
    });
    el.querySelector('#drv-add').addEventListener('click', () => OperatorUi.whenVerified(openScan));

    load();
  },
});
