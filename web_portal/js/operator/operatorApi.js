// js/operator/operatorApi.js
//
// Every backend call the operator portal makes, in one place.
// Views call these; they never build URLs or call fetch() themselves.

const OperatorApi = {
  // ---- Account ----
  profile: () => ApiClient.get('/operators/me'),
  updateProfile: ({ company_name, franchise_number, contact_number }) =>
    ApiClient.patch('/operators/me', { company_name, franchise_number, contact_number }),
  settings: () => ApiClient.get('/users/me/settings'),
  updateSettings: (changes) => ApiClient.patch('/users/me/settings', changes),
  startTwoFactor: () => ApiClient.post('/users/me/two-factor/start'),
  confirmTwoFactor: (otp) => ApiClient.post('/users/me/two-factor/confirm', { otp }),

  // ---- Fleet ----
  fleet: () => ApiClient.get('/fleet'),
  fleetReport: () => ApiClient.get('/reports/fleet'),
  subscription: () => ApiClient.get('/subscriptions/me'),
  startTrial: () => ApiClient.post('/subscriptions/trial'),
  /** Returns { checkout_url }: PayPal's approval page (or the mock pay path). */
  checkout: ({ return_url, cancel_url }) => ApiClient.post('/subscriptions/checkout', { return_url, cancel_url }),
  /** After PayPal sends the operator back with ?token=<order id>. */
  capturePayPal: (orderId) => ApiClient.post('/subscriptions/paypal/capture', { order_id: orderId }),
  /** Development only (PAYMENT_PROVIDER=mock): "pays" the checkout instantly. */
  mockPay: (path) => ApiClient.post(path),
  drivers: () => ApiClient.get('/drivers'),
  /** Reads both sides of a license. Nothing is saved. */
  scanLicense: (front, back) => {
    const form = new FormData();
    form.append('front', front);
    form.append('back', back);
    return ApiClient.upload('/drivers/scan-license', form);
  },
  addDriver: (details) => ApiClient.post('/drivers', details),
  updateDriver: (id, changes) => ApiClient.patch(`/drivers/${id}`, changes),
  updateDriverAccount: (id, changes) => ApiClient.patch(`/drivers/${id}/account`, changes),
  deleteDriver: (id) => ApiClient.delete(`/drivers/${id}`),
  addVehicle: ({ plate_number, route_id, driver_id }) =>
    ApiClient.post('/vehicles', { plate_number, route_id, driver_id: driver_id || null }),
  updateVehicle: (id, changes) => ApiClient.patch(`/vehicles/${id}`, changes),
  deleteVehicle: (id) => ApiClient.delete(`/vehicles/${id}`),
  issueDeviceKey: (id) => ApiClient.post(`/vehicles/${id}/device-key`),
  // GPS tracker setup by claim code (js/operator/trackerSetup.js)
  claimTracker: ({ claim_code, vehicle_id, networks }) =>
    ApiClient.post('/devices/claim', { claim_code, vehicle_id, networks }),
  trackerSetupStatus: (deviceId) => ApiClient.get(`/devices/${encodeURIComponent(deviceId)}`),

  // ---- Routes ----
  myRoutes: () => ApiClient.get('/routes/mine'),
  /** Active routes with their map geometry (public list). */
  mapRoutes: () => ApiClient.get('/routes'),
  createRoute: ({ code, name, origin, destination, baseFare }) =>
    ApiClient.post('/routes', {
      code,
      name,
      terminal_a: origin,
      terminal_b: destination,
      fare_matrix: { base: baseFare },
    }),
  setRouteActive: (id, isActive) => ApiClient.patch(`/routes/${id}/active`, { is_active: isActive }),
  deleteRoute: (id) => ApiClient.delete(`/routes/${id}`),

  // ---- Announcements (transit alerts) ----
  myAlerts: () => ApiClient.get('/alerts/mine'),
  publishAlert: ({ title, message, severity, route_id }) =>
    ApiClient.post('/alerts', { title, message, severity, route_id: route_id || null }),
  setAlertResolved: (id, resolved) => ApiClient.patch(`/alerts/${id}/resolved`, { is_resolved: resolved }),
  deleteAlert: (id) => ApiClient.delete(`/alerts/${id}`),

  // ---- Revenue (daily remittances) ----
  revenueSummary: ({ start, end }) => ApiClient.get('/revenue/summary', { start, end }),
  remittances: ({ start, end }) => ApiClient.get('/revenue/remittances', { start, end }),
  recordRemittance: (body) => ApiClient.post('/revenue/remittances', body),
  updateRemittance: (id, changes) => ApiClient.patch(`/revenue/remittances/${id}`, changes),
  deleteRemittance: (id) => ApiClient.delete(`/revenue/remittances/${id}`),

  // ---- Feedback ----
  myFeedback: ({ limit = 20 } = {}) => ApiClient.get('/feedback/mine', { limit }),
};
