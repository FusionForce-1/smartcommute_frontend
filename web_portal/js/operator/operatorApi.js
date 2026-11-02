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
  /** Driver monitoring: { name, on_shift, duty_status, current_location, events[] }. */
  driverActivity: (id) => ApiClient.get(`/drivers/${id}/activity`),
  /** Starts the driver's shift; vehicleId only when they have several. Returns { id, plate_number, started_at }. */
  startShift: (driverId, vehicleId) => ApiClient.post(`/drivers/${driverId}/shift`, vehicleId ? { vehicle_id: vehicleId } : {}),
  /** Ends it and returns its summary (trips, passengers, km, duration). */
  endShift: (driverId) => ApiClient.post(`/drivers/${driverId}/shift/end`),
  /** Commuters' ride reviews of this operator's drivers (+ per-driver summary), for a period and in an order. */
  driverReviews: ({ driverId, days, sort } = {}) => ApiClient.get('/reviews/operator', {
    ...(driverId ? { driver_id: driverId } : {}),
    ...(days ? { days } : {}),
    ...(sort ? { sort } : {}),
  }),
  addVehicle: ({ plate_number, route_id, driver_id }) =>
    ApiClient.post('/vehicles', { plate_number, route_id, driver_id: driver_id || null }),
  updateVehicle: (id, changes) => ApiClient.patch(`/vehicles/${id}`, changes),
  deleteVehicle: (id) => ApiClient.delete(`/vehicles/${id}`),
  issueDeviceKey: (id) => ApiClient.post(`/vehicles/${id}/device-key`),
  // GPS tracker setup by claim code (js/operator/trackerSetup.js)
  claimTracker: ({ claim_code, vehicle_id, networks }) =>
    ApiClient.post('/devices/claim', { claim_code, vehicle_id, networks }),
  trackerSetupStatus: (deviceId) => ApiClient.get(`/devices/${encodeURIComponent(deviceId)}`),
  // Remote WiFi for an online tracker (js/operator/trackerSetup.js -> openWifi)
  trackerWifi: (vehicleId) => ApiClient.get(`/vehicles/${vehicleId}/tracker-wifi`),
  setTrackerWifi: (vehicleId, networks) => ApiClient.put(`/vehicles/${vehicleId}/tracker-wifi`, { networks }),
  trackerFirmware: (vehicleId) => ApiClient.get(`/vehicles/${vehicleId}/tracker-firmware`),
  updateTrackerFirmware: (vehicleId) => ApiClient.post(`/vehicles/${vehicleId}/tracker-firmware/update`),
  /** Where the vehicle went between start and end (ISO, UTC; last 24 h only), for Playback. */
  vehicleTrack: (vehicleId, { start, end }) => ApiClient.get(`/vehicles/${vehicleId}/track`, { start, end }),

  // ---- Routes ----
  myRoutes: () => ApiClient.get('/routes/mine'),
  /** One route with its line and stops. */
  route: (id) => ApiClient.get(`/routes/${id}`),
  createRoute: ({ code, name, origin, destination, baseFare, originAt, destinationAt, path }) =>
    ApiClient.post('/routes', {
      code,
      name,
      terminal_a: origin,
      terminal_b: destination,
      fare_matrix: { base: baseFare },
      // Pinned on the Create Route map ([lng, lat]); optional.
      ...(originAt ? { terminal_a_location: { type: 'Point', coordinates: originAt } } : {}),
      ...(destinationAt ? { terminal_b_location: { type: 'Point', coordinates: destinationAt } } : {}),
      ...(path ? { geometry: { type: 'LineString', coordinates: path } } : {}),
    }),
  setRouteActive: (id, isActive) => ApiClient.patch(`/routes/${id}/active`, { is_active: isActive }),
  routeStops: (id) => ApiClient.get(`/routes/${id}/stops`),
  setRouteStops: (id, stops) => ApiClient.put(`/routes/${id}/stops`, { stops }),
  stopSuggestions: (id) => ApiClient.get(`/routes/${id}/stops/suggestions`),
  deleteRoute: (id) => ApiClient.delete(`/routes/${id}`),

  // ---- Announcements (notices to commuters) ----
  /** The routes a notice may cover: [{ route_id, route_code, route_name }]. */
  noticeTargets: () => ApiClient.get('/notices/targets'),
  sentNotices: ({ limit = 50 } = {}) => ApiClient.get('/notices/sent', { limit }),
  /** severity only for service alerts; no route_id = every route. Resending the same client_request_id returns the original. */
  sendNotice: ({ category, severity, title, message, route_id, client_request_id }) =>
    ApiClient.post('/notices', {
      category,
      ...(category === 'service_alert' ? { severity } : {}),
      title,
      message,
      ...(route_id ? { route_id } : {}),
      client_request_id,
    }),
  /** Takes it out of every commuter's inbox; returns it with withdrawn_at set. */
  withdrawNotice: (id) => ApiClient.delete(`/notices/${id}`),

  // ---- Driver reports (drivers -> this operator) ----
  /** Newest first; since (inclusive) / until (exclusive) are API timestamps. */
  driverReports: ({ unreadOnly, category, since, until, skip, limit } = {}) => ApiClient.get('/driver-reports/inbox', {
    ...(unreadOnly ? { unread_only: true } : {}),
    category, since, until, skip, limit,
  }),
  driverReportsUnreadCount: () => ApiClient.get('/driver-reports/inbox/unread-count'),
  markDriverReportRead: (id) => ApiClient.patch(`/driver-reports/${id}/read`),
  markAllDriverReportsRead: () => ApiClient.post('/driver-reports/read-all'),

  // ---- Revenue (daily remittances) ----
  revenueSummary: ({ start, end }) => ApiClient.get('/revenue/summary', { start, end }),
  remittances: ({ start, end }) => ApiClient.get('/revenue/remittances', { start, end }),
  recordRemittance: (body) => ApiClient.post('/revenue/remittances', body),
  updateRemittance: (id, changes) => ApiClient.patch(`/revenue/remittances/${id}`, changes),
  deleteRemittance: (id) => ApiClient.delete(`/revenue/remittances/${id}`),

  // ---- Feedback ----
  myFeedback: ({ limit = 20 } = {}) => ApiClient.get('/feedback/mine', { limit }),
};
