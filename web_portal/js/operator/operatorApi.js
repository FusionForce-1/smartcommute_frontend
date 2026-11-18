// Operator API
const OperatorApi = {
  // Profile request
  profile: () => ApiClient.get('/operators/me'),
  // Update profile request
  updateProfile: ({ company_name, franchise_number, contact_number }) =>
    ApiClient.patch('/operators/me', { company_name, franchise_number, contact_number }),
  // Settings request
  settings: () => ApiClient.get('/users/me/settings'),
  // Update settings request
  updateSettings: (changes) => ApiClient.patch('/users/me/settings', changes),
  // Security request
  security: () => ApiClient.get('/users/me/security'),
  // Change password request
  changePassword: (currentPassword, newPassword) =>
    ApiClient.post('/users/me/password', { current_password: currentPassword, new_password: newPassword }),
  // Start two factor request
  startTwoFactor: () => ApiClient.post('/users/me/two-factor/start'),
  // Confirm two factor request
  confirmTwoFactor: (otp) => ApiClient.post('/users/me/two-factor/confirm', { otp }),

  // Fleet request
  fleet: () => ApiClient.get('/fleet'),
  // Fleet report request
  fleetReport: () => ApiClient.get('/reports/fleet'),
  // Subscription request
  subscription: () => ApiClient.get('/subscriptions/me'),
  // Start trial request
  startTrial: () => ApiClient.post('/subscriptions/trial'),
  // Checkout request
  checkout: ({ return_url, cancel_url }) => ApiClient.post('/subscriptions/checkout', { return_url, cancel_url }),
  // Capture PayPal request
  capturePayPal: (orderId) => ApiClient.post('/subscriptions/paypal/capture', { order_id: orderId }),
  // Mock pay request
  mockPay: (path) => ApiClient.post(path),
  // Drivers request
  drivers: () => ApiClient.get('/drivers'),
  // Scan license request
  scanLicense: (front, back) => {
    const form = new FormData();
    form.append('front', front);
    form.append('back', back);
    return ApiClient.upload('/drivers/scan-license', form);
  },
  // Add driver request
  addDriver: (details) => ApiClient.post('/drivers', details),
  // Update driver request
  updateDriver: (id, changes) => ApiClient.patch(`/drivers/${id}`, changes),
  // Update driver account request
  updateDriverAccount: (id, changes) => ApiClient.patch(`/drivers/${id}/account`, changes),
  // Delete driver request
  deleteDriver: (id) => ApiClient.delete(`/drivers/${id}`),
  // Driver activity request
  driverActivity: (id) => ApiClient.get(`/drivers/${id}/activity`),
  // Start shift request
  startShift: (driverId, vehicleId) => ApiClient.post(`/drivers/${driverId}/shift`, vehicleId ? { vehicle_id: vehicleId } : {}),
  // End shift request
  endShift: (driverId) => ApiClient.post(`/drivers/${driverId}/shift/end`),
  // Driver reviews request
  driverReviews: ({ driverId, days, sort } = {}) => ApiClient.get('/reviews/operator', {
    ...(driverId ? { driver_id: driverId } : {}),
    ...(days ? { days } : {}),
    ...(sort ? { sort } : {}),
  }),
  // Add vehicle request
  addVehicle: ({ plate_number, route_id, driver_id }) =>
    ApiClient.post('/vehicles', { plate_number, route_id, driver_id: driver_id || null }),
  // Update vehicle request
  updateVehicle: (id, changes) => ApiClient.patch(`/vehicles/${id}`, changes),
  // Delete vehicle request
  deleteVehicle: (id) => ApiClient.delete(`/vehicles/${id}`),
  // Issue device key request
  issueDeviceKey: (id) => ApiClient.post(`/vehicles/${id}/device-key`),
  // Claim tracker request
  claimTracker: ({ claim_code, vehicle_id, networks }) =>
    ApiClient.post('/devices/claim', { claim_code, vehicle_id, networks }),
  // Tracker setup status request
  trackerSetupStatus: (deviceId) => ApiClient.get(`/devices/${encodeURIComponent(deviceId)}`),
  // Tracker WiFi request
  trackerWifi: (vehicleId) => ApiClient.get(`/vehicles/${vehicleId}/tracker-wifi`),
  // Set tracker WiFi request
  setTrackerWifi: (vehicleId, networks) => ApiClient.put(`/vehicles/${vehicleId}/tracker-wifi`, { networks }),
  // Tracker firmware request
  trackerFirmware: (vehicleId) => ApiClient.get(`/vehicles/${vehicleId}/tracker-firmware`),
  // Update tracker firmware request
  updateTrackerFirmware: (vehicleId) => ApiClient.post(`/vehicles/${vehicleId}/tracker-firmware/update`),
  // Vehicle track request
  vehicleTrack: (vehicleId, { start, end }) => ApiClient.get(`/vehicles/${vehicleId}/track`, { start, end }),

  // My routes request
  myRoutes: () => ApiClient.get('/routes/mine'),
  // Route request
  route: (id) => ApiClient.get(`/routes/${id}`),
  // Create route request
  createRoute: ({ code, name, origin, destination, baseFare, originAt, destinationAt, path }) =>
    ApiClient.post('/routes', {
      code,
      name,
      terminal_a: origin,
      terminal_b: destination,
      fare_matrix: { base: baseFare },
      ...(originAt ? { terminal_a_location: { type: 'Point', coordinates: originAt } } : {}),
      ...(destinationAt ? { terminal_b_location: { type: 'Point', coordinates: destinationAt } } : {}),
      ...(path ? { geometry: { type: 'LineString', coordinates: path } } : {}),
    }),
  // Set route active request
  setRouteActive: (id, isActive) => ApiClient.patch(`/routes/${id}/active`, { is_active: isActive }),
  // Route stops request
  routeStops: (id) => ApiClient.get(`/routes/${id}/stops`),
  // Set route stops request
  setRouteStops: (id, stops, geometry = null) => ApiClient.put(`/routes/${id}/stops`, geometry ? { stops, geometry } : { stops }),
  // Stop suggestions request
  stopSuggestions: (id) => ApiClient.get(`/routes/${id}/stops/suggestions`),
  // Delete route request
  deleteRoute: (id) => ApiClient.delete(`/routes/${id}`),

  // Notice targets request
  noticeTargets: () => ApiClient.get('/notices/targets'),
  // Sent notices request
  sentNotices: ({ limit = 50 } = {}) => ApiClient.get('/notices/sent', { limit }),
  // Send notice request
  sendNotice: ({ category, severity, title, message, route_id, client_request_id }) =>
    ApiClient.post('/notices', {
      category,
      ...(category === 'service_alert' ? { severity } : {}),
      title,
      message,
      ...(route_id ? { route_id } : {}),
      client_request_id,
    }),
  // Withdraw notice request
  withdrawNotice: (id) => ApiClient.delete(`/notices/${id}`),

  // Driver reports request
  driverReports: ({ unreadOnly, category, since, until, skip, limit } = {}) => ApiClient.get('/driver-reports/inbox', {
    ...(unreadOnly ? { unread_only: true } : {}),
    category, since, until, skip, limit,
  }),
  // Driver reports unread count
  driverReportsUnreadCount: () => ApiClient.get('/driver-reports/inbox/unread-count'),
  // Mark driver report read
  markDriverReportRead: (id) => ApiClient.patch(`/driver-reports/${id}/read`),
  // Mark all driver reports read
  markAllDriverReportsRead: () => ApiClient.post('/driver-reports/read-all'),

  // Revenue summary request
  revenueSummary: ({ start, end }) => ApiClient.get('/revenue/summary', { start, end }),
  // Remittances request
  remittances: ({ start, end }) => ApiClient.get('/revenue/remittances', { start, end }),
  // Record remittance request
  recordRemittance: (body) => ApiClient.post('/revenue/remittances', body),
  // Update remittance request
  updateRemittance: (id, changes) => ApiClient.patch(`/revenue/remittances/${id}`, changes),
  // Delete remittance request
  deleteRemittance: (id) => ApiClient.delete(`/revenue/remittances/${id}`),

  // My feedback request
  myFeedback: ({ limit = 20 } = {}) => ApiClient.get('/feedback/mine', { limit }),
};
