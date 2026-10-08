// js/admin/views/reports.js
//
// Reports: system activity summary and the most recent audit log entries.

AdminRouter.register('reports', {
  title: 'Reports',

  mount(el) {
    const RECENT_ACTIVITY = 15;
    const esc = AdminUi.escapeHtml;

    el.innerHTML = `
      <div id="reports-stats">${AdminUi.statGrid([['Total Users'], ['Active Users'], ['Actions (24h)'], ['Pending Verif.']])}</div>
      ${AdminUi.panel({
        title: 'Recent Activity',
        subtitle: 'Latest actions recorded in the audit log.',
        bodyId: 'reports-activity',
        bodyClass: 'panel__body--flush',
      })}`;

    const statsEl = el.querySelector('#reports-stats');
    const activityEl = el.querySelector('#reports-activity');

    Promise.all([AdminApi.systemReport(), AdminApi.userStats()])
      .then(([report, stats]) => {
        statsEl.innerHTML = AdminUi.statGrid([
          ['Total Users', AdminUi.formatNumber(stats.total_users)],
          ['Active Users', AdminUi.formatNumber(report.active_users)],
          ['Actions (24h)', AdminUi.formatNumber(report.actions_last_24h)],
          ['Pending Verif.', AdminUi.formatNumber(stats.pending_operators)],
        ]);
      })
      .catch((err) => {
        statsEl.innerHTML = AdminUi.stateMessage(err.message, { error: true });
      });

    AdminUi.loadInto(activityEl, () => AdminApi.auditLog({ limit: RECENT_ACTIVITY }), (entries) => {
      const rows = entries.length
        ? entries.map((e) => `
            <tr>
              <td>${AdminUi.formatDateTime(e.timestamp)}</td>
              <td class="data-table__name">${esc(e.action || '—')}</td>
              <td>${esc(e.target_collection || '—')}</td>
              <td>${esc(e.ip_address || '—')}</td>
            </tr>`).join('')
        : '<tr><td colspan="4" class="data-table__empty">No activity recorded yet.</td></tr>';

      activityEl.innerHTML = `
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Time</th><th>Action</th><th>Target</th><th>IP Address</th></tr></thead>
            <tbody>${rows}</tbody>
          </table>
        </div>`;
    });
  },
});
