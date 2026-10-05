// js/admin/views/config.js
//
// Config: placeholder until the backend exposes editable settings.

AdminRouter.register('config', {
  title: 'Config',

  mount(el) {
    el.innerHTML = AdminUi.panel({ title: 'System Configuration', bodyId: 'config-body' });
    el.querySelector('#config-body').innerHTML = AdminUi.stateMessage(
      'System settings are managed in the backend .env file. Editing them from the portal is not available yet.'
    );
  },
});
