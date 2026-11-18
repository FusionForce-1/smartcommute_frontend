// Admin UI
// Admin UI
const AdminUi = (() => {

  // Escape HTML
  function escapeHtml(value) {
    return String(value ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  // Parse date
  function parseDate(value) {
    if (!value) return null;
    if (value instanceof Date) return value;
    const hasZone = /[zZ]|[+-]\d\d:?\d\d$/.test(value);
    const date = new Date(hasZone ? value : `${value}Z`);
    return Number.isNaN(date.getTime()) ? null : date;
  }

  // Format date
  function formatDate(value) {
    const date = parseDate(value);
    return date ? date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : '—';
  }

  // Format date time
  function formatDateTime(value) {
    const date = parseDate(value);
    return date
      ? date.toLocaleString('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })
      : '—';
  }

  // Format number
  function formatNumber(value) {
    return typeof value === 'number' ? value.toLocaleString('en-US') : '—';
  }

  // Format duration
  function formatDuration(totalSeconds) {
    const days = Math.floor(totalSeconds / 86400);
    const hours = Math.floor((totalSeconds % 86400) / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    if (days) return `${days}d ${hours}h`;
    if (hours) return `${hours}h ${minutes}m`;
    return `${minutes}m`;
  }


  // Stat card
  function statCard(label, value) {
    return `
      <div class="stat-card">
        <p class="stat-card__label">${escapeHtml(label)}</p>
        <div class="stat-card__value">${value ?? '<span class="skeleton"></span>'}</div>
      </div>`;
  }

  // Stat grid
  function statGrid(cards) {
    return `<section class="stat-grid">${cards.map(([label, value]) => statCard(label, value)).join('')}</section>`;
  }

  // Admin UI panel
  function panel({ title, subtitle = '', bodyId, bodyClass = '', panelClass = '', between = '' }) {
    return `
      <section class="panel ${panelClass}">
        <header class="panel__head">
          <h2 class="panel__title">${escapeHtml(title)}</h2>
          ${subtitle ? `<p class="panel__subtitle">${escapeHtml(subtitle)}</p>` : ''}
        </header>
        ${between}
        <div class="panel__body ${bodyClass}" id="${bodyId}"></div>
      </section>`;
  }

  // Role badge
  function roleBadge(role) {
    return `<span class="role-badge role-badge--${escapeHtml(role)}">${escapeHtml(role)}</span>`;
  }

  // Status chip
  function statusChip(status) {
    return `<span class="status-chip status-chip--${escapeHtml(status)}">${escapeHtml(status)}</span>`;
  }

  // Filter chips
  function filterChips(options, active, dataAttr = 'filter') {
    return options
      .map(({ value, label }) => `
        <button type="button" class="chip${value === active ? ' is-active' : ''}" data-${dataAttr}="${escapeHtml(value)}">
          ${escapeHtml(label)}
        </button>`)
      .join('');
  }

  // State message
  function stateMessage(text, { error = false, retry = false } = {}) {
    return `
      <div class="state-msg${error ? ' state-msg--error' : ''}">
        <div>${escapeHtml(text)}</div>
        ${retry ? '<button type="button" class="btn-sm" data-retry>Try again</button>' : ''}
      </div>`;
  }


  // User row
  function userRow(user, currentEmail) {
    const isSelf = user.email === currentEmail;
    return `
      <tr>
        <td class="data-table__name">${escapeHtml(user.name || '—')}</td>
        <td>${escapeHtml(user.email)}</td>
        <td>${roleBadge(user.role)}</td>
        <td>${statusChip(user.status)}</td>
        <td>${formatDate(user.created_at)}</td>
        <td>
          <div class="data-table__actions">
            <button type="button" class="btn-sm" data-action="edit-user" data-id="${user.id}">Edit</button>
            <button type="button" class="btn-sm btn-sm--danger" data-action="delete-user" data-id="${user.id}"
              ${isSelf ? 'disabled title="You cannot delete your own account"' : ''}>Delete</button>
          </div>
        </td>
      </tr>`;
  }

  // Users table
  function usersTable(users, { firstColumn = 'Name', currentEmail = '' } = {}) {
    const rows = users.length
      ? users.map((u) => userRow(u, currentEmail)).join('')
      : '<tr><td colspan="6" class="data-table__empty">No user accounts found.</td></tr>';
    return `
      <div class="table-wrap">
        <table class="data-table">
          <thead>
            <tr><th>${firstColumn}</th><th>Email</th><th>Role</th><th>Status</th><th>Joined</th><th>Actions</th></tr>
          </thead>
          <tbody>${rows}</tbody>
        </table>
      </div>`;
  }


  // Pending operator list
  function pendingOperatorList(profiles) {
    if (!profiles.length) return stateMessage('No operators waiting for verification.');
    return `
      <div class="pending-list">
        ${profiles.map((p) => `
          <div class="pending-item">
            <span>${escapeHtml(p.company_name)}</span>
            <button type="button" class="btn-sm btn-sm--teal" data-action="review-operator" data-id="${p.id}">Verify</button>
          </div>`).join('')}
      </div>`;
  }


  // Health list
  function healthList(health) {
    return `
      <div class="health-list">
        ${health.services.map((s) => `
          <div class="health-item">
            <span class="health-item__dot health-item__dot--${escapeHtml(s.status)}"></span>
            <span>${escapeHtml(s.name)}</span>
            ${statusChip(s.status)}
          </div>`).join('')}
      </div>`;
  }


  // Load into
  async function loadInto(el, load, render) {
    if (!el) return;
    el.innerHTML = stateMessage('Loading…');
    try {
      const data = await load();
      if (el.isConnected) render(data);
    } catch (err) {
      if (!el.isConnected) return;
      el.innerHTML = stateMessage(err.message || 'Something went wrong.', { error: true, retry: true });
      el.querySelector('[data-retry]').addEventListener('click', () => loadInto(el, load, render));
    }
  }


  // Admin UI toast
  function toast(message, { error = false, sticky = false, onClick = null } = {}) {
    let root = document.getElementById('toast-root');
    if (!root) {
      root = document.createElement('div');
      root.id = 'toast-root';
      root.className = 'toast-root';
      root.setAttribute('role', 'status');
      document.body.appendChild(root);
    }
    const el = document.createElement('div');
    el.className = `toast${error ? ' toast--error' : ''}${onClick ? ' toast--action' : ''}`;
    const text = document.createElement('span');
    text.textContent = message;
    el.appendChild(text);

    if (onClick) {
      el.tabIndex = 0;
      el.setAttribute('role', 'button');
      // Activate admin UI
      const activate = () => { el.remove(); onClick(); };
      el.addEventListener('click', activate);
      el.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); activate(); }
      });
    }
    if (sticky) {
      const close = document.createElement('button');
      close.type = 'button';
      close.className = 'toast__close';
      close.setAttribute('aria-label', 'Dismiss');
      close.textContent = '×';
      close.addEventListener('click', (e) => { e.stopPropagation(); el.remove(); });
      el.appendChild(close);
    } else {
      setTimeout(() => el.remove(), 3500);
    }
    root.appendChild(el);
    return el;
  }

  return {
    escapeHtml,
    formatDate,
    formatDateTime,
    formatNumber,
    formatDuration,
    statGrid,
    panel,
    roleBadge,
    statusChip,
    filterChips,
    stateMessage,
    usersTable,
    pendingOperatorList,
    healthList,
    loadInto,
    toast,
  };
})();


