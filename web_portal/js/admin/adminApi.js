// Admin API
const AdminApi = {
  // User stats request
  userStats: () => ApiClient.get('/users/stats'),
  // List users request
  listUsers: ({ role, skip = 0, limit = 50 } = {}) => ApiClient.get('/users', { role, skip, limit }),
  // Update user request
  updateUser: (id, changes) => ApiClient.patch(`/users/${id}`, changes),
  // Delete user request
  deleteUser: (id) => ApiClient.delete(`/users/${id}`),

  // List operators request
  listOperators: (status) => ApiClient.get('/operators', { status }),
  // Approve operator request
  approveOperator: (profileId) => ApiClient.post(`/operators/${profileId}/verify`),
  // Decline operator request
  declineOperator: (profileId) => ApiClient.post(`/operators/${profileId}/decline`),

  // System health request
  systemHealth: () => ApiClient.get('/system/health'),
  // System config request
  systemConfig: () => ApiClient.get('/system/config'),
  // Update system config request
  updateSystemConfig: (values) => ApiClient.patch('/system/config', { values }),
  // Send test email request
  sendTestEmail: () => ApiClient.post('/system/config/test-email'),
  // System report request
  systemReport: () => ApiClient.get('/reports/system'),
  // Audit log request
  auditLog: ({ limit = 10 } = {}) => ApiClient.get('/audit-log', { limit }),
};
