// Operator UI
// Operator UI
const OperatorUi = (() => {
  const esc = AdminUi.escapeHtml;

  // Parse date
  function parseDate(value) {
    if (!value) return null;
    const iso = String(value).replace(' ', 'T');
    const hasZone = /[zZ]|[+-]\d\d:?\d\d$/.test(iso);
    const date = new Date(hasZone ? iso : `${iso}Z`);
    return Number.isNaN(date.getTime()) ? null : date;
  }

  // Time ago
  function timeAgo(value, now = new Date()) {
    const date = parseDate(value);
    if (!date) return '';
    const minutes = Math.floor((now - date) / 60000);
    if (minutes < 1) return 'Just now';
    if (minutes < 60) return `${minutes} ${minutes === 1 ? 'minute' : 'minutes'} ago`;

    // Start of day
    const startOfDay = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate());
    const days = Math.round((startOfDay(now) - startOfDay(date)) / 86400000);
    const clock = date.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
    if (days === 0) {
      const hours = Math.floor(minutes / 60);
      return `${hours} ${hours === 1 ? 'hour' : 'hours'} ago`;
    }
    if (days === 1) return `Yesterday, ${clock}`;
    const sameYear = date.getFullYear() === now.getFullYear();
    const day = date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', ...(sameYear ? {} : { year: 'numeric' }) });
    return `${day}, ${clock}`;
  }

  // Operator UI fare
  function fare(value) {
    if (typeof value !== 'number') return '—';
    return Number.isInteger(value) ? `₱${value}` : `₱${value.toFixed(2)}`;
  }

  // Operator UI chip
  function chip(label, tone = '') {
    return `<span class="op-chip${tone ? ` op-chip--${tone}` : ''}">${esc(label)}</span>`;
  }

  // Operator UI stat
  function stat(label, value, tone = '') {
    return `
      <div class="op-stat">
        <p class="op-stat__label">${esc(label)}</p>
        <div class="op-stat__value${tone ? ` op-stat__value--${tone}` : ''}">${value ?? '<span class="skeleton"></span>'}</div>
      </div>`;
  }

  // Operator UI stats
  function stats(items) {
    return `<section class="op-stats">${items.map(([l, v, t]) => stat(l, v, t)).join('')}</section>`;
  }

  const SEVERITY = {
    info: { label: 'Information', button: 'Info', tone: 'blue' },
    warning: { label: 'Warning', button: 'Warning', tone: 'amber' },
    critical: { label: 'Critical', button: 'Critical', tone: 'red' },
  };

  const NOTICE_CATEGORY = {
    service_alert: 'Service alert',
    schedule_change: 'Schedule change',
    promotion: 'Promotion',
  };

  const REPORT_CATEGORY = {
    emergency: { label: 'Emergency', tone: 'red' },
    breakdown: { label: 'Breakdown', tone: 'amber' },
    delay: { label: 'Delay / Heavy traffic', tone: 'amber' },
    vehicle_issue: { label: 'Vehicle issue', tone: 'amber' },
    other: { label: 'Other', tone: '' },
  };

  // Request ID
  function requestId() {
    if (crypto.randomUUID) return crypto.randomUUID();
    return Array.from(crypto.getRandomValues(new Uint8Array(16)), (b) => b.toString(16).padStart(2, '0')).join('');
  }

  const VEHICLE_STATUS = {
    active: { label: 'Active', tone: 'green' },
    inactive: { label: 'Inactive', tone: '' },
    maintenance: { label: 'Maintenance', tone: 'amber' },
    signal_lost: { label: 'Signal lost', tone: 'red' },
  };

  const ROUTE_STATUS = {
    active: { label: 'Normal', tone: 'green' },
    congested: { label: 'Congested', tone: 'amber' },
    suspended: { label: 'Suspended', tone: 'red' },
  };

  const FEEDBACK_CATEGORY = {
    delay: 'Delay',
    overcrowding: 'Overcrowding',
    route_issue: 'Route issue',
    driver_behavior: 'Driver behavior',
    other: 'Other',
  };

  const FLAG_TEXT = {
    driver_away: 'Driver away from PUV',
    off_route: 'Off route (more than 150 m from its route)',
  };

  // Away and off-route chips
  function flagChips(vehicle) {
    return [
      vehicle.driver_away ? chip(FLAG_TEXT.driver_away, 'amber') : '',
      vehicle.off_route ? chip('Off route', 'amber') : '',
    ].join('');
  }

  // Vehicle status chip
  function vehicleStatusChip(vehicle) {
    if (vehicle.suspended) return chip('Suspended', 'red');
    const meta = VEHICLE_STATUS[vehicle.status] || { label: vehicle.status, tone: '' };
    return chip(meta.label, meta.tone);
  }

  // Route labels
  function routeLabels(routes) {
    return Object.fromEntries(routes.map((r) => [r.id, `${r.code} – ${r.name}`]));
  }

  // Driver name
  function driverName(driver) {
    // Operator UI title
    const title = (s) => s.toLowerCase().replace(/\b\w/g, (c) => c.toUpperCase());
    return [driver.first_name, driver.last_name].filter(Boolean).map(title).join(' ') || driver.driver_code;
  }

  // When verified
  async function whenVerified(action) {
    const profile = await OperatorApi.profile().catch(() => null);
    if (profile && !profile.is_verified) {
      AdminModal.open({
        title: 'Account Not Verified',
        size: 'sm',
        body: '<p class="modal-text">Your operator account has not been verified by an admin yet.</p>',
        actions: [{ label: 'OK', variant: 'primary', onClick: AdminModal.close }],
      });
      return;
    }
    action();
  }

  // Operator UI bearing
  function bearing(a, b) {
    // To rad
    const toRad = (d) => (d * Math.PI) / 180;
    const [lat1, lng1] = a.map(toRad);
    const [lat2, lng2] = b.map(toRad);
    const y = Math.sin(lng2 - lng1) * Math.cos(lat2);
    const x = Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(lng2 - lng1);
    return ((Math.atan2(y, x) * 180) / Math.PI + 360) % 360;
  }

  const TRASH_ICON = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6M10 11v6M14 11v6"/></svg>';

  return {
    TRASH_ICON,
    parseDate,
    timeAgo,
    bearing,
    fare,
    chip,
    stats,
    SEVERITY,
    NOTICE_CATEGORY,
    REPORT_CATEGORY,
    requestId,
    ROUTE_STATUS,
    FEEDBACK_CATEGORY,
    vehicleStatusChip,
    FLAG_TEXT,
    flagChips,
    routeLabels,
    driverName,
    whenVerified,
  };
})();
