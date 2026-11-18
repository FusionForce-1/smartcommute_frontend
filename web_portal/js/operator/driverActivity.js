// Operator driver activity
// Driver activity
const DriverActivity = (() => {
  const esc = AdminUi.escapeHtml;
  const REFRESH_MS = 15000;
  const FOCUS_ZOOM = 17;

  const DUTY = {
    on_route: { label: 'On-Route', tone: 'green' },
    delayed: { label: 'Delayed', tone: 'amber' },
    unavailable: { label: 'Unavailable', tone: '' },
  };
  const EVENT_TONE = { shift_started: 'green', status_changed: 'amber', crowd_reported: 'blue', shift_ended: '' };
  const EVENT_LABEL = { shift_started: 'Shift', status_changed: 'Status', crowd_reported: 'Crowd', shift_ended: 'Shift end' };

  let session = 0;

  // Header HTML
  function headerHtml(a) {
    const duty = DUTY[a.duty_status] || DUTY.unavailable;
    return `
      <div class="op-list__meta" style="margin-bottom:12px;">
        ${a.driver_code ? OperatorUi.chip(a.driver_code) : ''}
        ${a.on_shift ? OperatorUi.chip('On shift', 'green') : OperatorUi.chip('Off shift')}
        ${a.on_shift ? OperatorUi.chip(duty.label, duty.tone) : ''}
      </div>`;
  }

  // Location HTML
  function locationHtml(loc) {
    if (!loc) return '<p class="op-card__sub" style="margin:8px 0 0;">No GPS location yet for this driver\'s vehicle.</p>';
    return `
      <p class="op-card__sub" style="margin:8px 0 0;">
        <strong>${esc(loc.plate_number)}</strong> · ${loc.lat.toFixed(5)}, ${loc.lng.toFixed(5)}
        · last GPS ${esc(OperatorUi.timeAgo(loc.timestamp))}
      </p>`;
  }

  // Log HTML
  function logHtml(events) {
    if (!events.length) return AdminUi.stateMessage('No shift activity recorded yet.');
    return `
      <div class="op-list op-activity__log">
        ${events.map((e) => `
          <div class="op-list__item">
            <div class="op-list__meta">
              ${OperatorUi.chip(EVENT_LABEL[e.kind] || e.kind, EVENT_TONE[e.kind] || '')}
              <span>${esc(OperatorUi.timeAgo(e.at))}</span>
            </div>
            ${esc(e.text)}
          </div>`).join('')}
      </div>`;
  }

  // Open driver activity
  function open(driverId, { title = 'Driver Activity' } = {}) {
    const mine = ++session;
    let map = null;
    let marker = null;
    let timer = null;

    const modal = AdminModal.open({
      title,
      size: 'wide',
      body: `
        <div id="da-header"></div>
        <h3 class="op-activity__heading">Current Active Location</h3>
        <div class="op-map op-activity__map" id="da-map" role="region" aria-label="Driver location map"></div>
        <div id="da-location"></div>
        <h3 class="op-activity__heading">Driver Activity Log</h3>
        <div id="da-log">${AdminUi.stateMessage('Loading…')}</div>`,
      actions: [
        { label: 'Refresh', variant: 'ghost', onClick: () => load({ focus: true }) },
        { label: 'Close', variant: 'primary', onClick: AdminModal.close },
      ],
      onClose: () => {
        clearInterval(timer);
        if (map) map.remove();
        if (session === mine) session++;
      },
    });

    const mapEl = modal.querySelector('#da-map');
    if (window.L) {
      map = L.map(mapEl).setView([10.3157, 123.8854], 13);
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
        attribution: '&copy; OpenStreetMap contributors',
      }).addTo(map);
    } else {
      mapEl.innerHTML = AdminUi.stateMessage('The map could not load. Check your internet connection.', { error: true });
    }

    // Show location
    function showLocation(loc, { focus }) {
      if (!map) return;
      if (!loc) {
        if (marker) marker.remove();
        marker = null;
        return;
      }
      const latLng = [loc.lat, loc.lng];
      if (!marker) {
        marker = L.marker(latLng, {
          icon: L.divIcon({
            className: '',
            html: '<div class="op-vehicle-marker" style="background:#27AE60"></div>',
            iconSize: [18, 18],
            iconAnchor: [9, 9],
          }),
        }).addTo(map);
      } else {
        marker.setLatLng(latLng);
      }
      marker.bindTooltip(loc.plate_number, { permanent: true, direction: 'top', offset: [0, -10] });
      if (focus) map.setView(latLng, FOCUS_ZOOM);
      else if (!map.getBounds().contains(latLng)) map.panTo(latLng);
    }

    // Load driver activity
    async function load({ focus }) {
      let activity;
      try {
        activity = await OperatorApi.driverActivity(driverId);
      } catch (err) {
        if (session !== mine) return;
        if (!focus) return;
        modal.querySelector('#da-log').innerHTML = AdminUi.stateMessage(err.message || 'Could not load this driver\'s activity.', { error: true });
        return;
      }
      if (session !== mine) return;
      modal.querySelector('#da-header').innerHTML = headerHtml(activity);
      modal.querySelector('#da-location').innerHTML = locationHtml(activity.current_location);
      modal.querySelector('#da-log').innerHTML = logHtml(activity.events);
      showLocation(activity.current_location, { focus });
    }

    if (map) setTimeout(() => map.invalidateSize(), 0);
    load({ focus: true });
    timer = setInterval(() => load({ focus: false }), REFRESH_MS);
  }

  return { open };
})();
