// js/operator/views/vehicles.js
//
// Vehicles: the operator's fleet with route, driver, status and GPS.
// Add / edit / remove vehicles and issue GPS tracker device keys.

OperatorRouter.register('vehicles', {
  title: 'Vehicles',
  heading: 'Vehicle Management',

  mount(el) {
    const esc = AdminUi.escapeHtml;
    const STATUSES = [
      ['active', 'Active'],
      ['inactive', 'Inactive'],
      ['maintenance', 'Maintenance'],
    ];

    let fleet;           // undefined = loading
    let routes = [];
    let drivers = [];
    let subscription = null;

    el.innerHTML = `
      <div class="op-page-head">
        <div>
          <h2>Fleet Vehicles</h2>
          <p>Register vehicles, assign them to routes and drivers, and manage their GPS trackers.</p>
        </div>
        <button type="button" class="op-btn" id="veh-add">＋ Add Vehicle</button>
      </div>
      <div id="veh-stats"></div>
      <section class="op-card op-card--flush">
        <div class="op-card__head">
          <h3>Vehicle Registry</h3>
          <p class="op-card__sub" id="veh-plan" style="margin:0;"></p>
        </div>
        <div id="veh-table"></div>
      </section>`;

    const statsEl = el.querySelector('#veh-stats');
    const tableEl = el.querySelector('#veh-table');
    const planEl = el.querySelector('#veh-plan');
    const addBtn = el.querySelector('#veh-add');

    const routeLabels = () => OperatorUi.routeLabels(routes);
    const driverById = (id) => drivers.find((d) => d.id === id);

    // ---------- Rendering ----------

    function renderStats() {
      const loaded = Array.isArray(fleet);
      const count = (fn) => (loaded ? fleet.filter(fn).length : undefined);
      statsEl.innerHTML = OperatorUi.stats([
        ['Total Vehicles', loaded ? fleet.length : undefined],
        ['Active', count((v) => v.status === 'active' && !v.suspended), 'green'],
        ['Maintenance', count((v) => v.status === 'maintenance'), 'amber'],
        ['With GPS Signal', count((v) => v.last_position), 'blue'],
      ]);
    }

    function renderPlan() {
      if (!subscription) {
        planEl.textContent = '';
        addBtn.disabled = false;
        return;
      }
      const { vehicle_count: count, vehicle_limit: limit, can_add_vehicle: canAdd, state } = subscription;
      planEl.textContent = limit
        ? `${count} of ${limit} vehicles used on your ${state} plan.${canAdd ? '' : ' Subscribe to add more.'}`
        : `${count} vehicles · unlimited on your ${state} plan.`;
      addBtn.disabled = !canAdd;
      addBtn.title = canAdd ? '' : 'Vehicle limit reached for your plan';
    }

    function row(v) {
      const labels = routeLabels();
      const driver = v.driver_id ? driverById(v.driver_id) : null;
      const ping = v.last_position?.timestamp ? OperatorUi.timeAgo(v.last_position.timestamp) : 'No GPS yet';
      const crowd = v.crowd_level ? OperatorUi.chip(v.crowd_level, { low: 'green', medium: 'amber', high: 'red' }[v.crowd_level]) : '—';
      return `
        <tr>
          <td class="data-table__name">${esc(v.plate_number)}</td>
          <td>${esc(labels[v.route_id] || 'Unknown route')}</td>
          <td>${driver ? esc(OperatorUi.driverName(driver)) : v.driver_id ? 'Assigned' : '<span style="color:var(--op-muted)">Unassigned</span>'}</td>
          <td>${OperatorUi.vehicleStatusChip(v)}</td>
          <td>${crowd}</td>
          <td>${esc(ping)}</td>
          <td>
            <div class="data-table__actions">
              <button type="button" class="btn-sm btn-sm--teal" data-action="edit" data-id="${v.vehicle_id}">Edit</button>
              <button type="button" class="btn-sm" data-action="key" data-id="${v.vehicle_id}">Tracker key</button>
              <button type="button" class="btn-sm btn-sm--danger" data-action="remove" data-id="${v.vehicle_id}">Remove</button>
            </div>
          </td>
        </tr>`;
    }

    function renderTable() {
      const rows = fleet.length
        ? fleet.map(row).join('')
        : '<tr><td colspan="7" class="data-table__empty">No vehicles yet. Click Add Vehicle to register one.</td></tr>';
      tableEl.innerHTML = `
        <div class="table-wrap">
          <table class="data-table">
            <thead>
              <tr><th>Plate</th><th>Route</th><th>Driver</th><th>Status</th><th>Crowd</th><th>Last GPS</th><th>Actions</th></tr>
            </thead>
            <tbody>${rows}</tbody>
          </table>
        </div>`;
    }

    function load() {
      fleet = undefined;
      renderStats();
      AdminUi.loadInto(tableEl, async () => {
        const [f, r, d, s] = await Promise.all([
          OperatorApi.fleet(),
          OperatorApi.myRoutes(),
          OperatorApi.drivers().catch(() => []),
          OperatorApi.subscription().catch(() => null),
        ]);
        return { f, r, d, s };
      }, ({ f, r, d, s }) => {
        fleet = f;
        routes = r;
        drivers = d;
        subscription = s;
        renderStats();
        renderPlan();
        renderTable();
      }).then(() => {
        if (!Array.isArray(fleet)) statsEl.innerHTML = '';
      });
    }

    // ---------- Forms ----------

    const options = (items, selected) => items
      .map(([value, label]) => `<option value="${esc(value)}"${value === selected ? ' selected' : ''}>${esc(label)}</option>`)
      .join('');

    function routeOptions(selected) {
      return options(routes.map((r) => [r.id, `${r.code} – ${r.name}${r.is_active ? '' : ' (inactive)'}`]), selected);
    }

    function driverOptions(selected) {
      return `<option value="">Unassigned</option>${options(
        drivers.map((d) => [d.id, `${OperatorUi.driverName(d)} (${d.driver_code})`]), selected)}`;
    }

    function openAdd() {
      if (!routes.length) {
        AdminModal.open({
          title: 'Add Vehicle',
          size: 'sm',
          body: '<p class="modal-text">Create a route first — every vehicle has to be assigned to one.</p>',
          actions: [{ label: 'Go to Routes', variant: 'primary', onClick: () => { AdminModal.close(); location.hash = '#/routes'; } }],
        });
        return;
      }
      const modal = AdminModal.open({
        title: 'Add Vehicle',
        size: 'sm',
        body: `
          <form novalidate>
            <div class="form-field">
              <label for="va-plate">Plate Number</label>
              <input id="va-plate" maxlength="12" placeholder="e.g. GAB 1234" autocomplete="off" />
            </div>
            <div class="form-field">
              <label for="va-route">Route</label>
              <select id="va-route">${routeOptions(routes[0].id)}</select>
            </div>
            <div class="form-field">
              <label for="va-driver">Driver</label>
              <select id="va-driver">${driverOptions('')}</select>
            </div>
          </form>`,
        actions: [
          { label: 'Cancel', variant: 'ghost', onClick: AdminModal.close },
          {
            label: 'Add Vehicle',
            variant: 'primary',
            onClick: async (m) => {
              const plate = m.querySelector('#va-plate').value.trim().toUpperCase();
              if (!plate) throw new Error('Enter the plate number.');
              await OperatorApi.addVehicle({
                plate_number: plate,
                route_id: m.querySelector('#va-route').value,
                driver_id: m.querySelector('#va-driver').value,
              });
              AdminModal.close();
              AdminUi.toast(`${plate} was added to your fleet.`);
              load();
            },
          },
        ],
      });
      modal.querySelector('#va-plate').focus();
    }

    function openEdit(v) {
      AdminModal.open({
        title: `Edit ${v.plate_number}`,
        size: 'sm',
        body: `
          <form novalidate>
            <div class="form-field">
              <label for="ve-route">Route</label>
              <select id="ve-route">${routeOptions(v.route_id)}</select>
            </div>
            <div class="form-field">
              <label for="ve-driver">Driver</label>
              <select id="ve-driver">${driverOptions(v.driver_id || '')}</select>
            </div>
            <div class="form-field">
              <label for="ve-status">Status</label>
              <select id="ve-status">${options(STATUSES, STATUSES.some(([s]) => s === v.status) ? v.status : 'active')}</select>
            </div>
            ${v.suspended ? '<p class="modal-text" style="color:var(--op-red)">This vehicle is suspended by your subscription plan and hidden from commuters until the plan is renewed.</p>' : ''}
          </form>`,
        actions: [
          { label: 'Cancel', variant: 'ghost', onClick: AdminModal.close },
          {
            label: 'Save',
            variant: 'primary',
            onClick: async (m) => {
              await OperatorApi.updateVehicle(v.vehicle_id, {
                route_id: m.querySelector('#ve-route').value,
                driver_id: m.querySelector('#ve-driver').value || null,
                status: m.querySelector('#ve-status').value,
              });
              AdminModal.close();
              AdminUi.toast(`${v.plate_number} was updated.`);
              load();
            },
          },
        ],
      });
    }

    function openDeviceKey(v) {
      AdminModal.open({
        title: 'GPS Tracker Key',
        size: 'sm',
        body: `
          <p class="modal-text">Issue a new device key for <strong>${esc(v.plate_number)}</strong>'s GPS tracker.</p>
          <p class="modal-text">Any previous key stops working immediately and its tracker is disconnected.</p>`,
        actions: [
          { label: 'Cancel', variant: 'ghost', onClick: AdminModal.close },
          {
            label: 'Issue New Key',
            variant: 'primary',
            onClick: async () => {
              const { device_key: key } = await OperatorApi.issueDeviceKey(v.vehicle_id);
              AdminModal.open({
                title: 'Copy This Key Now',
                size: 'sm',
                body: `
                  <p class="modal-text">Put this key in the tracker's <code>secrets.h</code> as <code>DEVICE_KEY</code>. It can't be shown again.</p>
                  <div class="op-key" id="device-key">${esc(key)}</div>`,
                actions: [
                  {
                    label: 'Copy',
                    variant: 'ghost',
                    onClick: async () => {
                      await navigator.clipboard.writeText(key);
                      AdminUi.toast('Device key copied.');
                    },
                  },
                  { label: 'Done', variant: 'primary', onClick: AdminModal.close },
                ],
              });
            },
          },
        ],
      });
    }

    function confirmRemove(v) {
      AdminModal.confirm({
        title: 'Remove vehicle?',
        message: `${v.plate_number} will be removed from your fleet and its GPS tracker key revoked. This cannot be undone.`,
        confirmLabel: 'Remove',
        onConfirm: async () => {
          await OperatorApi.deleteVehicle(v.vehicle_id);
          AdminUi.toast(`${v.plate_number} was removed.`);
          load();
        },
      });
    }

    tableEl.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-action]');
      if (!btn || !Array.isArray(fleet)) return;
      const vehicle = fleet.find((v) => v.vehicle_id === btn.dataset.id);
      if (!vehicle) return;
      ({ edit: openEdit, key: openDeviceKey, remove: confirmRemove })[btn.dataset.action]?.(vehicle);
    });
    // Verify first: GET /fleet refuses unverified operators, so `fleet` never loads for them.
    addBtn.addEventListener('click', () => OperatorUi.whenVerified(() => {
      if (Array.isArray(fleet)) openAdd();
    }));

    load();
  },
});
