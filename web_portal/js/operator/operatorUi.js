// js/operator/operatorUi.js
//
// Param-only HTML builders + formatting shared by the operator views.
// Generic helpers (escapeHtml, loadInto, toast, modal) come from adminUi.js.

const OperatorUi = (() => {
  const esc = AdminUi.escapeHtml;

  /** API timestamps are naive UTC; a string without a zone is treated as UTC. */
  function parseDate(value) {
    if (!value) return null;
    const hasZone = /[zZ]|[+-]\d\d:?\d\d$/.test(value);
    const date = new Date(hasZone ? value : `${value}Z`);
    return Number.isNaN(date.getTime()) ? null : date;
  }

  /** "Just now", "10 minutes ago", "3 hours ago", "Yesterday, 4:20 PM", "Oct 3, 4:20 PM" */
  function timeAgo(value, now = new Date()) {
    const date = parseDate(value);
    if (!date) return '';
    const minutes = Math.floor((now - date) / 60000);
    if (minutes < 1) return 'Just now';
    if (minutes < 60) return `${minutes} ${minutes === 1 ? 'minute' : 'minutes'} ago`;

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

  /** "₱18", "₱12.50", "—" */
  function fare(value) {
    if (typeof value !== 'number') return '—';
    return Number.isInteger(value) ? `₱${value}` : `₱${value.toFixed(2)}`;
  }

  function chip(label, tone = '') {
    return `<span class="op-chip${tone ? ` op-chip--${tone}` : ''}">${esc(label)}</span>`;
  }

  function stat(label, value, tone = '') {
    return `
      <div class="op-stat">
        <p class="op-stat__label">${esc(label)}</p>
        <div class="op-stat__value${tone ? ` op-stat__value--${tone}` : ''}">${value ?? '<span class="skeleton"></span>'}</div>
      </div>`;
  }

  /** @param {Array<[label, value, tone?]>} items — value undefined renders a skeleton */
  function stats(items) {
    return `<section class="op-stats">${items.map(([l, v, t]) => stat(l, v, t)).join('')}</section>`;
  }

  const SEVERITY = {
    info: { label: 'Information', button: 'Info', tone: 'blue' },
    warning: { label: 'Warning', button: 'Warning', tone: 'amber' },
    critical: { label: 'Critical', button: 'Critical', tone: 'red' },
  };

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

  function vehicleStatusChip(vehicle) {
    if (vehicle.suspended) return chip('Suspended', 'red');
    const meta = VEHICLE_STATUS[vehicle.status] || { label: vehicle.status, tone: '' };
    return chip(meta.label, meta.tone);
  }

  /** Map of route id -> "J01 – Carbon – Lahug" from GET /routes/mine. */
  function routeLabels(routes) {
    return Object.fromEntries(routes.map((r) => [r.id, `${r.code} – ${r.name}`]));
  }

  /** Readable driver name from GET /drivers ("LAST, FIRST" on the license). */
  function driverName(driver) {
    const title = (s) => s.toLowerCase().replace(/\b\w/g, (c) => c.toUpperCase());
    return [driver.first_name, driver.last_name].filter(Boolean).map(title).join(' ') || driver.driver_code;
  }

  const TRASH_ICON = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6M10 11v6M14 11v6"/></svg>';

  return {
    TRASH_ICON,
    parseDate,
    timeAgo,
    fare,
    chip,
    stats,
    SEVERITY,
    ROUTE_STATUS,
    FEEDBACK_CATEGORY,
    vehicleStatusChip,
    routeLabels,
    driverName,
  };
})();
