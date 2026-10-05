// js/admin/adminActions.js
//
// Interactive flows shared by several views:
//   UserActions     — Edit / Delete buttons in any users table
//   OperatorReview  — "Operator Registration Details" modal (Approve / Decline)

const ROLES = ['admin', 'operator', 'driver', 'commuter'];
const ROLES_REQUIRING_VERIFICATION = ['operator', 'driver'];

/** Status shown in the UI → fields the backend stores. */
const STATUS_TO_FIELDS = {
  active: { is_active: true, is_verified: true },
  pending: { is_active: true, is_verified: false },
  suspended: { is_active: false },
};

const UserActions = (() => {
  const capitalize = (s) => s.charAt(0).toUpperCase() + s.slice(1);

  function statusOptions(role, selected) {
    const statuses = ROLES_REQUIRING_VERIFICATION.includes(role)
      ? ['active', 'pending', 'suspended']
      : ['active', 'suspended'];
    const current = statuses.includes(selected) ? selected : 'active';
    return statuses
      .map((s) => `<option value="${s}"${s === current ? ' selected' : ''}>${capitalize(s)}</option>`)
      .join('');
  }

  function openEdit(user, onChanged) {
    const isSelf = user.email === Session.email;
    const lockAttr = isSelf ? ' disabled title="You cannot change your own role or status"' : '';

    const modal = AdminModal.open({
      title: 'Edit User',
      size: 'sm',
      body: `
        <form id="edit-user-form" novalidate>
          <div class="form-field">
            <label for="edit-name">Name</label>
            <input id="edit-name" type="text" value="${AdminUi.escapeHtml(user.name)}" required minlength="2" />
          </div>
          <div class="form-field">
            <label>Email</label>
            <input type="email" value="${AdminUi.escapeHtml(user.email)}" disabled />
          </div>
          <div class="form-field">
            <label for="edit-role">Role</label>
            <select id="edit-role"${lockAttr}>
              ${ROLES.map((r) => `<option value="${r}"${r === user.role ? ' selected' : ''}>${capitalize(r)}</option>`).join('')}
            </select>
          </div>
          <div class="form-field">
            <label for="edit-status">Status</label>
            <select id="edit-status"${lockAttr}>${statusOptions(user.role, user.status)}</select>
          </div>
        </form>`,
      actions: [
        { label: 'Cancel', variant: 'ghost', onClick: AdminModal.close },
        { label: 'Save', variant: 'primary', onClick: save },
      ],
    });

    const roleSelect = modal.querySelector('#edit-role');
    const statusSelect = modal.querySelector('#edit-status');
    roleSelect.addEventListener('change', () => {
      statusSelect.innerHTML = statusOptions(roleSelect.value, statusSelect.value);
    });

    async function save() {
      const name = modal.querySelector('#edit-name').value.trim();
      if (name.length < 2) throw new Error('Name must be at least 2 characters.');

      const changes = { name };
      if (!isSelf) {
        changes.role = roleSelect.value;
        Object.assign(changes, STATUS_TO_FIELDS[statusSelect.value]);
      }
      await AdminApi.updateUser(user.id, changes);
      AdminModal.close();
      AdminUi.toast(`${name} was updated.`);
      onChanged();
    }
  }

  function confirmDelete(user, onChanged) {
    AdminModal.confirm({
      title: 'Delete User',
      message: `Delete ${user.name || user.email}? They will lose access and be removed from the user list.`,
      confirmLabel: 'Delete',
      onConfirm: async () => {
        await AdminApi.deleteUser(user.id);
        AdminUi.toast(`${user.name || user.email} was deleted.`);
        onChanged();
      },
    });
  }

  /**
   * Wires Edit/Delete buttons inside `container` (event delegation, so the
   * table can be re-rendered freely). `findUser(id)` returns the user object.
   */
  function bind(container, { findUser, onChanged }) {
    container.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-action="edit-user"], [data-action="delete-user"]');
      if (!btn) return;
      const user = findUser(btn.dataset.id);
      if (!user) return;
      if (btn.dataset.action === 'edit-user') openEdit(user, onChanged);
      else confirmDelete(user, onChanged);
    });
  }

  return { bind };
})();

const OperatorReview = (() => {
  function details(profile) {
    const rows = [
      ['Full Name', profile.full_name],
      ['Email Address', profile.email],
      ['Contact Number', profile.contact_number],
      ['Company Name', profile.company_name],
      ['Franchise Number', profile.franchise_number],
      ['Verified At', profile.verified_at ? AdminUi.formatDate(profile.verified_at) : 'Not yet verified'],
    ];
    if (profile.declined_at) rows.push(['Declined At', AdminUi.formatDate(profile.declined_at)]);

    return `
      <dl class="detail-list">
        ${rows.map(([label, value]) => `
          <div class="detail-list__row">
            <dt>${label}</dt>
            <dd>${AdminUi.escapeHtml(value || '—')}</dd>
          </div>`).join('')}
      </dl>`;
  }

  /** Opens the review modal. Approve/Decline are hidden once a decision exists for that action. */
  function open(profile, onDone) {
    const decide = (apiCall, verb) => async () => {
      await apiCall(profile.id);
      AdminModal.close();
      AdminUi.toast(`${profile.company_name} was ${verb}.`);
      onDone();
    };

    const actions = [];
    if (profile.status !== 'verified') {
      actions.push({ label: 'Approve', variant: 'approve', onClick: decide(AdminApi.approveOperator, 'approved') });
    }
    if (profile.status !== 'declined') {
      actions.push({ label: 'Decline', variant: 'decline', onClick: decide(AdminApi.declineOperator, 'declined') });
    }

    AdminModal.open({ title: 'Operator Registration Details', body: details(profile), actions });
  }

  /** Wires "Verify"/"Review" buttons in `container` to the modal. */
  function bind(container, { findProfile, onDone }) {
    container.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-action="review-operator"]');
      if (!btn) return;
      const profile = findProfile(btn.dataset.id);
      if (profile) open(profile, onDone);
    });
  }

  return { open, bind };
})();
