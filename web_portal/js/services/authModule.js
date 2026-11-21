// Services auth module
// Auth module
const AuthModule = (() => {
  // Auth module request
  function request(method, path, body) {
    return ApiClient.request(method, path, body, { auth: false });
  }

  // Create operator profile
  function createOperatorProfile({ company_name, franchise_number, contact_number }) {
    return ApiClient.post('/operators', { user_id: 'self', company_name, franchise_number, contact_number });
  }

  return {
    // Login auth module
    login: async (email, password, rememberMe) => {
      const result = await request('POST', '/auth/login', { email, password });
      if (result?.two_factor_required) return result;
      Session.save({ ...result, email }, rememberMe);
      return result;
    },

    // Verify login code
    verifyLoginCode: async (email, otp, rememberMe) => {
      const result = await request('POST', '/auth/login/verify', { email, otp });
      Session.save({ ...result, email }, rememberMe);
      return result;
    },

    // Logout auth module
    logout: async () => {
      const refreshToken = Session.refreshToken;
      try {
        await ApiClient.post('/auth/logout', refreshToken ? { refresh_token: refreshToken } : undefined);
      } catch {
      }
      Session.clear();
    },

    // Register operator
    registerOperator: async ({ name, email, password, profile, acceptedTerms }) => {
      await request('POST', '/auth/register', {
        name, email, password, role: 'operator', accepted_terms: acceptedTerms === true,
      });
      try {
        const tokens = await request('POST', '/auth/login', { email, password });
        Session.save({ ...tokens, email });
        await createOperatorProfile(profile);
      } finally {
        Session.clear();
      }
    },

    // Login with Google
    loginWithGoogle: async (idToken, { role, email, rememberMe = false } = {}) => {
      const result = await request('POST', '/auth/google', { id_token: idToken, role });
      if (result?.two_factor_required) return result;
      Session.save({ ...result, email }, rememberMe);
      return result;
    },

    // Get my operator profile
    getMyOperatorProfile: async () => {
      try {
        return await ApiClient.get('/operators/me');
      } catch (err) {
        if (err.statusCode === 404) return null;
        throw err;
      }
    },

    createOperatorProfile,

    // Accept terms
    acceptTerms: () => ApiClient.post('/users/me/accept-terms'),

    // Forgot password
    forgotPassword: (email) =>
      request('POST', '/auth/forgot-password', { email }),

    // Reset password
    resetPassword: (email, otp, newPassword) =>
      request('POST', '/auth/reset-password', {
        email,
        otp,
        new_password: newPassword,
      }),
  };
})();
