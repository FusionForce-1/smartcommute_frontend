// js/operator/views/fleetMap.js
//
// Fleet Map: Leaflet map of the operator's vehicles (live over
// /ws/live), plus Active Vehicles, Route Alerts and Recent Feedback.

OperatorRouter.register('fleet', {
  title: 'Fleet Map',
  heading: 'Fleet Overview',

  mount(el) {
    const CEBU = [10.3157, 123.8854];
    const POLL_MS = 30000;
    const RECENT_PING_MS = 10 * 60 * 1000;
    const MARKER_COLORS = { active: '#27AE60', maintenance: '#F5A623', inactive: '#7D868E', signal_lost: '#D72F33' };
    const esc = AdminUi.escapeHtml;

    let fleet = [];
    let routes = [];
    let alerts = [];
    let socket = null;
    let reconnectTimer = null;
    let stopped = false;
    const markers = new Map(); // vehicle_id -> L.Marker

    el.innerHTML = `
      <div class="op-map" id="fleet-map" role="region" aria-label="Fleet map"></div>
      <div class="op-map__legend">
        <span><span class="op-dot" style="background:${MARKER_COLORS.active}"></span>Active</span>
        <span><span class="op-dot" style="background:${MARKER_COLORS.maintenance}"></span>Maintenance</span>
        <span><span class="op-dot" style="background:${MARKER_COLORS.inactive}"></span>Inactive / suspended</span>
        <span><span class="op-dot" style="background:${MARKER_COLORS.signal_lost}"></span>Signal lost</span>
        <span id="fleet-live">Connecting to live updates…</span>
      </div>
      <div class="op-grid">
        <section class="op-card">
          <h3>Active Vehicles</h3>
          <p class="op-card__sub">Live count and status summary for assigned fleet.</p>
          <div id="panel-vehicles"></div>
        </section>
        <section class="op-card">
          <h3>Route Alerts</h3>
          <p class="op-card__sub">Congested or suspended routes requiring attention.</p>
          <div id="panel-alerts"></div>
        </section>
        <section class="op-card">
          <h3>Recent Feedback</h3>
          <p class="op-card__sub">Latest commuter reports and ride reviews on your routes.</p>
          <div id="panel-feedback"></div>
        </section>
      </div>`;

    const vehiclesEl = el.querySelector('#panel-vehicles');
    const alertsEl = el.querySelector('#panel-alerts');
    const feedbackEl = el.querySelector('#panel-feedback');
    const liveEl = el.querySelector('#fleet-live');

    // ---------- Map ----------

    const map = window.L ? L.map(el.querySelector('#fleet-map')).setView(CEBU, 13) : null;
    if (map) {
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
        attribution: '&copy; OpenStreetMap contributors',
      }).addTo(map);
    } else {
      el.querySelector('#fleet-map').innerHTML = AdminUi.stateMessage('The map could not load. Check your internet connection.', { error: true });
    }
    const vehicleLayer = map ? L.layerGroup().addTo(map) : null;

    const routeLabel = (id) => {
      const r = routes.find((x) => x.id === id);
      return r ? `${r.code} – ${r.name}` : 'Unknown route';
    };

    function markerIcon(status) {
      const color = MARKER_COLORS[status] || MARKER_COLORS.inactive;
      return L.divIcon({
        className: '',
        html: `<div class="op-vehicle-marker" style="background:${color}"></div>`,
        iconSize: [18, 18],
        iconAnchor: [9, 9],
      });
    }

    function popupHtml(v) {
      const ping = v.last_position?.timestamp ? OperatorUi.timeAgo(v.last_position.timestamp) : 'No GPS yet';
      // Driver monitoring entry point from the map (see the popupopen hook below).
      const activity = v.driver_id
        ? `<br><button type="button" class="btn-sm btn-sm--teal" style="margin-top:6px;"
             data-driver-activity="${esc(v.driver_id)}" data-plate="${esc(v.plate_number)}">Driver activity</button>`
        : '';
      return `<strong>${esc(v.plate_number)}</strong><br>${esc(routeLabel(v.route_id))}<br>
        Status: ${esc(v.suspended ? 'suspended' : v.status)}<br>Last GPS: ${esc(ping)}${activity}`;
    }

    // "Driver activity" inside a vehicle popup. Listened for on the map in the
    // capture phase: Leaflet stops clicks in popups from bubbling, and the
    // popup's content is refreshed with live GPS, which would drop a listener
    // attached to the button itself.
    if (map) {
      map.getContainer().addEventListener('click', (e) => {
        const btn = e.target.closest?.('[data-driver-activity]');
        if (!btn) return;
        e.preventDefault();
        DriverActivity.open(btn.dataset.driverActivity, { title: `Driver of ${btn.dataset.plate} — Activity` });
      }, true);
    }

    function markerStatus(v) {
      return v.suspended ? 'inactive' : v.status;
    }

    function drawVehicles({ fit = false } = {}) {
      if (!map) return;
      const seen = new Set();
      fleet.forEach((v) => {
        const pos = v.last_position;
        if (!pos) return;
        seen.add(v.vehicle_id);
        const latLng = [pos.lat, pos.lng];
        const status = markerStatus(v);
        let marker = markers.get(v.vehicle_id);
        if (!marker) {
          marker = L.marker(latLng, { icon: markerIcon(status) }).addTo(vehicleLayer);
          marker.bindPopup(popupHtml(v));
          marker._opStatus = status;
          markers.set(v.vehicle_id, marker);
        } else {
          marker.setLatLng(latLng);
          // Rebuilding the icon on every GPS update swapped the element under
          // the pointer, so taps on a moving jeep were lost: only on a change.
          if (marker._opStatus !== status) {
            marker.setIcon(markerIcon(status));
            marker._opStatus = status;
          }
          const html = popupHtml(v);
          if (marker.getPopup()?.getContent() !== html) marker.setPopupContent(html);
        }
      });
      markers.forEach((marker, id) => {
        if (!seen.has(id)) {
          marker.remove();
          markers.delete(id);
        }
      });
      if (fit && markers.size) {
        map.fitBounds(L.latLngBounds([...markers.values()].map((m) => m.getLatLng())), { padding: [40, 40], maxZoom: 15 });
      }
    }

    // ---------- Panels ----------

    function renderVehicles() {
      const total = fleet.length;
      if (!total) {
        vehiclesEl.innerHTML = AdminUi.stateMessage('No vehicles in your fleet yet.');
        return;
      }
      const count = (fn) => fleet.filter(fn).length;
      const inService = count((v) => v.status === 'active' && !v.suspended && v.route_status !== 'suspended');
      const now = Date.now();
      const reporting = count((v) => {
        const t = OperatorUi.parseDate(v.last_position?.timestamp);
        return t && now - t <= RECENT_PING_MS;
      });
      const chips = [
        ['Active', count((v) => v.status === 'active' && !v.suspended), 'green'],
        ['Maintenance', count((v) => v.status === 'maintenance'), 'amber'],
        ['Inactive', count((v) => v.status === 'inactive'), ''],
        ['Signal lost', count((v) => v.status === 'signal_lost'), 'red'],
        ['Suspended', count((v) => v.suspended), 'red'],
      ].filter(([, n]) => n > 0);

      vehiclesEl.innerHTML = `
        <div class="op-big-number">${inService}<span style="font-size:1rem;color:var(--op-muted);font-weight:600;"> / ${total} in service</span></div>
        <div class="op-breakdown">${chips.map(([l, n, t]) => OperatorUi.chip(`${l}: ${n}`, t)).join('')}</div>
        <p class="op-card__sub" style="margin:12px 0 0;">${reporting} of ${total} reported GPS in the last 10 minutes.</p>
        <a class="op-link" href="#/vehicles">Manage vehicles →</a>`;
    }

    function renderAlerts() {
      const troubled = new Map();
      fleet.forEach((v) => {
        if (v.route_status === 'congested' || v.route_status === 'suspended') troubled.set(v.route_id, v.route_status);
      });
      const open = alerts.filter((a) => !a.is_resolved);

      const items = [
        ...[...troubled].map(([id, status]) => {
          const meta = OperatorUi.ROUTE_STATUS[status];
          return `
            <div class="op-list__item">
              <div class="op-list__meta">${OperatorUi.chip(meta.label, meta.tone)}</div>
              ${esc(routeLabel(id))}
            </div>`;
        }),
        ...open.slice(0, 3).map((a) => {
          const sev = OperatorUi.SEVERITY[a.severity] || OperatorUi.SEVERITY.info;
          return `
            <div class="op-list__item">
              <div class="op-list__meta">
                ${OperatorUi.chip(sev.label, sev.tone)} ${OperatorUi.chip(a.route_code || 'All routes')}
                <span>${esc(OperatorUi.timeAgo(a.created_at))}</span>
              </div>
              <strong>${esc(a.title)}</strong>
            </div>`;
        }),
      ];

      alertsEl.innerHTML = items.length
        ? `<div class="op-list">${items.join('')}</div>`
        : AdminUi.stateMessage('All routes are running normally.');
      alertsEl.insertAdjacentHTML('beforeend', '<a class="op-link" href="#/announcements">Post an announcement →</a>');
    }

    // Newest first: route reports (/feedback/mine) and ride reviews
    // (/reviews/operator) merged into one list.
    const FEEDBACK_SHOWN = 5;

    async function loadFeedback() {
      const [reports, reviews] = await Promise.all([
        OperatorApi.myFeedback({ limit: FEEDBACK_SHOWN }).catch(() => null),
        OperatorApi.driverReviews().then((r) => r.reviews || []).catch(() => null),
      ]);
      if (reports === null && reviews === null) throw new Error('Could not load feedback.');
      const items = [
        ...(reports || []).map((f) => ({ kind: 'report', at: f.created_at, f })),
        ...(reviews || []).map((r) => ({ kind: 'review', at: r.created_at, r })),
      ];
      items.sort((a, b) => (OperatorUi.parseDate(b.at) || 0) - (OperatorUi.parseDate(a.at) || 0));
      return items.slice(0, FEEDBACK_SHOWN);
    }

    function feedbackItemHtml(item) {
      const when = `<span>· ${esc(OperatorUi.timeAgo(item.at))}</span>`;
      if (item.kind === 'report') {
        const f = item.f;
        return `
          <div class="op-list__item">
            <div class="op-list__meta">
              ${OperatorUi.chip(OperatorUi.FEEDBACK_CATEGORY[f.category] || f.category, 'blue')}
              <span>${esc(routeLabel(f.route_id))}</span>${when}
            </div>
            ${esc(f.message)}
          </div>`;
      }
      const r = item.r;
      const stars = '★'.repeat(r.rating) + '☆'.repeat(5 - r.rating);
      const about = [r.plate_number, r.driver_name].filter(Boolean).join(' · ') || 'Plate not given';
      const tone = r.rating >= 4 ? 'green' : r.rating <= 2 ? 'red' : 'amber';
      return `
        <div class="op-list__item">
          <div class="op-list__meta">
            ${OperatorUi.chip('Ride review', tone)}
            <span style="color:#F5A623;" aria-label="${r.rating} of 5 stars">${stars}</span>
            <span>${esc(r.route_code || '')}</span>${when}
          </div>
          <span class="op-card__sub" style="margin:0;">${esc(about)}</span>
          ${r.comment ? `<div>${esc(r.comment)}</div>` : ''}
        </div>`;
    }

    function renderFeedback(list) {
      if (!list.length) {
        feedbackEl.innerHTML = AdminUi.stateMessage('No commuter feedback on your routes yet.');
        return;
      }
      feedbackEl.innerHTML = `
        <div class="op-list">${list.map(feedbackItemHtml).join('')}</div>
        <a class="op-link" href="#/reports">See all feedback →</a>`;
    }

    // ---------- Loading ----------

    async function loadFleet({ first = false } = {}) {
      const load = async () => {
        const [f, r, a] = await Promise.all([
          OperatorApi.fleet(),
          OperatorApi.myRoutes(),
          OperatorApi.myAlerts().catch(() => []),
        ]);
        return { f, r, a };
      };
      const render = ({ f, r, a }) => {
        fleet = f;
        routes = r;
        alerts = a;
        renderVehicles();
        renderAlerts();
        drawVehicles({ fit: first });
      };

      if (first) {
        alertsEl.innerHTML = AdminUi.stateMessage('Loading…');
        await AdminUi.loadInto(vehiclesEl, load, render);
        if (!fleet.length && vehiclesEl.querySelector('.state-msg--error')) {
          alertsEl.innerHTML = '';
        }
      } else {
        try {
          render(await load());
        } catch {
          // Keep showing the last good data between polls.
        }
      }
    }

    // ---------- Live updates ----------

    function connectLive() {
      if (stopped) return;
      const url = `${API_BASE_URL.replace(/^http/, 'ws')}/ws/live`;
      try {
        socket = new WebSocket(url);
      } catch {
        liveEl.textContent = 'Live updates unavailable.';
        return;
      }
      socket.addEventListener('open', () => { liveEl.textContent = '● Live'; });
      socket.addEventListener('message', (event) => {
        let msg;
        try { msg = JSON.parse(event.data); } catch { return; }
        if (msg.type === 'transit_alert') return; // published from Announcements
        const vehicle = fleet.find((v) => v.vehicle_id === msg.vehicle_id);
        if (!vehicle) return; // another operator's vehicle
        if (typeof msg.lat === 'number' && typeof msg.lng === 'number') {
          vehicle.last_position = { lat: msg.lat, lng: msg.lng, timestamp: msg.ts || new Date().toISOString() };
        }
        if (msg.status === 'signal_lost') vehicle.status = 'signal_lost';
        else if (msg.status === 'en_route' && vehicle.status === 'signal_lost') vehicle.status = 'active';
        drawVehicles();
        renderVehicles();
      });
      socket.addEventListener('close', () => {
        if (stopped) return;
        liveEl.textContent = 'Live updates paused — reconnecting…';
        reconnectTimer = setTimeout(connectLive, 5000);
      });
    }

    // Feedback rows show route names, so they load after the routes.
    feedbackEl.innerHTML = AdminUi.stateMessage('Loading…');
    loadFleet({ first: true }).then(() => {
      if (!stopped) AdminUi.loadInto(feedbackEl, loadFeedback, renderFeedback);
    });
    connectLive();
    // New feedback shows up without reloading the page.
    const refreshFeedback = () => loadFeedback().then((list) => { if (!stopped) renderFeedback(list); }).catch(() => {});
    const poll = setInterval(() => { loadFleet(); refreshFeedback(); }, POLL_MS);

    return () => {
      stopped = true;
      clearInterval(poll);
      clearTimeout(reconnectTimer);
      if (socket) socket.close();
      if (map) map.remove();
    };
  },
});
