// Driver report alerts
// Driver report alerts
const DriverReportAlerts = (() => {
  const POLL_MS = 30000;
  const NEW_LIMIT = 20;
  const NOTE_SHOWN = 80;

  let timer = null;
  let primed = false;
  let since = null;
  let seen = new Set();
  let stickies = [];

  // Open driver report
  const open = () => { location.hash = '#/driver-reports'; };

  // Emergency toast
  function emergencyToast(message) {
    stickies.push(AdminUi.toast(message, { error: true, sticky: true, onClick: open }));
  }

  // Set badge
  function setBadge(count) {
    const badge = document.getElementById('op-reports-badge');
    if (badge) {
      badge.textContent = count > 99 ? '99+' : String(count);
      badge.hidden = !count;
    }
    if (!count) {
      stickies.forEach((el) => el.remove());
      stickies = [];
    }
  }

  // Refresh driver report
  async function refresh() {
    const { count } = await OperatorApi.driverReportsUnreadCount();
    setBadge(count);
    return count;
  }

  // Driver report remember
  function remember(reports) {
    if (!reports.length) return;
    const newest = reports[0].created_at;
    if (newest !== since) {
      since = newest;
      seen = new Set();
    }
    reports.filter((r) => r.created_at === since).forEach((r) => seen.add(r.id));
  }

  // Driver report describe
  function describe(r) {
    const label = (OperatorUi.REPORT_CATEGORY[r.category] || OperatorUi.REPORT_CATEGORY.other).label;
    const plate = r.context?.plate_number ? ` (${r.context.plate_number})` : '';
    const note = r.note ? `: ${r.note.length > NOTE_SHOWN ? `${r.note.slice(0, NOTE_SHOWN)}…` : r.note}` : '';
    return { label, who: `${r.driver_name}${plate}`, note };
  }

  // Driver report announce
  function announce(reports) {
    const emergencies = reports.filter((r) => r.category === 'emergency');
    const others = reports.filter((r) => r.category !== 'emergency');
    emergencies.forEach((r) => {
      const { who, note } = describe(r);
      emergencyToast(`EMERGENCY from ${who}${note}`);
    });
    if (others.length === 1) {
      const { label, who, note } = describe(others[0]);
      AdminUi.toast(`${label} report from ${who}${note}`, { onClick: open });
    } else if (others.length > 1) {
      AdminUi.toast(`${others.length} new driver reports.`, { onClick: open });
    }
  }

  // Check driver report
  async function check() {
    const [fresh] = await Promise.all([
      OperatorApi.driverReports({ since, limit: NEW_LIMIT }),
      refresh(),
    ]);
    const news = fresh.filter((r) => !seen.has(r.id));
    remember(fresh);
    if (!news.length) return;
    announce(news);
    window.dispatchEvent(new CustomEvent('driver-reports:changed'));
  }

  // Driver report prime
  async function prime() {
    const [latest, count, emergencies] = await Promise.all([
      OperatorApi.driverReports({ limit: 1 }),
      refresh(),
      OperatorApi.driverReports({ unreadOnly: true, category: 'emergency', limit: NEW_LIMIT }),
    ]);
    remember(latest);
    primed = true;
    if (emergencies.length) {
      const n = emergencies.length;
      emergencyToast(`${n === NEW_LIMIT ? `${n}+` : n} unread emergency ${n === 1 ? 'report' : 'reports'} from your drivers.`);
    }
    const rest = count - emergencies.length;
    if (rest > 0) {
      AdminUi.toast(`You have ${rest} unread driver ${rest === 1 ? 'report' : 'reports'}.`, { onClick: open });
    }
  }

  // Schedule driver report
  function schedule() {
    timer = setTimeout(async () => {
      try {
        await (primed ? check() : prime());
      } catch (err) {
        if (stopOn(err)) return;
      }
      schedule();
    }, POLL_MS);
  }

  // Stop on
  function stopOn(err) {
    if (err.statusCode === 403 || err.statusCode === 401) {
      stop();
      return true;
    }
    return false;
  }

  // Start driver report
  async function start() {
    if (timer) return;
    try {
      await prime();
    } catch (err) {
      if (stopOn(err)) return;
    }
    schedule();
  }

  // Stop driver report
  function stop() {
    clearTimeout(timer);
    timer = null;
  }

  return { start, stop, refresh };
})();
