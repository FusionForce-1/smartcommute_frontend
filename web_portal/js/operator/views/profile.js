// js/operator/views/profile.js
//
// Profile: the operator's company details from GET /operators/me, with an
// Edit Profile modal (PATCH /operators/me).

OperatorRouter.register('profile', {
  title: 'Profile',
  heading: 'Operator Profile',

  mount(el) {
    const esc = AdminUi.escapeHtml;
    let profile = null;

    el.innerHTML = `
      <div class="op-narrow">
        <div class="op-page-head">
          <div><h2>Profile</h2></div>
          <button type="button" class="op-btn" id="profile-edit" disabled>Edit Profile</button>
        </div>
        <section class="op-card" id="profile-card"></section>
      </div>`;

    const cardEl = el.querySelector('#profile-card');
    const editBtn = el.querySelector('#profile-edit');

    /** "Cebu City Transport Co." -> "CC" */
    const initials = (name) =>
      (name || '').split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0].toUpperCase()).join('') || '?';

    function row(label, value) {
      const missing = !value || !String(value).trim();
      return `
        <div class="op-detail-row">
          <span>${esc(label)}</span>
          <strong class="${missing ? 'is-missing' : ''}">${missing ? 'Not provided' : esc(value)}</strong>
        </div>`;
    }

    function render() {
      cardEl.innerHTML = `
        <div class="op-profile__head">
          <div class="op-avatar">${esc(initials(profile.company_name))}</div>
          <div>
            <h3 class="op-profile__name">${esc(profile.company_name)}</h3>
            <p class="op-profile__email">${esc(profile.email || Session.email)}</p>
            ${profile.is_verified ? OperatorUi.chip('Verified Operator', 'green') : OperatorUi.chip('Pending Verification', 'amber')}
          </div>
        </div>
        ${row('Company Name', profile.company_name)}
        ${row('Account Owner', profile.full_name)}
        ${row('Franchise Number', profile.franchise_number)}
        ${row('Contact Number', profile.contact_number)}
        ${profile.verified_at ? row('Verified On', AdminUi.formatDate(profile.verified_at)) : ''}`;
      editBtn.disabled = false;
    }

    function load() {
      editBtn.disabled = true;
      AdminUi.loadInto(cardEl, OperatorApi.profile, (p) => {
        profile = p;
        render();
      });
    }

    function openEdit() {
      const field = (id, label, value, attrs = '') => `
        <div class="form-field">
          <label for="${id}">${label}</label>
          <input id="${id}" value="${esc(value || '')}" ${attrs} />
        </div>`;

      const modal = AdminModal.open({
        title: 'Edit Profile',
        size: 'sm',
        body: `
          <form novalidate>
            ${field('pe-company', 'Company Name', profile.company_name, 'maxlength="100" required')}
            ${field('pe-franchise', 'Franchise Number', profile.franchise_number, 'maxlength="50"')}
            ${field('pe-contact', 'Contact Number', profile.contact_number, 'maxlength="20" inputmode="tel"')}
          </form>`,
        actions: [
          { label: 'Cancel', variant: 'ghost', onClick: AdminModal.close },
          {
            label: 'Save',
            variant: 'primary',
            onClick: async (m) => {
              const changes = {
                company_name: m.querySelector('#pe-company').value.trim(),
                franchise_number: m.querySelector('#pe-franchise').value.trim(),
                contact_number: m.querySelector('#pe-contact').value.trim(),
              };
              if (changes.company_name.length < 2) throw new Error('Company name must be at least 2 characters.');
              if (changes.contact_number && !/^[0-9+\-\s]{7,20}$/.test(changes.contact_number)) {
                throw new Error('Enter a valid contact number.');
              }
              await OperatorApi.updateProfile(changes);
              profile = { ...profile, ...changes };
              AdminModal.close();
              render();
              AdminUi.toast('Profile updated.');
            },
          },
        ],
      });
      modal.querySelector('#pe-company').focus();
    }

    editBtn.addEventListener('click', () => {
      if (profile) openEdit();
    });

    load();
  },
});
