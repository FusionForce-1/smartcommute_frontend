// Admin system health view
AdminRouter.register('system-health', {
  title: 'System Health',

  // Mount the view
  mount(el) {
    const POLL_MS = 30000;

    el.innerHTML = `
      <div id="health-stats">${AdminUi.statGrid([['System Uptime'], ['Services Online'], ['Server Running'], ['Last Checked']])}</div>
      ${AdminUi.panel({ title: 'System Health Monitor', bodyId: 'health-body' })}`;

    const statsEl = el.querySelector('#health-stats');
    const bodyEl = el.querySelector('#health-body');

    // Render the view
    function render(health) {
      const online = health.services.filter((s) => s.status !== 'down').length;
      statsEl.innerHTML = AdminUi.statGrid([
        ['System Uptime', `${health.uptime_percent}%`],
        ['Services Online', `${online}/${health.services.length}`],
        ['Server Running', AdminUi.formatDuration(health.uptime_seconds)],
        ['Last Checked', new Date().toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })],
      ]);
      bodyEl.innerHTML = `
        ${AdminUi.healthList(health)}
        <p class="panel__meta">
          Refreshes every 30 seconds. "Idle" GPS means no vehicle has reported a position in the last hour.
          Uptime counts health checks since the server last started.
        </p>`;
    }

    AdminUi.loadInto(bodyEl, AdminApi.systemHealth, render);
    const timer = setInterval(() => {
      AdminApi.systemHealth().then(render).catch(() => {});
    }, POLL_MS);
    return () => clearInterval(timer);
  },
});
