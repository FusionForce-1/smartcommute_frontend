// js/admin/adminApi.js
//
// Every backend call the admin portal makes, in one place.
// Views call these; they never build URLs or call fetch() themselves.

const AdminApi = {
  // ---- Users ----
  userStats: () => ApiClient.get('/users/stats'),
  listUsers: ({ role, skip = 0, limit = 50 } = {}) => ApiClient.get('/users', { role, skip, limit }),
  updateUser: (id, changes) => ApiClient.patch(`/users/${id}`, changes),
  deleteUser: (id) => ApiClient.delete(`/users/${id}`),

  // ---- Operator verification ----
  listOperators: (status) => ApiClient.get('/operators', { status }),
  approveOperator: (profileId) => ApiClient.post(`/operators/${profileId}/verify`),
  declineOperator: (profileId) => ApiClient.post(`/operators/${profileId}/decline`),

  // ---- System ----
  systemHealth: () => ApiClient.get('/system/health'),
  systemReport: () => ApiClient.get('/reports/system'),
  auditLog: ({ limit = 10 } = {}) => ApiClient.get('/audit-log', { limit }),
};