// Admin modal
const AdminModal = (() => {
  let backdrop = null;
  let closeHook = null;

  // On keydown
  function onKeydown(e) {
    if (e.key === 'Escape') close();
  }

  // Open admin UI
  function open({ title, body, actions = [], size = '', onClose = null }) {
    close();
    closeHook = onClose;
    backdrop = document.createElement('div');
    backdrop.className = 'admin-modal-backdrop';
    backdrop.innerHTML = `
      <div class="admin-modal ${size ? `admin-modal--${size}` : ''}" role="dialog" aria-modal="true" aria-labelledby="admin-modal-title">
        <header class="admin-modal__head">
          <h2 class="admin-modal__title" id="admin-modal-title">${AdminUi.escapeHtml(title)}</h2>
          <button type="button" class="admin-modal__close" aria-label="Close">${LucideSvg.x}</button>
        </header>
        <div class="admin-modal__body">${body}</div>
        <div class="admin-modal__error" hidden></div>
        ${actions.length ? `
          <footer class="admin-modal__foot">
            ${actions.map((a, i) => `<button type="button" class="btn-lg btn-lg--${a.variant}" data-index="${i}">${AdminUi.escapeHtml(a.label)}</button>`).join('')}
          </footer>` : ''}
      </div>`;
    document.body.appendChild(backdrop);
    document.addEventListener('keydown', onKeydown);

    backdrop.addEventListener('click', (e) => {
      if (e.target === backdrop) close();
    });
    backdrop.querySelector('.admin-modal__close').addEventListener('click', close);

    const buttons = [...backdrop.querySelectorAll('.admin-modal__foot button')];
    const errorEl = backdrop.querySelector('.admin-modal__error');
    buttons.forEach((btn) => {
      btn.addEventListener('click', async () => {
        errorEl.hidden = true;
        buttons.forEach((b) => { b.disabled = true; });
        try {
          await actions[btn.dataset.index].onClick(backdrop);
        } catch (err) {
          errorEl.textContent = err.message || 'Something went wrong.';
          errorEl.hidden = false;
        } finally {
          buttons.forEach((b) => { b.disabled = false; });
        }
      });
    });

    return backdrop;
  }

  // Close admin UI
  function close() {
    if (!backdrop) return;
    backdrop.remove();
    backdrop = null;
    document.removeEventListener('keydown', onKeydown);
    const hook = closeHook;
    closeHook = null;
    if (hook) hook();
  }

  // Confirm admin UI
  function confirm({ title, message, confirmLabel = 'Confirm', variant = 'decline', onConfirm }) {
    open({
      title,
      size: 'sm',
      body: `<p class="modal-text">${AdminUi.escapeHtml(message)}</p>`,
      actions: [
        { label: 'Cancel', variant: 'ghost', onClick: close },
        {
          label: confirmLabel,
          variant,
          onClick: async () => {
            await onConfirm();
            close();
          },
        },
      ],
    });
  }

  return { open, close, confirm };
})();
